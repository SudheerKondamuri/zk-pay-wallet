import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../providers/services_providers.dart';

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
    ref.read(isSyncingProvider.notifier).state = true;
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getDeposit(address);
      final balanceWei = data['balanceWei'] as String? ?? '0';

      // Incoming-transfer detection: compare to previous value.
      if (_previousBalance != '0' && balanceWei != _previousBalance) {
        final current = BigInt.parse(balanceWei);
        final previous = BigInt.parse(_previousBalance);
        if (current > previous) {
          final diff = current - previous;
          ref.read(incomingTransferProvider.notifier).state =
              IncomingTransferEvent(diff.toString(), DateTime.now());
        }
      }
      _previousBalance = balanceWei;
      ref.read(lastUpdatedProvider.notifier).state = DateTime.now();
      return balanceWei;
    } finally {
      Future.delayed(const Duration(milliseconds: 350), () {
        ref.read(isSyncingProvider.notifier).state = false;
      });
    }
  }

  void _startPolling(String address) {
    _timer = Timer.periodic(AppDuration.balancePoll, (_) async {
      try {
        final balance = await _fetchBalance(address);
        state = AsyncData(balance);
      } catch (e, st) {
        if (state.isLoading) {
          state = AsyncError(e, st);
        }
      }
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(await _fetchBalance(arg));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
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
    await ref.read(contractAddressProvider.notifier).ensureAddress();
    _startPolling(address);
    return _fetch(address);
  }

  Future<String> _fetch(String address) async {
    final wallet = ref.read(walletServiceProvider);
    return wallet.getOnChainDeposit(address);
  }

  void _startPolling(String address) {
    _timer = Timer.periodic(AppDuration.balancePoll, (_) async {
      try {
        final balance = await _fetch(address);
        state = AsyncData(balance);
      } catch (e, st) {
        if (state.isLoading) {
          state = AsyncError(e, st);
        }
      }
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(await _fetch(arg));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final onChainDepositProvider =
    AsyncNotifierProvider.family<OnChainDepositNotifier, String, String>(
  OnChainDepositNotifier.new,
);

/// Event emitted when an incoming transfer is detected on L2.
class IncomingTransferEvent {
  final String amountWei;
  final DateTime timestamp;
  const IncomingTransferEvent(this.amountWei, this.timestamp);
}

final incomingTransferProvider =
    StateProvider<IncomingTransferEvent?>((ref) => null);

/// Tracks the timestamp of the last successful balance refresh.
final lastUpdatedProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Pulses true when active polling / network sync occurs.
final isSyncingProvider = StateProvider<bool>((ref) => false);

