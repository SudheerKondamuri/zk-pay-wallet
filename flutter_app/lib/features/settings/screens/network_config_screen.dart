import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/env.dart';
import '../../../app/theme.dart';
import '../../../providers/services_providers.dart';
import '../../../shared/app_button.dart';
import '../../../shared/app_text_field.dart';

/// Screen 19 — Network Configuration. Edit API base URL and RPC URL at runtime.
class NetworkConfigScreen extends ConsumerStatefulWidget {
  const NetworkConfigScreen({super.key});

  @override
  ConsumerState<NetworkConfigScreen> createState() =>
      _NetworkConfigScreenState();
}

class _NetworkConfigScreenState extends ConsumerState<NetworkConfigScreen> {
  late TextEditingController _apiController;
  late TextEditingController _rpcController;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _apiController = TextEditingController(text: Env.apiBaseUrl);
    _rpcController = TextEditingController(text: Env.rpcUrl);
  }

  @override
  void dispose() {
    _apiController.dispose();
    _rpcController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final storage = ref.read(secureStorageServiceProvider);
    final newApi = _apiController.text.trim();
    final newRpc = _rpcController.text.trim();

    if (newApi.isNotEmpty) {
      await storage.write('api_base_url_override', newApi);
    }
    if (newRpc.isNotEmpty) {
      await storage.write('rpc_url_override', newRpc);
    }

    HapticFeedback.mediumImpact();
    setState(() => _saved = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Saved. Restart app for changes to take effect.')),
      );
    }
  }

  void _reset() {
    _apiController.text = Env.apiBaseUrl;
    _rpcController.text = Env.rpcUrl;
    setState(() => _saved = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.base),
              Text(
                'Override the API and RPC endpoints.\nDefaults are set via --dart-define at build time.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _apiController,
                labelText: 'API Base URL',
                hintText: 'http://10.0.2.2:3000',
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _rpcController,
                labelText: 'RPC URL',
                hintText: 'http://10.0.2.2:8545',
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_saved)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.primaryAccent, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Saved',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.primaryAccent),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              AppButton(
                label: 'Save',
                onPressed: _save,
                width: double.infinity,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Reset to defaults',
                onPressed: _reset,
                isPrimary: false,
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
