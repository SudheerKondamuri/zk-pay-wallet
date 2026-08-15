import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over flutter_secure_storage.
/// Mnemonic/private key storage only happens through here.
class SecureStorageService {
  static const _mnemonicKey = 'wallet_mnemonic';
  static const _privateKeyKey = 'wallet_private_key';
  static const _pinKey = 'user_pin';
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _autoLockTimeoutKey = 'auto_lock_timeout';
  static const _rpcUrlOverrideKey = 'rpc_url_override';
  static const _apiBaseUrlOverrideKey = 'api_base_url_override';

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  // --- Wallet credentials ---

  Future<void> saveMnemonic(String mnemonic) async {
    await _storage.write(key: _mnemonicKey, value: mnemonic);
  }

  Future<String?> readMnemonic() async {
    return _storage.read(key: _mnemonicKey);
  }

  Future<void> savePrivateKey(String privateKey) async {
    await _storage.write(key: _privateKeyKey, value: privateKey);
  }

  Future<String?> readPrivateKey() async {
    return _storage.read(key: _privateKeyKey);
  }

  Future<bool> hasWallet() async {
    final mnemonic = await readMnemonic();
    final pk = await readPrivateKey();
    return mnemonic != null || pk != null;
  }

  // --- PIN ---

  Future<void> savePin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  Future<String?> readPin() async {
    return _storage.read(key: _pinKey);
  }

  Future<bool> hasPin() async {
    final pin = await readPin();
    return pin != null;
  }

  // --- Biometric preference ---

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricEnabledKey,
      value: enabled.toString(),
    );
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  // --- Auto-lock timeout (seconds) ---

  Future<void> setAutoLockTimeout(int seconds) async {
    await _storage.write(key: _autoLockTimeoutKey, value: seconds.toString());
  }

  Future<int> getAutoLockTimeout() async {
    final value = await _storage.read(key: _autoLockTimeoutKey);
    return value != null ? int.tryParse(value) ?? 60 : 60;
  }

  // --- Network overrides ---

  Future<void> setRpcUrlOverride(String? url) async {
    if (url == null || url.isEmpty) {
      await _storage.delete(key: _rpcUrlOverrideKey);
    } else {
      await _storage.write(key: _rpcUrlOverrideKey, value: url);
    }
  }

  Future<String?> getRpcUrlOverride() async {
    return _storage.read(key: _rpcUrlOverrideKey);
  }

  Future<void> setApiBaseUrlOverride(String? url) async {
    if (url == null || url.isEmpty) {
      await _storage.delete(key: _apiBaseUrlOverrideKey);
    } else {
      await _storage.write(key: _apiBaseUrlOverrideKey, value: url);
    }
  }

  Future<String?> getApiBaseUrlOverride() async {
    return _storage.read(key: _apiBaseUrlOverrideKey);
  }

  // --- Local Activity Log (Deposits & Withdrawals) ---

  Future<void> saveLocalActivity(String address, Map<String, dynamic> activityJson) async {
    final key = 'local_activities_${address.toLowerCase()}';
    final existingRaw = await _storage.read(key: key);
    List<dynamic> list = [];
    if (existingRaw != null && existingRaw.isNotEmpty) {
      try {
        list = jsonDecode(existingRaw) as List<dynamic>;
      } catch (_) {
        list = [];
      }
    }
    // Prepend or replace if exists
    final id = activityJson['id'] as String;
    final index = list.indexWhere((e) => e['id'] == id);
    if (index != -1) {
      list[index] = activityJson;
    } else {
      list.insert(0, activityJson);
    }
    await _storage.write(key: key, value: jsonEncode(list));
  }

  Future<List<Map<String, dynamic>>> getLocalActivities(String address) async {
    final key = 'local_activities_${address.toLowerCase()}';
    final existingRaw = await _storage.read(key: key);
    if (existingRaw == null || existingRaw.isEmpty) return [];
    try {
      final list = jsonDecode(existingRaw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // --- Full wipe ---

  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  /// Alias for deleteAll — used by settings reset flow.
  Future<void> clearAll() async => deleteAll();

  /// Generic write — used by network config screen for runtime overrides.
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }
}
