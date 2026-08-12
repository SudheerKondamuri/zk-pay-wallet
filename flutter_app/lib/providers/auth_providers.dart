import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services_providers.dart';

/// Auth state: tracks whether the app is locked and if a wallet exists.
class AuthState {
  final bool hasWallet;
  final bool isLocked;

  const AuthState({this.hasWallet = false, this.isLocked = true});

  AuthState copyWith({bool? hasWallet, bool? isLocked}) {
    return AuthState(
      hasWallet: hasWallet ?? this.hasWallet,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

  void setHasWallet(bool value) {
    state = state.copyWith(hasWallet: value);
  }

  void unlock() {
    state = state.copyWith(isLocked: false);
  }

  void lock() {
    state = state.copyWith(isLocked: true);
  }
}

final authStateProvider =
    NotifierProvider<AuthStateNotifier, AuthState>(AuthStateNotifier.new);

/// Checks SecureStorage for an existing wallet on app launch.
final hasWalletProvider = FutureProvider<bool>((ref) async {
  final storage = ref.read(secureStorageServiceProvider);
  return storage.hasWallet();
});
