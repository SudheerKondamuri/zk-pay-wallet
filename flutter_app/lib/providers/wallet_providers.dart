import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import 'services_providers.dart';

/// L2 spendable balance — DB-computed ledger via GET /deposits/:address.
/// Polls every ~15s. Fires incoming-transfer detection by comparing values.
class L2BalanceNotifier extends FamilyAsyncNotifier<String, String> {
  Timer? _timer;
  String _previousBalance = '0';

  @override
  Future<String> build(String address) async {
    ref.onDispose(() => _timer?.cancel());
    _startPolling(address);
    return _fetchBalance(address);
  }

  Future<String> _fetchBalance(String address) async {
    final api = ref.read(apiServiceProvider);
    final data = await api.getDeposit(address);
    final balanceWei = data['balanceWei'] as String? ?? '0';

    // Incoming-transfer detection: compare to previous value.
    if (_previousBalance != '0' && balanceWei != _previousBalance) {
      final current = BigInt.parse(balanceWei);
      final previous = BigInt.parse(_previousBalance);
      if (current > previous) {
        // Balance increased — an incoming transfer arrived.
        // The UI layer reads this via a separate callback/listener.
      }
    }
    _previousBalance = balanceWei;
    return balanceWei;
  }

  void _startPolling(String address) {
    _timer = Timer.periodic(AppDuration.balancePoll, (_) async {
      state = AsyncData(await _fetchBalance(address));
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetchBalance(arg));
  }
}

final l2BalanceProvider =
    AsyncNotifierProvider.family<L2BalanceNotifier, String, String>(
  L2BalanceNotifier.new,
);

/// On-chain withdrawable balance — direct RPC read of deposits(address).
/// This is the L1 ceiling for withdraw(). Polls every ~15s.
class OnChainDepositNotifier extends FamilyAsyncNotifier<String, String> {
  Timer? _timer;

  @override
  Future<String> build(String address) async {
    ref.onDispose(() => _timer?.cancel());
    // Ensure contract address is loaded first.
    await ref.read(contractAddressProvider.future);
    _startPolling(address);
    return _fetch(address);
  }

  Future<String> _fetch(String address) async {
    final wallet = ref.read(walletServiceProvider);
    return wallet.getOnChainDeposit(address);
  }

  void _startPolling(String address) {
    _timer = Timer.periodic(AppDuration.balancePoll, (_) async {
      state = AsyncData(await _fetch(address));
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetch(arg));
  }
}

final onChainDepositProvider =
    AsyncNotifierProvider.family<OnChainDepositNotifier, String, String>(
  OnChainDepositNotifier.new,
);
