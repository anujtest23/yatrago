import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import 'payment_api.dart';

/// G2 — Top-up attempt history. Distinct from the wallet transaction ledger:
/// this lists payment *attempts* across every status (pending, completed,
/// failed, expired, refunded) with cursor pagination, so a driver can tell an
/// in-progress or failed top-up apart from a settled credit.
class TopupHistoryScreen extends StatefulWidget {
  const TopupHistoryScreen({super.key});

  @override
  State<TopupHistoryScreen> createState() => _TopupHistoryScreenState();
}

class _TopupHistoryScreenState extends State<TopupHistoryScreen> {
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _items = [];

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _cursor;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 240 &&
        !_loadingMore &&
        _hasMore) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _cursor = null;
        _hasMore = true;
        _items.clear();
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final res = await PaymentApi.getTopupHistory(cursor: _cursor);
      final topups = List<Map<String, dynamic>>.from(res['topups'] ?? []);
      if (!mounted) return;
      setState(() {
        _items.addAll(topups);
        _cursor = res['nextCursor'] as String?;
        _hasMore = _cursor != null;
        _loading = false;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _loadingMore = false;
      });
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
        title: const Text('Top-up History'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.driver),
            )
          : _error != null
              ? _errorState()
              : _items.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.screenPadding),
                        itemCount: _items.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          if (i >= _items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.driver,
                                  ),
                                ),
                              ),
                            );
                          }
                          return _TopupTile(topup: _items[i]);
                        },
                      ),
                    ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 56, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          const Text(
            'No top-ups yet',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _load(reset: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _TopupTile extends StatelessWidget {
  final Map<String, dynamic> topup;
  const _TopupTile({required this.topup});

  @override
  Widget build(BuildContext context) {
    final status = topup['status'] as String? ?? 'initiated';
    final amount = (topup['amount'] as num?)?.toDouble() ?? 0;
    final style = _statusStyle(status);
    final createdAt = _formatDate(topup['createdAt']);
    final refunded = (topup['refundedAmount'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(style.icon, color: style.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NPR ${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'eSewa • $createdAt',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (refunded != null)
                  Text(
                    'Refunded NPR ${refunded.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              style.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: style.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _StatusStyle _statusStyle(String status) {
    switch (status) {
      case 'completed':
        return const _StatusStyle(
            'Completed', Icons.check_circle_rounded, AppColors.success);
      case 'pending':
      case 'initiated':
        return const _StatusStyle(
            'Pending', Icons.hourglass_bottom_rounded, AppColors.warning);
      case 'failed':
        return const _StatusStyle(
            'Failed', Icons.cancel_rounded, AppColors.error);
      case 'expired':
        return const _StatusStyle(
            'Expired', Icons.timer_off_rounded, AppColors.textTertiary);
      case 'refunded':
        return const _StatusStyle(
            'Refunded', Icons.undo_rounded, AppColors.error);
      default:
        return const _StatusStyle(
            'Unknown', Icons.help_outline_rounded, AppColors.textTertiary);
    }
  }

  String _formatDate(dynamic iso) {
    if (iso == null) return '';
    try {
      return DateFormat('d MMM yyyy, h:mm a')
          .format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
  }
}

class _StatusStyle {
  final String label;
  final IconData icon;
  final Color color;
  const _StatusStyle(this.label, this.icon, this.color);
}
