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

/// Fetches contract address from GET /state and caches it, with auto-retry.
class ContractAddressNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    return _fetch();
  }

  Future<String> _fetch() async {
    final api = ref.read(apiServiceProvider);
    final state = await api.getRollupState();
    final address = state['contractAddress'] as String;
    // Also set it on the wallet service for RPC calls.
    ref.read(walletServiceProvider).setContractAddress(address);
    return address;
  }

  Future<String> ensureAddress() async {
    if (state.hasValue && state.value!.isNotEmpty) {
      ref.read(walletServiceProvider).setContractAddress(state.value!);
      return state.value!;
    }
    final addr = await _fetch();
    state = AsyncData(addr);
    return addr;
  }
}

final contractAddressProvider =
    AsyncNotifierProvider<ContractAddressNotifier, String>(
  ContractAddressNotifier.new,
);
