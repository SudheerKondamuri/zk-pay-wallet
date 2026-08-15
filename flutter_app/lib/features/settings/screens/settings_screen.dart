import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../providers/services_providers.dart';
import '../providers/settings_providers.dart';
import '../../../shared/flat_card.dart';

/// Screen 18 — Settings. Network config, biometrics, address book, danger zone.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(securitySettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Network section
              Text('Network',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              FlatCard(
                onTap: () => context.push(AppRoutes.networkConfig),
                child: Row(
                  children: [
                    const Icon(Icons.dns_outlined,
                        color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text('Network Configuration',
                          style: Theme.of(context).textTheme.labelLarge),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textMuted, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Security section
              Text('Security',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              FlatCard(
                child: Row(
                  children: [
                    const Icon(Icons.fingerprint,
                        color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text('Biometric Unlock',
                          style: Theme.of(context).textTheme.labelLarge),
                    ),
                    security.when(
                      data: (settings) => Switch.adaptive(
                        value: settings.biometricEnabled,
                        activeTrackColor: AppColors.primaryAccent,
                        onChanged: (v) {
                          ref
                              .read(securitySettingsProvider.notifier)
                              .setBiometricEnabled(v);
                        },
                      ),
                      loading: () => const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (err, stack) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Address book section
              Text('Contacts',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              FlatCard(
                onTap: () => context.push(AppRoutes.addressBook),
                child: Row(
                  children: [
                    const Icon(Icons.contacts_outlined,
                        color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text('Address Book',
                          style: Theme.of(context).textTheme.labelLarge),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textMuted, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Danger zone
              Text('Danger Zone',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppColors.danger)),
              const SizedBox(height: AppSpacing.md),
              FlatCard(
                onTap: () => _showResetDialog(context, ref),
                child: Row(
                  children: [
                    const Icon(Icons.delete_forever,
                        color: AppColors.danger, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'Reset Wallet',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: AppColors.danger),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceFlat,
        title: const Text('Reset Wallet?'),
        content: const Text(
            'This will erase your private key and all local data. '
            'Make sure you have your recovery phrase saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final storage = ref.read(secureStorageServiceProvider);
              await storage.clearAll();
              ref.read(authStateProvider.notifier).setHasWallet(false);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                context.go(AppRoutes.welcome);
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
