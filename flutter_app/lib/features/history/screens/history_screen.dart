import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../models/activity_item.dart';
import '../providers/intents_providers.dart';
import '../../../providers/services_providers.dart';
import '../../../shared/empty_state.dart';
import '../../../shared/error_state.dart';
import '../../../shared/flat_card.dart';
import '../../../shared/skeleton_loader.dart';

/// Screen 14 — History. Unified activity log (Sends, Deposits, Withdrawals).
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  ActivityFilterType _selectedFilter = ActivityFilterType.all;

  @override
  Widget build(BuildContext context) {
    final wallet = ref.read(walletServiceProvider);
    final filter = ActivityFilter(
      address: wallet.address,
      type: _selectedFilter,
    );
    final activities = ref.watch(unifiedActivityProvider(filter));

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: Column(
        children: [
          // Filter chip row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                _buildFilterChip('All', ActivityFilterType.all),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip('Sent', ActivityFilterType.sent),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip('Deposits', ActivityFilterType.deposits),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip('Withdrawals', ActivityFilterType.withdrawals),
              ],
            ),
          ),
          const Divider(),
          // Activity list
          Expanded(
            child: activities.when(
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No activity found',
                    subtitle: _emptySubtitle(_selectedFilter),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primaryAccent,
                  backgroundColor: AppColors.surfaceFlat,
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    ref.invalidate(unifiedActivityProvider(filter));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: list.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return _ActivityRow(item: item);
                    },
                  ),
                );
              },
              loading: () => Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: List.generate(
                    5,
                    (index) => const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.md),
                      child: SkeletonLoader(lineCount: 2),
                    ),
                  ),
                ),
              ),
              error: (e, stack) => ErrorState(
                message: 'Failed to load activity history',
                onRetry: () => ref.invalidate(unifiedActivityProvider(filter)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ActivityFilterType type) {
    final isSelected = _selectedFilter == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          HapticFeedback.selectionClick();
          setState(() => _selectedFilter = type);
        }
      },
      selectedColor: AppColors.primaryAccent.withValues(alpha: 0.2),
      backgroundColor: AppColors.surfaceFlat,
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
        color: isSelected ? AppColors.primaryAccent : AppColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primaryAccent : AppColors.divider,
        ),
      ),
      showCheckmark: false,
    );
  }

  String _emptySubtitle(ActivityFilterType type) {
    switch (type) {
      case ActivityFilterType.sent:
        return 'Your outgoing L2 transfers will appear here.';
      case ActivityFilterType.deposits:
        return 'Your on-chain ETH deposits will appear here.';
      case ActivityFilterType.withdrawals:
        return 'Your rollup withdrawals will appear here.';
      case ActivityFilterType.all:
        return 'Transactions and intents will appear here.';
    }
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityItem item;

  const _ActivityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;

    switch (item.status) {
      case ActivityStatus.batched:
      case ActivityStatus.confirmed:
        statusColor = AppColors.secondaryGold;
        statusLabel = item.status == ActivityStatus.batched ? 'batched' : 'confirmed';
        break;
      case ActivityStatus.failed:
        statusColor = AppColors.danger;
        statusLabel = 'failed';
        break;
      case ActivityStatus.pending:
        statusColor = AppColors.primaryAccent;
        statusLabel = 'pending';
    }

    IconData icon;
    Color iconColor;
    String title;
    String amountPrefix;

    switch (item.type) {
      case ActivityType.deposit:
        icon = Icons.arrow_downward;
        iconColor = AppColors.secondaryGold;
        title = 'Deposit';
        amountPrefix = '+';
        break;
      case ActivityType.withdraw:
        icon = Icons.arrow_outward;
        iconColor = AppColors.primaryAccent;
        title = 'Withdrawal';
        amountPrefix = '-';
        break;
      case ActivityType.send:
        icon = Icons.arrow_upward;
        iconColor = AppColors.primaryAccent;
        title = item.toAddress != null
            ? 'To ${shortenAddress(item.toAddress!)}'
            : 'Transfer';
        amountPrefix = '-';
    }

    return FlatCard(
      onTap: () => context.push(
        AppRoutes.intentDetail,
        extra: item.toJson(),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.1),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontFamily: 'SpaceGrotesk',
                      ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: statusColor),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(item.timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '$amountPrefix${weiToEth(item.amountWei)} ETH',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontFamily: 'SpaceGrotesk',
                  color: item.type == ActivityType.deposit
                      ? AppColors.secondaryGold
                      : AppColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}';
  }
}
