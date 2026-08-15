enum ActivityType { send, deposit, withdraw }

enum ActivityStatus { pending, batched, confirmed, failed }

class ActivityItem {
  final String id;
  final ActivityType type;
  final String amountWei;
  final String? fromAddress;
  final String? toAddress;
  final String? txHash;
  final int? batchIndex;
  final DateTime timestamp;
  final ActivityStatus status;

  const ActivityItem({
    required this.id,
    required this.type,
    required this.amountWei,
    this.fromAddress,
    this.toAddress,
    this.txHash,
    this.batchIndex,
    required this.timestamp,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amountWei': amountWei,
        'fromAddress': fromAddress,
        'toAddress': toAddress,
        'txHash': txHash,
        'batchIndex': batchIndex,
        'timestamp': timestamp.toIso8601String(),
        'status': status.name,
      };

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: json['id'] as String,
      type: ActivityType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ActivityType.send,
      ),
      amountWei: json['amountWei'] as String? ?? '0',
      fromAddress: json['fromAddress'] as String?,
      toAddress: json['toAddress'] as String?,
      txHash: json['txHash'] as String?,
      batchIndex: json['batchIndex'] as int?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      status: ActivityStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ActivityStatus.confirmed,
      ),
    );
  }

  factory ActivityItem.fromIntent(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'pending';
    ActivityStatus status;
    switch (statusStr) {
      case 'batched':
        status = ActivityStatus.batched;
        break;
      case 'failed':
        status = ActivityStatus.failed;
        break;
      case 'pending':
      default:
        status = ActivityStatus.pending;
    }

    final createdAt = json['created_at'] as String?;
    final timestamp =
        createdAt != null ? DateTime.tryParse(createdAt) ?? DateTime.now() : DateTime.now();

    return ActivityItem(
      id: json['id']?.toString() ?? 'intent_${timestamp.millisecondsSinceEpoch}',
      type: ActivityType.send,
      amountWei: json['amount_wei']?.toString() ?? '0',
      fromAddress: json['from_address'] as String?,
      toAddress: json['to_address'] as String?,
      batchIndex: json['batch_index'] as int?,
      timestamp: timestamp,
      status: status,
    );
  }

  ActivityItem copyWith({
    ActivityStatus? status,
    String? txHash,
    int? batchIndex,
  }) {
    return ActivityItem(
      id: id,
      type: type,
      amountWei: amountWei,
      fromAddress: fromAddress,
      toAddress: toAddress,
      txHash: txHash ?? this.txHash,
      batchIndex: batchIndex ?? this.batchIndex,
      timestamp: timestamp,
      status: status ?? this.status,
    );
  }
}
