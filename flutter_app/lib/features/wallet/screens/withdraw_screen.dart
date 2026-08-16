import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../providers/services_providers.dart';
import '../../history/models/activity_item.dart';
import '../providers/wallet_providers.dart';
import '../../../shared/app_button.dart';
import '../../../shared/app_text_field.dart';

enum WithdrawStep { idle, submitting, confirming }

/// Screen 12 — Withdraw. Withdraw ETH from rollup contract (L1 on-chain).
/// Amount capped at on-chain deposits(address).
class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  final _amountController = TextEditingController();
  String? _error;
  WithdrawStep _step = WithdrawStep.idle;
  String? _txHash;

  @override
  void initState() {
    super.initState();
    // Refresh balances on screen entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = ref.read(walletServiceProvider);
      if (wallet.isLoaded) {
        ref.read(l2BalanceProvider(wallet.address).notifier).refresh();
        ref.read(onChainDepositProvider(wallet.address).notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() => _error = 'Enter an amount');
      return;
    }

    final weiString = ethToWei(amountText);
    if (weiString == '0') {
      setState(() => _error = 'Amount must be greater than zero');
      return;
    }

    setState(() {
      _error = null;
      _step = WithdrawStep.submitting;
    });

    final wallet = ref.read(walletServiceProvider);
    final api = ref.read(apiServiceProvider);
    final storage = ref.read(secureStorageServiceProvider);

    try {
      // Check live L2 spendable balance
      final l2Data = await api.getDeposit(wallet.address);
      final l2BalanceWei = l2Data['balanceWei'] as String? ?? '0';

      if (BigInt.parse(weiString) > BigInt.parse(l2BalanceWei)) {
        setState(() {
          _step = WithdrawStep.idle;
          _error = 'Exceeds available balance (${formatBalance(l2BalanceWei)})';
        });
        return;
      }

      // Execute rollup withdrawal via backend relayer exit
      final result = await api.submitWithdrawal(wallet.address, weiString);
      final txHash = result['txHash'] as String? ?? '';

      HapticFeedback.mediumImpact();

      final activity = ActivityItem(
        id: txHash.isNotEmpty ? txHash : DateTime.now().millisecondsSinceEpoch.toString(),
        type: ActivityType.withdraw,
        amountWei: weiString,
        fromAddress: wallet.address,
        txHash: txHash.isNotEmpty ? txHash : null,
        timestamp: DateTime.now(),
        status: ActivityStatus.confirmed,
      );
      await storage.saveLocalActivity(wallet.address, activity.toJson());

      ref.read(onChainDepositProvider(wallet.address).notifier).refresh();
      ref.read(l2BalanceProvider(wallet.address).notifier).refresh();

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      context.push(
        AppRoutes.transactionResult,
        extra: {
          'success': true,
          'type': 'withdraw',
          'amount': amountText,
          'txHash': txHash,
        },
      );
    } catch (e, stack) {
      debugPrint('Withdraw error: $e\n$stack');
      HapticFeedback.heavyImpact();
      if (mounted) {
        final msg = e.toString();
        setState(() {
          _step = WithdrawStep.idle;
          if (msg.contains('Insufficient') || msg.contains('insufficient')) {
            _error = 'Insufficient rollup balance to complete withdrawal';
          } else if (msg.contains('Amount must be greater than 0') || msg.contains('amount zero')) {
            _error = 'Withdrawal amount must be greater than zero';
          } else if (msg.contains('paused')) {
            _error = 'Contract is temporarily paused';
          } else if (msg.contains('insufficient contract balance')) {
            _error = 'Vault contract has insufficient liquidity for this withdrawal';
          } else if (msg.contains('4000') || msg.contains('SocketException')) {
            _error = 'Cannot reach backend server. Check connection.';
          } else {
            _error = 'Withdrawal could not be completed. Try again.';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.read(walletServiceProvider);
    final l2Balance = ref.watch(l2BalanceProvider(wallet.address));

    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.base),
              Text(
                _step == WithdrawStep.confirming
                    ? 'Confirming withdrawal on-chain...'
                    : 'Withdraw ETH from the rollup contract back to your L1 wallet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_step == WithdrawStep.confirming && _txHash != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: AppRadius.cardBorder,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primaryAccent,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _txHash!));
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Transaction hash copied')),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Tx: ${shortenAddress(_txHash!)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontFamily: 'SpaceGrotesk',
                                    color: AppColors.primaryAccent,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy, size: 14, color: AppColors.primaryAccent),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ] else ...[
                AppTextField(
                  controller: _amountController,
                  labelText: 'Amount (ETH)',
                  hintText: '0.0',
                  errorText: _error,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  enabled: _step == WithdrawStep.idle,
                ),
                const SizedBox(height: AppSpacing.sm),
                // L2 spendable balance ceiling
                l2Balance.when(
                  data: (wei) => Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        _amountController.text = weiToEth(wei);
                      },
                      child: Text(
                        'Available: ${formatBalance(wei)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primaryAccent,
                            ),
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (err, stack) => const SizedBox.shrink(),
                ),
              ],
              const Spacer(),
              if (_step != WithdrawStep.confirming)
                AppButton(
                  label: _step == WithdrawStep.submitting
                      ? 'Broadcasting...'
                      : 'Withdraw',
                  onPressed: _submit,
                  isLoading: _step == WithdrawStep.submitting,
                  width: double.infinity,
                ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
