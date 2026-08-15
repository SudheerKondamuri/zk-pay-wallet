import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants.dart';
import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../models/activity_item.dart';
import '../../../shared/flat_card.dart';

/// Screen 15 — Activity / Intent Detail. All fields from an activity record.
class IntentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> intent;

  const IntentDetailScreen({super.key, required this.intent});

  @override
  Widget build(BuildContext context) {
    // Deserialize or parse from map
    final item = ActivityItem.fromJson(intent);

    String title;
    switch (item.type) {
      case ActivityType.deposit:
        title = 'Deposit';
        break;
      case ActivityType.withdraw:
        title = 'Withdrawal';
        break;
      case ActivityType.send:
        title = 'Transfer intent #${item.id}';
        break;
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildField(
                context,
                'Status',
                item.status.name,
                _statusColor(item.status),
              ),
              const SizedBox(height: AppSpacing.base),
              _buildField(
                context,
                'Type',
                item.type.name.toUpperCase(),
                item.type == ActivityType.deposit
                    ? AppColors.secondaryGold
                    : AppColors.primaryAccent,
              ),
              const SizedBox(height: AppSpacing.base),
              _buildField(
                context,
                'Amount',
                '${weiToEth(item.amountWei)} ETH',
              ),
              if (item.fromAddress != null && item.fromAddress!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.base),
                _buildCopyField(context, 'From', item.fromAddress!),
              ],
              if (item.toAddress != null && item.toAddress!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.base),
                _buildCopyField(context, 'To', item.toAddress!),
              ],
              if (item.txHash != null && item.txHash!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.base),
                _buildCopyField(context, 'Tx hash', item.txHash!),
              ],
              if (item.batchIndex != null) ...[
                const SizedBox(height: AppSpacing.base),
                _buildField(context, 'Batch', '#${item.batchIndex}'),
              ],
              const SizedBox(height: AppSpacing.base),
              _buildField(
                context,
                'Time',
                item.timestamp.toLocal().toString().split('.').first,
              ),
              if (item.status == ActivityStatus.pending && item.type == ActivityType.send) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withValues(alpha: 0.08),
                    borderRadius: AppRadius.cardBorder,
                    border: Border.all(
                      color: AppColors.primaryAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.primaryAccent,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Pending batch creation — intents are grouped and settled on-chain periodically.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(ActivityStatus status) {
    switch (status) {
      case ActivityStatus.batched:
      case ActivityStatus.confirmed:
        return AppColors.secondaryGold;
      case ActivityStatus.failed:
        return AppColors.danger;
      case ActivityStatus.pending:
        return AppColors.primaryAccent;
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

  Widget _buildCopyField(BuildContext context, String label, String value) {
    return FlatCard(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label copied to clipboard')),
        );
      },
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Flexible(
            child: Text(
              shortenAddress(value),
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
