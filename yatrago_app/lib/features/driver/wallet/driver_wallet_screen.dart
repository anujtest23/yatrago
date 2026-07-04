import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import 'wallet_api.dart';

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _isLoading = true;
  String? _error;
  double _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _commissions = [];
  bool _isToppingUp = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Future<void> _showTopUpSheet() async {
    final controller = TextEditingController();
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Up Wallet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                prefixText: 'NPR ',
                hintText: 'Enter amount',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [500, 1000, 2000, 5000]
                  .map(
                    (v) => ActionChip(
                      label: Text('NPR $v'),
                      onPressed: () => controller.text = v.toString(),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.driver,
                ),
                onPressed: () {
                  final val = double.tryParse(controller.text.trim());
                  if (val != null && val > 0) Navigator.pop(ctx, val);
                },
                child: const Text('Top Up'),
              ),
            ),
          ],
        ),
      ),
    );

    if (amount == null) return;
    setState(() => _isToppingUp = true);
    try {
      await WalletApi.topUp(amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('NPR ${amount.toStringAsFixed(0)} added to wallet'),
          backgroundColor: AppColors.success,
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isToppingUp = false);
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
              onPressed: _isToppingUp ? null : _showTopUpSheet,
              icon: _isToppingUp
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
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
