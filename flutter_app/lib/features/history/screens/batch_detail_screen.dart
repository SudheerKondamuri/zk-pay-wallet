import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';

import '../../../core/utils.dart';
import '../providers/batches_providers.dart';
import '../../../shared/error_state.dart';
import '../../../shared/flat_card.dart';
import '../../../shared/skeleton_loader.dart';

/// Screen 17 — Batch Detail. Shows batch metadata and its intents.
class BatchDetailScreen extends ConsumerWidget {
  final int batchIndex;

  const BatchDetailScreen({super.key, required this.batchIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(batchDetailProvider(batchIndex));

    return Scaffold(
      appBar: AppBar(title: Text('Batch #$batchIndex')),
      body: detail.when(
        data: (data) {
          final batch = data['batch'] as Map<String, dynamic>? ?? {};
          final intents = data['intents'] as List<dynamic>? ?? [];
          final stateRoot = batch['new_state_root'] as String? ?? '';
          final txHash = batch['tx_hash'] as String? ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Batch metadata
                FlatCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MetaRow(label: 'Batch index', value: '#$batchIndex'),
                      const SizedBox(height: AppSpacing.sm),
                      _MetaRow(
                          label: 'State root',
                          value: shortenAddress(stateRoot)),
                      if (txHash.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _MetaRow(
                            label: 'Tx hash',
                            value: shortenAddress(txHash)),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      _MetaRow(
                          label: 'Intents',
                          value: '${intents.length}'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Intents in this batch',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                // Intent list
                ...intents.map((intent) {
                  final i = intent as Map<String, dynamic>;
                  final from = i['from_address'] as String? ?? '';
                  final to = i['to_address'] as String? ?? '';
                  final amountWei = i['amount_wei']?.toString() ?? '0';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: FlatCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${shortenAddress(from)} → ${shortenAddress(to)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontFamily: 'SpaceGrotesk'),
                              ),
                              Text(
                                '${weiToEth(amountWei)} ETH',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontFamily: 'SpaceGrotesk'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: SkeletonLoader(lineCount: 6),
        ),
        error: (e, stack) => ErrorState(
          message: 'Failed to load batch',
          onRetry: () => ref.invalidate(batchDetailProvider(batchIndex)),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontFamily: 'SpaceGrotesk',
              ),
        ),
      ],
    );
  }
}
