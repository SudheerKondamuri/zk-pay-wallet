import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../core/utils.dart';
import '../../../providers/services_providers.dart';
import '../../history/models/activity_item.dart';
import '../providers/wallet_providers.dart';
import '../../../shared/app_button.dart';
import '../../../shared/app_text_field.dart';

enum DepositStep { idle, submitting, confirming }

/// Bottom sheet for L1 deposit (amount → sign & broadcast → confirm on-chain).
/// Triggered from Dashboard or Receive screen.
class DepositSheet extends ConsumerStatefulWidget {
  const DepositSheet({super.key});

  @override
  ConsumerState<DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends ConsumerState<DepositSheet> {
  final _amountController = TextEditingController();
  String? _error;
  DepositStep _step = DepositStep.idle;
  String? _txHash;

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

    // Validate it's a valid number string (no doubles in the pipeline).
    final parts = amountText.split('.');
    if (parts.length > 2) {
      setState(() => _error = 'Invalid amount');
      return;
    }

    final weiString = ethToWei(amountText);
    if (weiString == '0') {
      setState(() => _error = 'Amount must be greater than zero');
      return;
    }

    setState(() {
      _error = null;
      _step = DepositStep.submitting;
    });

    final wallet = ref.read(walletServiceProvider);

    try {
      // Step 1: Ensure contract address is resolved
      final contractAddress = await ref
          .read(contractAddressProvider.notifier)
          .ensureAddress();
      wallet.setContractAddress(contractAddress);

      // Step 2: Sign and broadcast transaction
      final txHash = await wallet.deposit(weiString);
      HapticFeedback.mediumImpact();

      final storage = ref.read(secureStorageServiceProvider);
      final activity = ActivityItem(
        id: txHash,
        type: ActivityType.deposit,
        amountWei: weiString,
        fromAddress: wallet.address,
        txHash: txHash,
        timestamp: DateTime.now(),
        status: ActivityStatus.pending,
      );
      await storage.saveLocalActivity(wallet.address, activity.toJson());

      if (!mounted) return;
      setState(() {
        _step = DepositStep.confirming;
        _txHash = txHash;
      });

      // Step 3: Poll for on-chain block confirmation
      final receipt = await wallet.waitForReceipt(txHash);

      if (!mounted) return;

      if (receipt != null) {
        await storage.saveLocalActivity(
          wallet.address,
          activity.copyWith(status: ActivityStatus.confirmed).toJson(),
        );

        // Refresh balance providers after on-chain confirmation
        ref.read(onChainDepositProvider(wallet.address).notifier).refresh();
        ref.read(l2BalanceProvider(wallet.address).notifier).refresh();

        if (!mounted) return;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(txHash);

        context.push(
          AppRoutes.transactionResult,
          extra: {
            'success': true,
            'type': 'deposit',
            'amount': amountText,
            'txHash': txHash,
          },
        );
      } else {
        await storage.saveLocalActivity(
          wallet.address,
          activity.copyWith(status: ActivityStatus.failed).toJson(),
        );
        setState(() {
          _step = DepositStep.idle;
          _error = 'Confirmation timed out. Check your transaction on-chain.';
        });
      }
    } catch (e, stack) {
      debugPrint('Deposit error: $e\n$stack');
      HapticFeedback.heavyImpact();
      if (mounted) {
        final msg = e.toString();
        setState(() {
          _step = DepositStep.idle;
          if (msg.contains('insufficient funds')) {
            _error = 'Insufficient L1 ETH balance for amount + gas';
          } else if (msg.contains('amount zero')) {
            _error = 'Deposit amount must be greater than zero';
          } else if (msg.contains('ZKRollup: paused') || msg.contains('paused')) {
            _error = 'Contract is temporarily paused';
          } else if (msg.contains('4000')) {
            _error = 'Cannot reach backend server. Check connection.';
          } else if (msg.contains('8545') || msg.contains('SocketException')) {
            _error = 'Cannot reach blockchain RPC node. Check connection.';
          } else {
            _error = 'Deposit could not be completed. Try again.';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _step == DepositStep.confirming
                ? 'Confirming Deposit'
                : 'Deposit ETH',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _step == DepositStep.confirming
                ? 'Transaction broadcast on-chain. Waiting for block confirmation...'
                : 'Send ETH from your wallet to the rollup contract. This is an on-chain transaction signed on your device.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_step == DepositStep.confirming && _txHash != null) ...[
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
              hintText: '0.0',
              labelText: 'Amount (ETH)',
              errorText: _error,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: _step == DepositStep.idle,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: _step == DepositStep.submitting
                  ? 'Broadcasting...'
                  : 'Deposit',
              onPressed: _submit,
              isLoading: _step == DepositStep.submitting,
            ),
          ],
          const SizedBox(height: AppSpacing.base),
        ],
      ),
    );
  }
}
