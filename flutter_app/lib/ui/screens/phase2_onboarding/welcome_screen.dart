import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../shared/app_button.dart';

/// Screen 2 — Welcome. Two CTA paths: Create or Import.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Hero visual
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryAccent.withValues(alpha: 0.2),
                      AppColors.primaryAccent.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppColors.primaryAccent.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 44,
                  color: AppColors.primaryAccent,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Welcome to ZK Vault',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Self-custody ZK rollup wallet.\nYour keys never leave this device.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              // CTAs
              AppButton(
                label: 'Create new wallet',
                onPressed: () => context.push(AppRoutes.seedGeneration),
                width: double.infinity,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Import existing wallet',
                onPressed: () => context.push(AppRoutes.importWallet),
                isPrimary: false,
                width: double.infinity,
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
