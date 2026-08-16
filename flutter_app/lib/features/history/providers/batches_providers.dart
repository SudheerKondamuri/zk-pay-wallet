import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/services_providers.dart';

/// Fetches all batches.
final batchesProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getBatches();
});

/// Fetches detail for a specific batch index.
final batchDetailProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, batchIndex) async {
  final api = ref.read(apiServiceProvider);
  return api.getBatchDetail(batchIndex);
});
