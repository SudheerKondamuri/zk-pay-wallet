import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../providers/services_providers.dart';
import '../../../shared/app_button.dart';
import '../../../shared/flat_card.dart';

/// Screen 3 — Seed Generation. Shows the 12-word mnemonic, user
/// must write it down. "Continue" goes to verification.
class SeedGenerationScreen extends ConsumerStatefulWidget {
  const SeedGenerationScreen({super.key});

  @override
  ConsumerState<SeedGenerationScreen> createState() =>
      _SeedGenerationScreenState();
}

class _SeedGenerationScreenState extends ConsumerState<SeedGenerationScreen> {
  late String _mnemonic;
  late List<String> _words;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    final wallet = ref.read(walletServiceProvider);
    _mnemonic = wallet.generateMnemonic();
    _words = _mnemonic.split(' ');
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _mnemonic));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery phrase')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.base),
              Text(
                'Write these 12 words down in order.\nYou will need them to recover your wallet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              // Word grid
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _revealed = true),
                  child: FlatCard(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    child: _revealed
                        ? _buildWordGrid()
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.visibility_off_outlined,
                                  color: AppColors.textMuted,
                                  size: 32,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Tap to reveal',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              if (_revealed)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.base),
              AppButton(
                label: 'I\'ve written it down',
                onPressed: _revealed
                    ? () => context.push(
                          AppRoutes.seedVerification,
                          extra: _mnemonic,
                        )
                    : null,
                width: double.infinity,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2.8,
      ),
      itemCount: _words.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${index + 1}. ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextSpan(
                  text: _words[index],
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontFamily: 'SpaceGrotesk',
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
