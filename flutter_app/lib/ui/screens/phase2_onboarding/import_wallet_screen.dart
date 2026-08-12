import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/services_providers.dart';
import '../../shared/app_button.dart';
import '../../shared/app_text_field.dart';

/// Screen 5 — Import Wallet. Paste or type a 12/24-word mnemonic.
class ImportWalletScreen extends ConsumerStatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  ConsumerState<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends ConsumerState<ImportWalletScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _isImporting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final mnemonic = _controller.text.trim().toLowerCase();
    final wallet = ref.read(walletServiceProvider);

    if (!wallet.validateMnemonic(mnemonic)) {
      setState(() => _error = 'Invalid recovery phrase. Check each word.');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _error = null;
      _isImporting = true;
    });

    try {
      final storage = ref.read(secureStorageServiceProvider);
      final privateKey = wallet.derivePrivateKey(mnemonic);
      wallet.loadCredentials(privateKey);
      await storage.saveMnemonic(mnemonic);
      await storage.savePrivateKey(privateKey);

      ref.read(authStateProvider.notifier).setHasWallet(true);

      HapticFeedback.mediumImpact();

      if (mounted) {
        context.go(AppRoutes.setupPin);
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isImporting = false;
        _error = 'Failed to import wallet. Try again.';
      });
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _controller.text = data!.text!;
      setState(() => _error = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import wallet')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.base),
              Text(
                'Enter your 12-word recovery phrase, separated by spaces.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _controller,
                hintText: 'word1 word2 word3 ...',
                errorText: _error,
                maxLines: 4,
                enabled: !_isImporting,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste, size: 20),
                  color: AppColors.textSecondary,
                  onPressed: _paste,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${_controller.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} / 12 words',
                style: Theme.of(context).textTheme.bodySmall,
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
