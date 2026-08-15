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
      appBar: AppBar(title: const Text('Batches')),
      body: batches.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.layers_outlined,
              title: 'No batches yet',
              subtitle: 'Batches appear here after the relayer submits them.',
            );
          }
          // Sort descending by batch_index.
          list.sort((a, b) => ((b['batch_index'] as int?) ?? 0)
              .compareTo((a['batch_index'] as int?) ?? 0));

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: list.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final batch = list[index] as Map<String, dynamic>;
              final batchIndex = batch['batch_index'] as int? ?? 0;
              final intentCount = batch['intent_count'] as int? ?? 0;
              final txHash = batch['tx_hash'] as String? ?? '';

              return FlatCard(
                onTap: () => context.push(
                  AppRoutes.batchDetail,
                  extra: batchIndex,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondaryGold.withValues(alpha: 0.1),
                      ),
                      child: Center(
                        child: Text(
                          '#$batchIndex',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: AppColors.secondaryGold,
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
                          Text(
                            '$intentCount intent${intentCount == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          if (txHash.isNotEmpty)
                            Text(
                              txHash.length > 16
                                  ? '${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 6)}'
                                  : txHash,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontFamily: 'SpaceGrotesk'),
                            ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              );
            },
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
