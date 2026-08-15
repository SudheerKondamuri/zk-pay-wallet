import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../providers/services_providers.dart';
import 'wallet_providers.dart';

/// Rollup state from GET /state — polls every ~8s.
/// Drives the signature node-graph visualization.
class RollupState {
  final String currentStateRoot;
  final int batchCount;
  final String contractAddress;

  const RollupState({
    required this.currentStateRoot,
    required this.batchCount,
    required this.contractAddress,
  });

  factory RollupState.fromJson(Map<String, dynamic> json) {
    return RollupState(
      currentStateRoot: json['currentStateRoot'] as String? ?? '',
      batchCount: (json['batchCount'] as num?)?.toInt() ?? 0,
      contractAddress: json['contractAddress'] as String? ?? '',
    );
  }
}

class RollupStateNotifier extends AsyncNotifier<RollupState> {
  Timer? _timer;

  @override
  Future<RollupState> build() async {
    ref.onDispose(() => _timer?.cancel());
    _startPolling();
    return _fetch();
  }

  Future<RollupState> _fetch() async {
    ref.read(isSyncingProvider.notifier).state = true;
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getRollupState();
      final rollup = RollupState.fromJson(data);
      if (rollup.contractAddress.isNotEmpty) {
        ref.read(walletServiceProvider).setContractAddress(rollup.contractAddress);
      }
      return rollup;
    } finally {
      Future.delayed(const Duration(milliseconds: 350), () {
        ref.read(isSyncingProvider.notifier).state = false;
      });
    }
  }

  void _startPolling() {
    _timer = Timer.periodic(AppDuration.statePoll, (_) async {
      try {
        final newState = await _fetch();
        state = AsyncData(newState);
      } catch (e, st) {
        // If initial load failed, surface the error so UI stops loading skeleton
        if (state.isLoading) {
          state = AsyncError(e, st);
        }
      }
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(await _fetch());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final rollupStateProvider =
    AsyncNotifierProvider<RollupStateNotifier, RollupState>(
  RollupStateNotifier.new,
);
