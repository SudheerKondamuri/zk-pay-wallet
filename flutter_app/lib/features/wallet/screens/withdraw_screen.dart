import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../providers/services_providers.dart';
import '../providers/wallet_providers.dart';
import '../../../shared/app_button.dart';
import '../../../shared/app_text_field.dart';

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
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Refresh on-chain balance on screen entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = ref.read(walletServiceProvider);
      if (wallet.isLoaded) {
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
      _isSubmitting = true;
    });

    final wallet = ref.read(walletServiceProvider);

    try {
      final contractAddress = await ref
          .read(contractAddressProvider.notifier)
          .ensureAddress();
      wallet.setContractAddress(contractAddress);

      // Check live on-chain deposit ceiling directly from node
      final liveCeiling = await wallet.getOnChainDeposit(wallet.address);
      if (BigInt.parse(weiString) > BigInt.parse(liveCeiling)) {
        setState(() {
          _isSubmitting = false;
          _error = 'Exceeds on-chain balance (${formatBalance(liveCeiling)})';
        });
        return;
      }

      final txHash = await wallet.withdraw(weiString);
      HapticFeedback.mediumImpact();
      ref.read(onChainDepositProvider(wallet.address).notifier).refresh();

      if (mounted) {
        context.push(
          AppRoutes.transactionResult,
          extra: {
            'success': true,
            'type': 'withdraw',
            'amount': amountText,
            'txHash': txHash,
          },
        );
      }
    } catch (e, stack) {
      debugPrint('Withdraw error: $e\n$stack');
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = 'Withdrawal failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.read(walletServiceProvider);
    final onChain = ref.watch(onChainDepositProvider(wallet.address));

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
                'Withdraw ETH from the rollup contract back to your L1 wallet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _amountController,
                labelText: 'Amount (ETH)',
                hintText: '0.0',
                errorText: _error,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: AppSpacing.sm),
              // On-chain ceiling
              onChain.when(
                data: (wei) => Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      _amountController.text = weiToEth(wei);
                    },
                    child: Text(
                      'Max: ${formatBalance(wei)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primaryAccent,
                          ),
                    ),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
              ),
              const Spacer(),
              AppButton(
                label: 'Withdraw',
                onPressed: _submit,
                isLoading: _isSubmitting,
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
