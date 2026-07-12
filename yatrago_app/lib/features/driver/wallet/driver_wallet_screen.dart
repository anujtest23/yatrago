import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/route_names.dart';
import 'wallet_api.dart';
import 'payment_api.dart';

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;

  bool _isLoading = true;
  String? _error;
  double _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _commissions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _load();
    // G1: credit any top-up that settled while the app was closed.
    _reconcile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reconcile();
  }

  /// Reconcile pending top-ups server-side; refresh the ledger if any credited.
  Future<void> _reconcile() async {
    try {
      final res = await PaymentApi.reconcile();
      if (!mounted) return;
      final credited = (res['credited'] as num?)?.toInt() ?? 0;
      final bal = (res['balance'] as num?)?.toDouble();
      if (credited > 0) {
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A pending top-up was credited to your wallet.'),
            ),
          );
        }
      } else if (bal != null && bal != _balance) {
        setState(() => _balance = bal);
      }
    } catch (_) {
      // Silent; the reconciliation cron is the backstop.
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final wallet = await WalletApi.getWallet();
      final commissions = await WalletApi.getCommissions();
      if (!mounted) return;
      setState(() {
        _balance = (wallet['balance'] as num?)?.toDouble() ?? 0;
        _transactions = List<Map<String, dynamic>>.from(
          wallet['transactions'] ?? [],
        );
        _commissions = commissions;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  // Top-ups are self-service via the payment gateway. Open the Top Up screen
  // and refresh the balance if it reports a successful credit.
  Future<void> _openTopUp() async {
    final credited = await context.push<bool>(RouteNames.topUp);
    if (credited == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Wallet'),
        actions: [
          IconButton(
            tooltip: 'Top-up history',
            icon: const Icon(Icons.history_rounded, color: AppColors.driver),
            onPressed: () => context.push(RouteNames.topupHistory),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.driver),
            )
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : Column(
              children: [
                _balanceCard(),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.driver,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.driver,
                  tabs: const [
                    Tab(text: 'Transactions'),
                    Tab(text: 'Commissions'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _transactionsList(),
                      _commissionsList(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _balanceCard() {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.screenPadding),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.driver, Color(0xFF0E7A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Balance',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'NPR ${_balance.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.driver,
              ),
              onPressed: _openTopUp,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Top Up'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionsList() {
    if (_transactions.isEmpty) {
      return const _EmptyState(
        icon: Icons.receipt_long_rounded,
        message: 'No transactions yet',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: _transactions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final tx = _transactions[i];
          final isCredit = tx['type'] == 'credit';
          final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: (isCredit ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.12),
              child: Icon(
                isCredit
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: isCredit ? AppColors.success : AppColors.error,
                size: 20,
              ),
            ),
            title: Text(
              _sourceLabel(tx['source'] as String?),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              tx['note'] as String? ?? _formatDate(tx['createdAt']),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              '${isCredit ? '+' : '-'}NPR ${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isCredit ? AppColors.success : AppColors.error,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _commissionsList() {
    if (_commissions.isEmpty) {
      return const _EmptyState(
        icon: Icons.percent_rounded,
        message: 'No commission history yet',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: _commissions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = _commissions[i];
          final amount = (c['amount'] as num?)?.toDouble() ?? 0;
          final mode = c['mode'] as String? ?? 'percent';
          final gross = (c['grossFares'] as num?)?.toDouble() ?? 0;
          final status = c['status'] as String? ?? 'charged';
          final isOwed = status == 'owed';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: const Icon(
                Icons.percent_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            title: Text(
              mode == 'fixed'
                  ? 'Fixed commission'
                  : '${(c['rate'] as num?)?.toStringAsFixed(0) ?? ''}% of NPR ${gross.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _formatDate(c['createdAt']),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-NPR ${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                if (isOwed)
                  const Text(
                    'OWED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _sourceLabel(String? source) {
    switch (source) {
      case 'topup':
        return 'Wallet Top-up';
      case 'commission':
        return 'Platform Commission';
      case 'refund':
        return 'Refund';
      case 'payout':
        return 'Payout';
      case 'trip_earnings':
        return 'Trip Earnings';
      default:
        return source ?? 'Transaction';
    }
  }

  String _formatDate(dynamic iso) {
    if (iso == null) return '';
    try {
      return DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
