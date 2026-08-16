import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../providers/rollup_state_provider.dart';
import '../../../providers/services_providers.dart';
import '../providers/wallet_providers.dart';
import '../../../shared/app_bottom_sheet.dart';
import '../widgets/deposit_sheet.dart';
import '../../../shared/flat_card.dart';
import '../../../shared/glass_card.dart';
import '../../../shared/signature_visual.dart';
import '../../../shared/skeleton_loader.dart';

/// Screen 8 — Dashboard. Balance hero, action row, state root visual.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.read(walletServiceProvider);
    if (!wallet.isLoaded) {
      return const Scaffold(
        body: Center(child: Text('Wallet not loaded')),
      );
    }

    final address = wallet.address;
    final l2Balance = ref.watch(l2BalanceProvider(address));
    final onChainBalance = ref.watch(onChainDepositProvider(address));
    final rollupState = ref.watch(rollupStateProvider);

    // Incoming transfer toast
    ref.listen<IncomingTransferEvent?>(incomingTransferProvider, (previous, next) {
      if (next != null) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceFlat,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
            content: Row(
              children: [
                const Icon(Icons.arrow_downward, color: AppColors.primaryAccent, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Received ${formatBalance(next.amountWei)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryAccent,
          backgroundColor: AppColors.surfaceFlat,
          strokeWidth: 2.5,
          displacement: 32,
          edgeOffset: 0,
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            try {
              await Future.wait([
                ref.read(l2BalanceProvider(address).notifier).refresh(),
                ref.read(onChainDepositProvider(address).notifier).refresh(),
                ref.read(rollupStateProvider.notifier).refresh(),
              ]);
            } catch (_) {
              // Ignore transient network errors during refresh
            }
            HapticFeedback.lightImpact();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.base),
              // App bar row
              Row(
                children: [
                  Text('ZK Vault',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.history),
                    color: AppColors.textSecondary,
                    onPressed: () => context.push(AppRoutes.history),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    color: AppColors.textSecondary,
                    onPressed: () => context.push(AppRoutes.settings),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Balance hero — glass card
              GlassCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('L2 Balance',
                            style: Theme.of(context).textTheme.bodyMedium),
                        const LiveSyncBadge(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    l2Balance.when(
                      data: (wei) => Text(
                        formatBalance(wei),
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      loading: () => const BalanceSkeleton(),
                      error: (err, stack) => Text(
                        '—',
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(color: AppColors.danger),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // On-chain deposit subtitle
                    onChainBalance.when(
                      data: (wei) => Text(
                        'On-chain: ${formatBalance(wei)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (err, stack) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action row
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.arrow_downward,
                      label: 'Receive',
                      onTap: () => context.push(AppRoutes.receive),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.arrow_upward,
                      label: 'Send',
                      onTap: () => context.push(AppRoutes.send),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Deposit',
                      onTap: () async {
                        final tx = await AppBottomSheet.show(
                          context: context,
                          child: const DepositSheet(),
                        );
                        if (tx != null) {
                          ref.read(onChainDepositProvider(address).notifier).refresh();
                          ref.read(l2BalanceProvider(address).notifier).refresh();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.output,
                      label: 'Withdraw',
                      onTap: () => context.push(AppRoutes.withdraw),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // State root visualization
              rollupState.when(
                data: (state) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Network State',
                            style: Theme.of(context).textTheme.titleMedium),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryAccent
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.primaryAccent
                                    .withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                state.batchCount == 0
                                    ? 'Genesis'
                                    : '${state.batchCount} settled',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.primaryAccent,
                                      fontFamily: 'SpaceGrotesk',
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.batchExplorer),
                      child: GlassCard(
                        padding: const EdgeInsets.all(AppSpacing.base),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SignatureVisual(
                              stateRoot: state.currentStateRoot,
                              batchCount: state.batchCount,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('State Root',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                      const SizedBox(height: 2),
                                      Text(
                                        shortenAddress(state.currentStateRoot),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                                fontFamily: 'SpaceGrotesk'),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Batches',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${state.batchCount}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                color: AppColors.primaryAccent,
                                                fontFamily: 'SpaceGrotesk',
                                              ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.chevron_right,
                                          size: 16,
                                          color: AppColors.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                loading: () => const SkeletonLoader(lineCount: 4),
                error: (e, stack) => FlatCard(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.invalidate(rollupStateProvider);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.refresh, size: 16, color: AppColors.primaryAccent),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Failed to load state. Tap to retry.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceFlat,
      borderRadius: AppRadius.cardBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primaryAccent, size: 22),
              const SizedBox(height: AppSpacing.xs),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dynamic live synchronization indicator and freshness timer.
class LiveSyncBadge extends ConsumerStatefulWidget {
  const LiveSyncBadge({super.key});

  @override
  ConsumerState<LiveSyncBadge> createState() => _LiveSyncBadgeState();
}

class _LiveSyncBadgeState extends ConsumerState<LiveSyncBadge> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastUpdated = ref.watch(lastUpdatedProvider);
    final isSyncing = ref.watch(isSyncingProvider);

    final diff = DateTime.now().difference(lastUpdated);
    String label;
    if (isSyncing) {
      label = 'Syncing...';
    } else if (diff.inSeconds < 5) {
      label = 'Updated just now';
    } else if (diff.inSeconds < 60) {
      label = 'Updated ${diff.inSeconds}s ago';
    } else {
      label = 'Updated ${diff.inMinutes}m ago';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSyncing
                ? AppColors.primaryAccent
                : AppColors.primaryAccent.withValues(alpha: 0.6),
            boxShadow: isSyncing
                ? [
                    BoxShadow(
                      color: AppColors.primaryAccent.withValues(alpha: 0.7),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

