import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants.dart';
import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../shared/flat_card.dart';

/// Screen 15 — Intent Detail. All fields from a single intent.
class IntentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> intent;

  const IntentDetailScreen({super.key, required this.intent});

  @override
  Widget build(BuildContext context) {
    final id = intent['id']?.toString() ?? '—';
    final from = intent['from_address'] as String? ?? '';
    final to = intent['to_address'] as String? ?? '';
    final amountWei = intent['amount_wei']?.toString() ?? '0';
    final status = intent['status'] as String? ?? 'pending';
    final batchIndex = intent['batch_index'];
    final createdAt = intent['created_at'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(title: Text('Intent #$id')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildField(context, 'Status', status, _statusColor(status)),
              const SizedBox(height: AppSpacing.base),
              _buildField(context, 'Amount', '${weiToEth(amountWei)} ETH'),
              const SizedBox(height: AppSpacing.base),
              _buildCopyField(context, 'From', from),
              const SizedBox(height: AppSpacing.base),
              _buildCopyField(context, 'To', to),
              if (batchIndex != null) ...[
                const SizedBox(height: AppSpacing.base),
                _buildField(context, 'Batch', '#$batchIndex'),
              ],
              if (createdAt.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.base),
                _buildField(context, 'Created', createdAt),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'batched':
        return AppColors.secondaryGold;
      case 'pending':
        return AppColors.primaryAccent;
      default:
        return AppColors.textMuted;
    }
  }

  Widget _buildField(BuildContext context, String label, String value,
      [Color? valueColor]) {
    return FlatCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: valueColor,
                  fontFamily: 'SpaceGrotesk',
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyField(BuildContext context, String label, String address) {
    return FlatCard(
      onTap: () {
        Clipboard.setData(ClipboardData(text: address));
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label address copied')),
        );
      },
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Flexible(
            child: Text(
              shortenAddress(address),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontFamily: 'SpaceGrotesk',
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.copy, size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
