import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/utils.dart';
import '../../../providers/services_providers.dart';

import '../../../shared/app_button.dart';
import '../../../shared/app_text_field.dart';

/// Bottom sheet for L1 deposit (amount → sign → broadcast).
/// Triggered from Dashboard or Receive screen.
class DepositSheet extends ConsumerStatefulWidget {
  const DepositSheet({super.key});

  @override
  ConsumerState<DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends ConsumerState<DepositSheet> {
  final _amountController = TextEditingController();
  String? _error;
  bool _isSubmitting = false;

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
      _isSubmitting = true;
    });

    try {
      // Ensure contract address is loaded and set on the wallet service
      final contractAddress = await ref
          .read(contractAddressProvider.notifier)
          .ensureAddress();
      final wallet = ref.read(walletServiceProvider);
      wallet.setContractAddress(contractAddress);

      final txHash = await wallet.deposit(weiString);

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(txHash);
      }
    } catch (e, stack) {
      debugPrint('Deposit error: $e\n$stack');
      if (mounted) {
        HapticFeedback.heavyImpact();
        final msg = e.toString();
        setState(() {
          _isSubmitting = false;
          if (msg.contains('insufficient funds')) {
            _error = 'Insufficient L1 ETH balance for amount + gas.';
          } else if (msg.contains('4000')) {
            _error = 'Cannot reach backend server (127.0.0.1:4000).';
          } else if (msg.contains('8545')) {
            _error = 'Cannot reach blockchain RPC node (127.0.0.1:8545).';
          } else {
            _error = 'Deposit failed: $e';
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
            'Deposit ETH',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Send ETH from your wallet to the rollup contract. This is an on-chain transaction signed on your device.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _amountController,
            hintText: '0.0',
            labelText: 'Amount (ETH)',
            errorText: _error,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Deposit',
            onPressed: _submit,
            isLoading: _isSubmitting,
          ),
          const SizedBox(height: AppSpacing.base),
        ],
      ),
    );
  }
}
