/// Single source of truth for API_BASE_URL and RPC_URL.
///
/// Compile-time defaults come from --dart-define flags.
/// Runtime overrides (from Settings screen) are checked first
/// via SecureStorageService, falling back to compile-time values.
class Env {
  Env._();

  static const String _defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:4000',
  );

  static const String _defaultRpcUrl = String.fromEnvironment(
    'RPC_URL',
    defaultValue: 'http://10.0.2.2:8545',
  );

  static const int chainId = int.fromEnvironment(
    'CHAIN_ID',
    defaultValue: 31337,
  );

  /// Runtime overrides — set from Settings, cleared on null.
  static String? _runtimeApiBaseUrl;
  static String? _runtimeRpcUrl;

  static String get apiBaseUrl => _runtimeApiBaseUrl ?? _defaultApiBaseUrl;
  static String get rpcUrl => _runtimeRpcUrl ?? _defaultRpcUrl;

  static void setApiBaseUrl(String? url) => _runtimeApiBaseUrl = url;
  static void setRpcUrl(String? url) => _runtimeRpcUrl = url;
}
