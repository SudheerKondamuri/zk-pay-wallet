import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../providers/intents_providers.dart';
import '../../../providers/services_providers.dart';
import '../../../shared/empty_state.dart';
import '../../../shared/error_state.dart';
import '../../../shared/flat_card.dart';
import '../../../shared/skeleton_loader.dart';

/// Screen 14 — History. Outgoing intents list (from_address only).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.read(walletServiceProvider);
    final filter = IntentsFilter(address: wallet.address);
    final intents = ref.watch(intentsProvider(filter));

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: intents.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No transactions yet',
              subtitle: 'Your outgoing L2 transfers will appear here.',
            );
          }
          // Sort by id descending.
          list.sort(
              (a, b) => (b['id'] as int).compareTo(a['id'] as int));

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: list.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final intent = list[index] as Map<String, dynamic>;
              return _IntentRow(intent: intent);
            },
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
          message: 'Failed to load history',
          onRetry: () => ref.invalidate(intentsProvider(filter)),
        ),
      ),
    );
  }
}

class _IntentRow extends StatelessWidget {
  final Map<String, dynamic> intent;

  const _IntentRow({required this.intent});

  @override
  Widget build(BuildContext context) {
    final status = intent['status'] as String? ?? 'pending';
    final toAddr = intent['to_address'] as String? ?? '';
    final amountWei = intent['amount_wei']?.toString() ?? '0';

    Color statusColor;
    switch (status) {
      case 'batched':
        statusColor = AppColors.secondaryGold;
        break;
      case 'pending':
        statusColor = AppColors.primaryAccent;
        break;
      default:
        statusColor = AppColors.textMuted;
    }

    return FlatCard(
      onTap: () => context.push(
        AppRoutes.intentDetail,
        extra: intent,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryAccent.withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.arrow_upward,
              size: 18,
              color: AppColors.primaryAccent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To: ${shortenAddress(toAddr)}',
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
                      status,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: statusColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '-${weiToEth(amountWei)} ETH',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontFamily: 'SpaceGrotesk',
                ),
          ),
        ],
      ),
    );
  }
}
