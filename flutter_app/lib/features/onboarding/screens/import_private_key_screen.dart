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
import '../../../shared/app_text_field.dart';

/// Screen — Import wallet via raw hex private key.
class ImportPrivateKeyScreen extends ConsumerStatefulWidget {
  const ImportPrivateKeyScreen({super.key});

  @override
  ConsumerState<ImportPrivateKeyScreen> createState() =>
      _ImportPrivateKeyScreenState();
}

class _ImportPrivateKeyScreenState
    extends ConsumerState<ImportPrivateKeyScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _isImporting = false;
  bool _obscured = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Validate that the input is a 64 hex-char key (with optional 0x prefix).
  bool _isValidPrivateKey(String key) {
    final clean = key.startsWith('0x') ? key.substring(2) : key;
    if (clean.length != 64) return false;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean);
  }

  Future<void> _import() async {
    final rawKey = _controller.text.trim();

    if (!_isValidPrivateKey(rawKey)) {
      setState(
          () => _error = 'Invalid key. Must be 64 hex characters (0x optional).');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _error = null;
      _isImporting = true;
    });

    try {
      final wallet = ref.read(walletServiceProvider);
      final storage = ref.read(secureStorageServiceProvider);

      final cleanKey =
          rawKey.startsWith('0x') ? rawKey.substring(2) : rawKey;

      wallet.loadCredentials(cleanKey);
      await storage.savePrivateKey(cleanKey);
      // No mnemonic to save for raw key imports.

      ref.read(authStateProvider.notifier).setHasWallet(true);
      HapticFeedback.mediumImpact();

      if (mounted) {
        context.go(AppRoutes.setupPin);
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isImporting = false;
        _error = 'Failed to import. Check the key and try again.';
      });
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _controller.text = data!.text!.trim();
      setState(() => _error = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import private key')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.base),
              // Warning card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: AppRadius.cardBorder,
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.danger, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Never share your private key. Anyone with it can control your funds.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Paste your private key (hex, 64 characters).',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _controller,
                hintText: '0x...',
                errorText: _error,
                maxLines: 1,
                enabled: !_isImporting,
                obscureText: _obscured,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      color: AppColors.textSecondary,
                      onPressed: () =>
                          setState(() => _obscured = !_obscured),
                    ),
                    IconButton(
                      icon: const Icon(Icons.paste, size: 20),
                      color: AppColors.textSecondary,
                      onPressed: _paste,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'Import',
                onPressed: _import,
                isLoading: _isImporting,
                width: double.infinity,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
