import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/env.dart';

/// Pure REST API client for the 6 backend endpoints.
/// Knows nothing about private keys or blockchain signing.
class ApiService {
  http.Client? _client;

  http.Client get client => _client ??= http.Client();

  String get _baseUrl => Env.apiBaseUrl;

  /// GET /deposits/:address → { address, balanceWei, balanceEth }
  /// This is the DB-computed L2 ledger balance, not a live chain read.
  Future<Map<String, dynamic>> getDeposit(String address) async {
    final response = await client.get(
      Uri.parse('$_baseUrl/deposits/$address'),
    );
    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch balance', response.statusCode);
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// GET /state → { currentStateRoot, batchCount, contractAddress }
  Future<Map<String, dynamic>> getRollupState() async {
    final response = await client.get(
      Uri.parse('$_baseUrl/state'),
    );
    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch rollup state', response.statusCode);
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// POST /intents → { intentId, status }
  /// amountWei must be a decimal string, never a number.
  Future<Map<String, dynamic>> submitIntent(
    String from,
    String to,
    String amountWei,
  ) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/intents'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'fromAddress': from,
        'toAddress': to,
        'amountWei': amountWei,
      }),
    );
    if (response.statusCode == 400) {
      final body = json.decode(response.body) as Map<String, dynamic>;
      throw ApiException(
        body['error'] as String? ?? 'Bad request',
        400,
      );
    }
    if (response.statusCode != 201) {
      throw ApiException('Failed to submit intent', response.statusCode);
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// GET /intents?address=&status= → { intents: [...] }
  /// Only returns outgoing intents (from_address match).
  Future<List<dynamic>> getIntents({String? address, String? status}) async {
    final params = <String, String>{};
    if (address != null) params['address'] = address;
    if (status != null) params['status'] = status;

    final uri = Uri.parse('$_baseUrl/intents').replace(queryParameters: params);
    final response = await client.get(uri);
    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch intents', response.statusCode);
    }
    final body = json.decode(response.body) as Map<String, dynamic>;
    return body['intents'] as List<dynamic>;
  }

  /// GET /batches → { batches: [...] }
  Future<List<dynamic>> getBatches() async {
    final response = await client.get(
      Uri.parse('$_baseUrl/batches'),
    );
    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch batches', response.statusCode);
    }
    final body = json.decode(response.body) as Map<String, dynamic>;
    return body['batches'] as List<dynamic>;
  }

  /// GET /batches/:batchIndex → { batch: {...}, intents: [...] }
  Future<Map<String, dynamic>> getBatchDetail(int batchIndex) async {
    final response = await client.get(
      Uri.parse('$_baseUrl/batches/$batchIndex'),
    );
    if (response.statusCode == 404) {
      throw ApiException('Batch not found', 404);
    }
    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch batch detail', response.statusCode);
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// POST /withdrawals → { status, userAddress, amountWei, txHash, blockNumber }
  Future<Map<String, dynamic>> submitWithdrawal(
    String userAddress,
    String amountWei,
  ) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/withdrawals'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userAddress': userAddress,
        'amountWei': amountWei,
      }),
    );
    if (response.statusCode == 400) {
      final body = json.decode(response.body) as Map<String, dynamic>;
      throw ApiException(
        body['error'] as String? ?? 'Insufficient balance or invalid amount',
        400,
      );
    }
    if (response.statusCode != 200) {
      throw ApiException('Failed to process withdrawal', response.statusCode);
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// GET /withdrawals/:address → { withdrawals: [...] }
  Future<List<dynamic>> getWithdrawals(String address) async {
    final response = await client.get(
      Uri.parse('$_baseUrl/withdrawals/$address'),
    );
    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch withdrawals', response.statusCode);
    }
    final body = json.decode(response.body) as Map<String, dynamic>;
    return body['withdrawals'] as List<dynamic>;
  }

  void dispose() {
    _client?.close();
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
