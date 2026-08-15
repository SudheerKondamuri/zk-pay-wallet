import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/env.dart';
import '../../../providers/services_providers.dart';

/// Network configuration — RPC/API URL overrides persisted via SecureStorage.
class NetworkConfig {
  final String apiBaseUrl;
  final String rpcUrl;

  const NetworkConfig({required this.apiBaseUrl, required this.rpcUrl});
}

class NetworkConfigNotifier extends AsyncNotifier<NetworkConfig> {
  @override
  Future<NetworkConfig> build() async {
    final storage = ref.read(secureStorageServiceProvider);
    final apiOverride = await storage.getApiBaseUrlOverride();
    final rpcOverride = await storage.getRpcUrlOverride();

    // Apply overrides to Env.
    if (apiOverride != null) Env.setApiBaseUrl(apiOverride);
    if (rpcOverride != null) Env.setRpcUrl(rpcOverride);

    return NetworkConfig(
      apiBaseUrl: Env.apiBaseUrl,
      rpcUrl: Env.rpcUrl,
    );
  }

  Future<void> updateUrls({String? apiBaseUrl, String? rpcUrl}) async {
    final storage = ref.read(secureStorageServiceProvider);

    if (apiBaseUrl != null) {
      await storage.setApiBaseUrlOverride(apiBaseUrl);
      Env.setApiBaseUrl(apiBaseUrl);
    }
    if (rpcUrl != null) {
      await storage.setRpcUrlOverride(rpcUrl);
      Env.setRpcUrl(rpcUrl);
      ref.read(walletServiceProvider).resetWeb3();
    }

    state = AsyncData(NetworkConfig(
      apiBaseUrl: Env.apiBaseUrl,
      rpcUrl: Env.rpcUrl,
    ));
  }

  Future<void> resetToDefaults() async {
    final storage = ref.read(secureStorageServiceProvider);
    await storage.setApiBaseUrlOverride(null);
    await storage.setRpcUrlOverride(null);
    Env.setApiBaseUrl(null);
    Env.setRpcUrl(null);
    ref.read(walletServiceProvider).resetWeb3();

    state = AsyncData(NetworkConfig(
      apiBaseUrl: Env.apiBaseUrl,
      rpcUrl: Env.rpcUrl,
    ));
  }
}

final networkConfigProvider =
    AsyncNotifierProvider<NetworkConfigNotifier, NetworkConfig>(
  NetworkConfigNotifier.new,
);

/// Security settings — auto-lock timeout and biometric toggle.
class SecuritySettings {
  final int autoLockTimeoutSeconds;
  final bool biometricEnabled;

  const SecuritySettings({
    this.autoLockTimeoutSeconds = 60,
    this.biometricEnabled = false,
  });
}

class SecuritySettingsNotifier extends AsyncNotifier<SecuritySettings> {
  @override
  Future<SecuritySettings> build() async {
    final storage = ref.read(secureStorageServiceProvider);
    final timeout = await storage.getAutoLockTimeout();
    final biometric = await storage.isBiometricEnabled();
    return SecuritySettings(
      autoLockTimeoutSeconds: timeout,
      biometricEnabled: biometric,
    );
  }

  Future<void> setAutoLockTimeout(int seconds) async {
    final storage = ref.read(secureStorageServiceProvider);
    await storage.setAutoLockTimeout(seconds);
    final current = state.value ?? const SecuritySettings();
    state = AsyncData(SecuritySettings(
      autoLockTimeoutSeconds: seconds,
      biometricEnabled: current.biometricEnabled,
    ));
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final storage = ref.read(secureStorageServiceProvider);
    await storage.setBiometricEnabled(enabled);
    final current = state.value ?? const SecuritySettings();
    state = AsyncData(SecuritySettings(
      autoLockTimeoutSeconds: current.autoLockTimeoutSeconds,
      biometricEnabled: enabled,
    ));
  }
}

final securitySettingsProvider =
    AsyncNotifierProvider<SecuritySettingsNotifier, SecuritySettings>(
  SecuritySettingsNotifier.new,
);
