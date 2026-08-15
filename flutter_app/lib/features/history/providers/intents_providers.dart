import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/services_providers.dart';
import '../models/activity_item.dart';

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

enum ActivityFilterType { all, sent, deposits, withdrawals }

class ActivityFilter {
  final String address;
  final ActivityFilterType type;

  const ActivityFilter({
    required this.address,
    this.type = ActivityFilterType.all,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityFilter &&
          address == other.address &&
          type == other.type;

  @override
  int get hashCode => Object.hash(address, type);
}

/// Merges on-chain local transactions (deposits & withdrawals) with L2 transfer intents.
final unifiedActivityProvider =
    FutureProvider.family<List<ActivityItem>, ActivityFilter>((ref, filter) async {
  final api = ref.read(apiServiceProvider);
  final storage = ref.read(secureStorageServiceProvider);

  // 1. Fetch remote L2 intents
  List<ActivityItem> remoteItems = [];
  try {
    final intents = await api.getIntents(address: filter.address);
    remoteItems = intents
        .map((i) => ActivityItem.fromIntent(i as Map<String, dynamic>))
        .toList();
  } catch (_) {
    // If backend is temporarily offline, still show local records
  }

  // 2. Fetch local deposits and withdrawals
  final localList = await storage.getLocalActivities(filter.address);
  final localItems = localList.map(ActivityItem.fromJson).toList();

  // 3. Merge & sort descending by timestamp
  final allItems = [...remoteItems, ...localItems];
  allItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  // 4. Apply filter
  switch (filter.type) {
    case ActivityFilterType.sent:
      return allItems.where((i) => i.type == ActivityType.send).toList();
    case ActivityFilterType.deposits:
      return allItems.where((i) => i.type == ActivityType.deposit).toList();
    case ActivityFilterType.withdrawals:
      return allItems.where((i) => i.type == ActivityType.withdraw).toList();
    case ActivityFilterType.all:
      return allItems;
  }
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
      final msg = e.toString();
      String friendlyError = 'Transfer could not be submitted. Try again.';
      if (msg.contains('insufficient') || msg.contains('balance')) {
        friendlyError = 'Insufficient L2 balance to complete transfer';
      } else if (msg.contains('Connection refused') || msg.contains('SocketException')) {
        friendlyError = 'Cannot reach backend server. Check connection.';
      }
      state = SubmitIntentState(error: friendlyError);
      return false;
    }
  }

  void reset() => state = const SubmitIntentState();
}

final submitIntentProvider =
    NotifierProvider<SubmitIntentNotifier, SubmitIntentState>(
  SubmitIntentNotifier.new,
);
