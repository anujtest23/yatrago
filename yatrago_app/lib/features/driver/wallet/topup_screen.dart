import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import 'payment_api.dart';
import 'wallet_api.dart';
import 'esewa_payment_webview.dart';

/// Self-service wallet top-up. Shows the available payment methods (only the
/// eSewa sandbox for now, plus an "Add payment method" placeholder), takes an
/// amount, and drives the eSewa pay → backend-verify → credit flow.
///
/// Pops `true` once a top-up has been credited, so callers (e.g. the
/// post-ride insufficient-balance flow) can continue automatically.
class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen>
    with WidgetsBindingObserver {
  final _amountController = TextEditingController();

  bool _loading = true;
  bool _processing = false;
  String? _error;

  double _balance = 0;
  List<Map<String, dynamic>> _methods = [];
  List<Map<String, dynamic>> _saved = [];
  String? _selectedMethodId;
  int _minAmount = 100;
  int _maxAmount = 100000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // G1: pick up any top-up that settled while the app was away.
    _reconcile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the eSewa page (or any background) re-checks pending
    // top-ups server-side, so a payment that completed out-of-band is credited.
    if (state == AppLifecycleState.resumed && !_processing) {
      _reconcile();
    }
  }

  /// Ask the backend to reconcile all of this user's pending top-ups. Silent on
  /// failure — the periodic cron is the ultimate backstop.
  Future<void> _reconcile() async {
    try {
      final res = await PaymentApi.reconcile();
      if (!mounted) return;
      final bal = (res['balance'] as num?)?.toDouble();
      final credited = (res['credited'] as num?)?.toInt() ?? 0;
      if (bal != null) setState(() => _balance = bal);
      if (credited > 0) {
        _snack('A pending top-up was credited to your wallet.');
      }
    } catch (_) {
      // Ignore; reconciliation will be retried on next open / by the cron.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        PaymentApi.getPaymentMethods(),
        WalletApi.getWallet(),
      ]);
      final methodsData = results[0];
      final wallet = results[1];
      if (!mounted) return;
      final methods = List<Map<String, dynamic>>.from(
        methodsData['methods'] ?? [],
      );
      setState(() {
        _methods = methods;
        _saved = List<Map<String, dynamic>>.from(methodsData['saved'] ?? []);
        _balance = (wallet['balance'] as num?)?.toDouble() ?? 0;
        // Default-select the first enabled method.
        final firstEnabled = methods.firstWhere(
          (m) => m['enabled'] == true,
          orElse: () => {},
        );
        _selectedMethodId = firstEnabled['id'] as String?;
        if (firstEnabled['minAmount'] != null) {
          _minAmount = (firstEnabled['minAmount'] as num).toInt();
        }
        if (firstEnabled['maxAmount'] != null) {
          _maxAmount = (firstEnabled['maxAmount'] as num).toInt();
        }
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _pay() async {
    FocusScope.of(context).unfocus();
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (amount < _minAmount || amount > _maxAmount) {
      setState(
        () => _error = 'Amount must be between NPR $_minAmount and NPR $_maxAmount',
      );
      return;
    }
    if (_selectedMethodId != 'esewa') {
      setState(() => _error = 'Select a payment method');
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      // 1. Backend creates a signed intent (no money moves yet).
      final intent = await PaymentApi.initiateEsewa(amount);
      if (!mounted) return;

      // 2. Complete payment inside the eSewa WebView.
      final result = await Navigator.of(context).push<EsewaResult>(
        MaterialPageRoute(
          builder: (_) => EsewaPaymentWebView(intent: intent),
        ),
      );

      if (result == EsewaResult.cancelled || result == null) {
        if (mounted) {
          setState(() => _processing = false);
          _snack('Payment cancelled');
        }
        return;
      }

      // 3. ALWAYS verify server-side — the WebView outcome is never trusted
      //    to move money on its own.
      final verify = await PaymentApi.verifyEsewa(intent.paymentId);
      if (!mounted) return;
      final status = verify['status'] as String?;
      setState(() => _processing = false);

      if (status == 'completed') {
        final newBalance = (verify['balance'] as num?)?.toDouble() ?? _balance;
        setState(() => _balance = newBalance);
        await _showSuccess(amount.toDouble(), newBalance);
        if (mounted) context.pop(true); // signal caller: wallet topped up
      } else if (status == 'pending') {
        _snack(
          'Payment is being confirmed. Your balance will update shortly.',
        );
        await _load();
      } else {
        setState(
          () => _error = 'Payment was not completed. You were not charged.',
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = e.message;
      });
    }
  }

  Future<void> _showSuccess(double amount, double balance) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 48,
        ),
        title: const Text('Top-Up Successful'),
        content: Text(
          'NPR ${amount.toStringAsFixed(0)} added to your wallet.\n'
          'New balance: NPR ${balance.toStringAsFixed(0)}',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.driver,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        title: const Text('Top Up'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.driver),
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.screenPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _balancePill(),
                          const SizedBox(height: 24),
                          const Text(
                            'Amount',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _amountField(),
                          const SizedBox(height: 12),
                          _quickChips(),
                          const SizedBox(height: 28),
                          const Text(
                            'Payment method',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._methods.map(_methodTile),
                          ..._saved.map(_methodTile),
                          const SizedBox(height: 12),
                          _addMethodTile(),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _payBar(),
                ],
              ),
            ),
    );
  }

  Widget _balancePill() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.driver, Color(0xFF0E7A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Balance',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'NPR ${_balance.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountField() {
    return TextField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(7),
      ],
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        prefixText: 'NPR ',
        hintText: '0',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  Widget _quickChips() {
    return Wrap(
      spacing: 8,
      children: [500, 1000, 2000, 5000]
          .map(
            (v) => ActionChip(
              label: Text('NPR $v'),
              backgroundColor: Colors.white,
              onPressed: () => setState(() {
                _amountController.text = v.toString();
                _error = null;
              }),
            ),
          )
          .toList(),
    );
  }

  Widget _methodTile(Map<String, dynamic> m) {
    final id = m['id'] as String?;
    final enabled = m['enabled'] == true;
    final selected = _selectedMethodId == id;
    final isSandbox = m['environment'] == 'sandbox';
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? () => setState(() => _selectedMethodId = id) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: selected ? AppColors.driver : AppColors.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.driverLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.driver,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${m['label'] ?? 'Payment'}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isSandbox) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SANDBOX',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (m['subtitle'] != null)
                      Text(
                        '${m['subtitle']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.driver : AppColors.textTertiary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addMethodTile() {
    return GestureDetector(
      onTap: () => _snack(
        'Bank accounts, cards and other wallets are coming soon.',
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: AppColors.border,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Add payment method',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const Text(
              'Soon',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _payBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SizedBox(
        width: double.infinity,
        height: AppSpacing.buttonHeight,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.driver),
          onPressed: _processing ? null : _pay,
          child: _processing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Continue to Pay',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}
