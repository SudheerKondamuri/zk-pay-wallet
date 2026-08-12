import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/wallet_service.dart';
import '../services/secure_storage_service.dart';

/// Singleton instances of the three services.
final apiServiceProvider = Provider<ApiService>((ref) {
  final service = ApiService();
  ref.onDispose(() => service.dispose());
  return service;
});

final walletServiceProvider = Provider<WalletService>((ref) {
  final service = WalletService();
  ref.onDispose(() => service.dispose());
  return service;
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Fetches contract address once from GET /state and caches it.
final contractAddressProvider = FutureProvider<String>((ref) async {
  final api = ref.read(apiServiceProvider);
  final state = await api.getRollupState();
  final address = state['contractAddress'] as String;
  // Also set it on the wallet service for RPC calls.
  ref.read(walletServiceProvider).setContractAddress(address);
  return address;
});
