import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../shared/app_button.dart';

/// Screen 13 — Transaction Result. Success/failure with next actions.
class TransactionResultScreen extends StatelessWidget {
  final bool success;
  final String type; // 'send' | 'withdraw'
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
                success
                    ? (type == 'send' ? 'Intent Submitted' : 'Withdrawal Sent')
                    : 'Transaction Failed',
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
                Text(
                  'Tx: ${shortenAddress(txHash!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'SpaceGrotesk',
                      ),
                ),
              ],
              const Spacer(),
              AppButton(
                label: 'Back to Dashboard',
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
