import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../providers/batches_providers.dart';
import '../../../shared/empty_state.dart';
import '../../../shared/error_state.dart';
import '../../../shared/flat_card.dart';
import '../../../shared/skeleton_loader.dart';

/// Screen 16 — Batch Explorer. List of all batches.
class BatchExplorerScreen extends ConsumerWidget {
  const BatchExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(batchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ZK Batches')),
      body: batches.when(
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(batchesProvider);
                await ref.read(batchesProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.layers_outlined,
                    title: 'No batches yet',
                    subtitle: 'Batches appear here after the relayer commits them on-chain.',
                  ),
                ],
              ),
            );
          }
          // Sort descending by batch_index.
          final sortedList = List<dynamic>.from(list);
          sortedList.sort((a, b) => (((b as Map)['batch_index'] as int?) ?? 0)
              .compareTo(((a as Map)['batch_index'] as int?) ?? 0));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(batchesProvider);
              await ref.read(batchesProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: sortedList.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final batch = sortedList[index] as Map<String, dynamic>;
                final batchIndex = (batch['batch_index'] as num?)?.toInt() ?? 0;
                final txCount = (batch['tx_count'] as num?)?.toInt() ??
                    (batch['intent_count'] as num?)?.toInt() ??
                    0;
                final txHash = batch['tx_hash'] as String? ?? '';
                final stateRoot = batch['new_state_root'] as String? ?? '';

                return FlatCard(
                  onTap: () => context.push(
                    AppRoutes.batchDetail,
                    extra: batchIndex,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryAccent.withValues(alpha: 0.12),
                          border: Border.all(
                            color: AppColors.primaryAccent.withValues(alpha: 0.3),
                            width: 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '#$batchIndex',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: AppColors.primaryAccent,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'SpaceGrotesk',
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '$txCount item${txCount == 1 ? '' : 's'} committed',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceBorder.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Settled',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.primaryAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (stateRoot.isNotEmpty)
                              Text(
                                'Root: ${stateRoot.length > 16 ? "${stateRoot.substring(0, 8)}...${stateRoot.substring(stateRoot.length - 6)}" : stateRoot}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontFamily: 'SpaceGrotesk',
                                      color: AppColors.textMuted,
                                    ),
                              ),
                            if (txHash.isNotEmpty)
                              Text(
                                'Tx: ${txHash.length > 16 ? "${txHash.substring(0, 8)}...${txHash.substring(txHash.length - 6)}" : txHash}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontFamily: 'SpaceGrotesk',
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: List.generate(
              4,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: SkeletonLoader(lineCount: 2),
              ),
            ),
          ),
        ),
        error: (e, stack) => ErrorState(
          message: 'Failed to load batches',
          onRetry: () => ref.invalidate(batchesProvider),
        ),
      ),
    );
  }
}
