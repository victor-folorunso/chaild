class ChaildUser {
  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;
  final String? partnerKey; // which developer referred this user
  final DateTime createdAt;

  const ChaildUser({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    this.partnerKey,
    required this.createdAt,
  });

  factory ChaildUser.fromMap(Map<String, dynamic> map) {
    return ChaildUser(
      id: map['id'] as String,
      email: map['email'] as String,
      name: map['name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      partnerKey: map['partner_key'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'name': name,
        'avatar_url': avatarUrl,
        'partner_key': partnerKey,
        'created_at': createdAt.toIso8601String(),
      };
}
