import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants.dart';
import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../providers/services_providers.dart';
import '../providers/wallet_providers.dart';
import '../../../shared/app_bottom_sheet.dart';
import '../../../shared/app_button.dart';
import '../../../shared/app_text_field.dart';
import 'review_sign_sheet.dart';

/// Screen 10 — Send. Address input (with QR scan), amount, invokes review sheet.
class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  String? _addressError;
  String? _amountError;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _openScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: MobileScanner(
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final code = barcodes.first.rawValue ?? '';
                // Strip ethereum: prefix if present.
                final address = code.startsWith('ethereum:')
                    ? code.substring(9).split('@').first
                    : code;
                _addressController.text = address;
                Navigator.of(context).pop();
              }
            },
          ),
        ),
      ),
    );
  }

  void _review() {
    // Validate address
    final to = _addressController.text.trim();
    if (!isValidEthAddress(to)) {
      setState(() => _addressError = 'Enter a valid Ethereum address');
      return;
    }
    setState(() => _addressError = null);

    // Validate amount
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() => _amountError = 'Enter an amount');
      return;
    }
    final weiString = ethToWei(amountText);
    if (weiString == '0') {
      setState(() => _amountError = 'Amount must be greater than zero');
      return;
    }
    setState(() => _amountError = null);

    // Check against L2 balance
    final wallet = ref.read(walletServiceProvider);
    final l2 = ref.read(l2BalanceProvider(wallet.address));
    l2.whenData((balanceWei) {
      final balance = BigInt.parse(balanceWei);
      final amount = BigInt.parse(weiString);
      if (amount > balance) {
        setState(() => _amountError = 'Exceeds your L2 balance');
        return;
      }

      // Open review sheet
      AppBottomSheet.show(
        context: context,
        child: ReviewSignSheet(
          toAddress: to,
          amountWei: weiString,
          amountDisplay: amountText,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.base),
              // Recipient
              AppTextField(
                controller: _addressController,
                labelText: 'Recipient address',
                hintText: '0x...',
                errorText: _addressError,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, size: 20),
                  color: AppColors.textSecondary,
                  onPressed: _openScanner,
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              // Amount
              AppTextField(
                controller: _amountController,
                labelText: 'Amount (ETH)',
                hintText: '0.0',
                errorText: _amountError,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Balance hint
              Consumer(builder: (context, ref, _) {
                final wallet = ref.read(walletServiceProvider);
                if (!wallet.isLoaded) return const SizedBox.shrink();
                final l2 = ref.watch(l2BalanceProvider(wallet.address));
                return l2.when(
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
                );
              }),
              const Spacer(),
              AppButton(
                label: 'Review',
                onPressed: _review,
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
