import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services_providers.dart';

/// Fetches outgoing intents for a user address, optionally filtered by status.
class IntentsFilter {
  final String address;
  final String? status;

  const IntentsFilter({required this.address, this.status});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntentsFilter &&
          address == other.address &&
          status == other.status;

  @override
  int get hashCode => Object.hash(address, status);
}

final intentsProvider =
    FutureProvider.family<List<dynamic>, IntentsFilter>((ref, filter) async {
  final api = ref.read(apiServiceProvider);
  return api.getIntents(address: filter.address, status: filter.status);
});

/// Mutation state for submitting a new intent.
class SubmitIntentState {
  final bool isSubmitting;
  final String? error;
  final Map<String, dynamic>? result;

  const SubmitIntentState({
    this.isSubmitting = false,
    this.error,
    this.result,
  });
}

class SubmitIntentNotifier extends Notifier<SubmitIntentState> {
  @override
  SubmitIntentState build() => const SubmitIntentState();

  Future<bool> submit(String from, String to, String amountWei) async {
    state = const SubmitIntentState(isSubmitting: true);
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.submitIntent(from, to, amountWei);
      state = SubmitIntentState(result: result);
      return true;
    } catch (e) {
      state = SubmitIntentState(error: e.toString());
      return false;
    }
  }

  void reset() => state = const SubmitIntentState();
}

final submitIntentProvider =
    NotifierProvider<SubmitIntentNotifier, SubmitIntentState>(
  SubmitIntentNotifier.new,
);
