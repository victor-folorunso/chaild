enum SubscriptionStatus { active, expired, cancelled, grace_period, none }

class ChaildSubscription {
  final String id;
  final String userId;
  final SubscriptionStatus status;
  final String? plan;
  final DateTime? expiresAt;
  final String? flutterwaveRef;
  final String? source; // 'revenuecat' | 'supabase'

  const ChaildSubscription({
    required this.id,
    required this.userId,
    required this.status,
    this.plan,
    this.expiresAt,
    this.flutterwaveRef,
    this.source,
  });

  bool get isActive =>
      status == SubscriptionStatus.active &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  factory ChaildSubscription.fromMap(Map<String, dynamic> map) {
    return ChaildSubscription(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String),
        orElse: () => SubscriptionStatus.none,
      ),
      plan: map['plan'] as String?,
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'] as String)
          : null,
      flutterwaveRef: map['flutterwave_ref'] as String?,
      source: 'supabase',
    );
  }
}
