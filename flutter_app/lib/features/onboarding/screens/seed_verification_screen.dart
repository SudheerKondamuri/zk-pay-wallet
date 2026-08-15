import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../providers/services_providers.dart';
import '../../../shared/app_button.dart';

/// Screen 4 — Seed Verification. Asks user to fill 3 random word slots
/// from the mnemonic they wrote down on Screen 3.
class SeedVerificationScreen extends ConsumerStatefulWidget {
  final String mnemonic;

  const SeedVerificationScreen({super.key, required this.mnemonic});

  @override
  ConsumerState<SeedVerificationScreen> createState() =>
      _SeedVerificationScreenState();
}

class _SeedVerificationScreenState
    extends ConsumerState<SeedVerificationScreen> {
  late List<String> _words;
  late List<int> _challengeIndices;
  final Map<int, TextEditingController> _controllers = {};
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _words = widget.mnemonic.split(' ');
    // Pick 3 random distinct indices to challenge.
    final rng = Random();
    final indices = <int>{};
    while (indices.length < 3) {
      indices.add(rng.nextInt(_words.length));
    }
    _challengeIndices = indices.toList()..sort();
    for (final i in _challengeIndices) {
      _controllers[i] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _verify() async {
    bool allCorrect = true;
    for (final i in _challengeIndices) {
      if (_controllers[i]!.text.trim().toLowerCase() !=
          _words[i].toLowerCase()) {
        allCorrect = false;
        break;
      }
    }

    if (!allCorrect) {
      HapticFeedback.heavyImpact();
      setState(() => _hasError = true);
      return;
    }

    HapticFeedback.mediumImpact();

    // Save wallet.
    final wallet = ref.read(walletServiceProvider);
    final storage = ref.read(secureStorageServiceProvider);
    final privateKey = wallet.derivePrivateKey(widget.mnemonic);
    wallet.loadCredentials(privateKey);
    await storage.saveMnemonic(widget.mnemonic);
    await storage.savePrivateKey(privateKey);

    ref.read(authStateProvider.notifier).setHasWallet(true);

    if (mounted) {
      context.go(AppRoutes.setupPin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify phrase')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.base),
              Text(
                'Fill in the missing words to verify you\'ve saved your recovery phrase.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_hasError) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'One or more words don\'t match. Please try again.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.danger),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView(
                  children: [
                    for (int i = 0; i < _words.length; i++)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _challengeIndices.contains(i)
                            ? _buildChallengeRow(i)
                            : _buildFilledRow(i),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              AppButton(
                label: 'Verify',
                onPressed: _verify,
                width: double.infinity,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilledRow(int index) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            '${index + 1}.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          _words[index],
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontFamily: 'SpaceGrotesk',
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildChallengeRow(int index) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            '${index + 1}.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.primaryAccent),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _controllers[index],
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFamily: 'SpaceGrotesk',
                  ),
              decoration: InputDecoration(
                hintText: 'Word ${index + 1}',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: (_) {
                if (_hasError) setState(() => _hasError = false);
              },
            ),
          ),
        ),
      ],
    );
  }
}
