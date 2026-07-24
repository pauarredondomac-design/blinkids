enum UserRole { parent, child, admin }

extension UserRoleX on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.parent:
        return 'Papá / Mamá';
      case UserRole.child:
        return 'Aventurero';
      case UserRole.admin:
        return 'Administrador';
    }
  }

  bool get isParent => this == UserRole.parent;
  bool get isChild => this == UserRole.child;
}

enum AccountType { demo, limited, full }

class Profile {
  final String id;
  final UserRole role;
  final String displayName;
  final String? avatarUrl;
  final String? worldName;
  final AccountType accountType;
  final String? pinHash;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.role,
    required this.displayName,
    this.avatarUrl,
    this.worldName,
    this.accountType = AccountType.full,
    this.pinHash,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDemo => accountType == AccountType.demo;
  bool get hasPinSet => pinHash != null && pinHash!.isNotEmpty;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name == (json['role'] as String),
        orElse: () => UserRole.child,
      ),
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      worldName: json['world_name'] as String?,
      accountType: switch (json['account_type'] as String? ?? 'full') {
        'demo'    => AccountType.demo,
        'limited' => AccountType.limited,
        _         => AccountType.full,
      },
      pinHash: json['pin_hash'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (worldName != null) 'world_name': worldName,
        'account_type': accountType.name,
        if (pinHash != null) 'pin_hash': pinHash,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Profile copyWith({
    String? displayName,
    String? avatarUrl,
    String? worldName,
    AccountType? accountType,
    String? pinHash,
  }) {
    return Profile(
      id: id,
      role: role,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      worldName: worldName ?? this.worldName,
      accountType: accountType ?? this.accountType,
      pinHash: pinHash ?? this.pinHash,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Profile && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
