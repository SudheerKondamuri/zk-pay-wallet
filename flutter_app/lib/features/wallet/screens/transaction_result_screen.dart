import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../shared/app_button.dart';

/// Screen 13 — Transaction Result. Success/failure with next actions.
class TransactionResultScreen extends StatelessWidget {
  final bool success;
  final String type; // 'send' | 'deposit' | 'withdraw'
  final String amount;
  final String? toAddress;
  final String? txHash;

  const TransactionResultScreen({
    super.key,
    required this.success,
    required this.type,
    required this.amount,
    this.toAddress,
    this.txHash,
  });

  String _title() {
    if (!success) return 'Transaction failed';
    switch (type) {
      case 'deposit':
        return 'Deposit confirmed';
      case 'withdraw':
        return 'Withdrawal confirmed';
      case 'send':
      default:
        return 'Intent submitted';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(),
              // Result icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: success
                      ? AppColors.secondaryGold.withValues(alpha: 0.15)
                      : AppColors.danger.withValues(alpha: 0.15),
                ),
                child: Icon(
                  success ? Icons.check : Icons.close,
                  size: 40,
                  color: success ? AppColors.secondaryGold : AppColors.danger,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _title(),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$amount ETH',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontFamily: 'SpaceGrotesk',
                    ),
              ),
              if (toAddress != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'To: ${shortenAddress(toAddress!)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'SpaceGrotesk',
                      ),
                ),
              ],
              if (txHash != null) ...[
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: txHash!));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaction hash copied')),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tx: ${shortenAddress(txHash!)}',
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
              const Spacer(),
              AppButton(
                label: 'Back to dashboard',
                onPressed: () => context.go(AppRoutes.dashboard),
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
