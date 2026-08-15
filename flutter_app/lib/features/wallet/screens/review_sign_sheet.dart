import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../app/router.dart';

import '../../../core/utils.dart';
import '../../history/providers/intents_providers.dart';
import '../../../providers/services_providers.dart';
import '../../../shared/app_button.dart';
import '../../../shared/glass_card.dart';

/// Screen 11 — Review & Sign. Glass bottom sheet confirming the intent
/// before submitting to POST /intents.
class ReviewSignSheet extends ConsumerStatefulWidget {
  final String toAddress;
  final String amountWei;
  final String amountDisplay;

  const ReviewSignSheet({
    super.key,
    required this.toAddress,
    required this.amountWei,
    required this.amountDisplay,
  });

  @override
  ConsumerState<ReviewSignSheet> createState() => _ReviewSignSheetState();
}

class _ReviewSignSheetState extends ConsumerState<ReviewSignSheet> {
  bool _isSigning = false;

  Future<void> _sign() async {
    setState(() => _isSigning = true);
    HapticFeedback.mediumImpact();

    final wallet = ref.read(walletServiceProvider);
    final notifier = ref.read(submitIntentProvider.notifier);
    final success = await notifier.submit(
      wallet.address,
      widget.toAddress,
      widget.amountWei,
    );

    if (!mounted) return;

    Navigator.of(context).pop(); // Close sheet

    context.push(
      AppRoutes.transactionResult,
      extra: {
        'success': success,
        'type': 'send',
        'amount': widget.amountDisplay,
        'to': widget.toAddress,
      },
    );
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
            'Confirm Transfer',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              children: [
                _DetailRow(
                  label: 'To',
                  value: shortenAddress(widget.toAddress),
                  mono: true,
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  label: 'Amount',
                  value: '${widget.amountDisplay} ETH',
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  label: 'Type',
                  value: 'L2 Intent',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This creates an L2 transfer intent. It will be batched and submitted to the rollup.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Sign & Submit',
            onPressed: _sign,
            isLoading: _isSigning,
            icon: Icons.check,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
            isPrimary: false,
          ),
          const SizedBox(height: AppSpacing.base),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _DetailRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontFamily: mono ? 'SpaceGrotesk' : null,
              ),
        ),
      ],
    );
  }
}
