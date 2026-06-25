// ─────────────────────────────────────────────────────────────────────────────
// WalletCategoryType
//
// Las 3 categorías del PDF de Blinkids:
//   guardar       → alcancía tradicional (ahorro)
//   banco_estelar → cuenta de inversión virtual (gana interés semanal)
//   gastar        → pool de gastos inmediatos
// ─────────────────────────────────────────────────────────────────────────────
enum WalletCategoryType { guardar, banco_estelar, gastar }

extension WalletCategoryTypeX on WalletCategoryType {
  String get displayName {
    switch (this) {
      case WalletCategoryType.guardar:
        return 'Guardar';
      case WalletCategoryType.banco_estelar:
        return 'Banco Estelar';
      case WalletCategoryType.gastar:
        return 'Gastar';
    }
  }

  String get emoji {
    switch (this) {
      case WalletCategoryType.guardar:
        return '🐷';
      case WalletCategoryType.banco_estelar:
        return '🏦';
      case WalletCategoryType.gastar:
        return '🛒';
    }
  }

  String get description {
    switch (this) {
      case WalletCategoryType.guardar:
        return 'Guarda para el futuro';
      case WalletCategoryType.banco_estelar:
        return 'Gana interés cada semana';
      case WalletCategoryType.gastar:
        return 'Para tus gastos de hoy';
    }
  }

  // Color de acento para la tarjeta
  int get colorDarkHex {
    switch (this) {
      case WalletCategoryType.guardar:
        return 0xFF0D47A1;
      case WalletCategoryType.banco_estelar:
        return 0xFF4A148C;
      case WalletCategoryType.gastar:
        return 0xFFBF360C;
    }
  }

  int get colorLightHex {
    switch (this) {
      case WalletCategoryType.guardar:
        return 0xFF42A5F5;
      case WalletCategoryType.banco_estelar:
        return 0xFFCE93D8;
      case WalletCategoryType.gastar:
        return 0xFFFFCC80;
    }
  }
}

class Wallet {
  final String id;
  final String userId;
  final int totalCoins;
  final int realBalanceCents;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Wallet({
    required this.id,
    required this.userId,
    required this.totalCoins,
    required this.realBalanceCents,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      totalCoins: json['total_coins'] as int? ?? 0,
      realBalanceCents: json['real_balance_cents'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'total_coins': totalCoins,
        'real_balance_cents': realBalanceCents,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Wallet copyWith({int? totalCoins, int? realBalanceCents}) {
    return Wallet(
      id: id,
      userId: userId,
      totalCoins: totalCoins ?? this.totalCoins,
      realBalanceCents: realBalanceCents ?? this.realBalanceCents,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class WalletCategory {
  final String id;
  final String walletId;
  final WalletCategoryType category;
  final int balance;
  final DateTime updatedAt;

  const WalletCategory({
    required this.id,
    required this.walletId,
    required this.category,
    required this.balance,
    required this.updatedAt,
  });

  factory WalletCategory.fromJson(Map<String, dynamic> json) {
    return WalletCategory(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String,
      category: WalletCategoryType.values.firstWhere(
        (c) => c.name == (json['category'] as String),
        orElse: () => WalletCategoryType.gastar,
      ),
      balance: json['balance'] as int? ?? 0,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'wallet_id': walletId,
        'category': category.name,
        'balance': balance,
        'updated_at': updatedAt.toIso8601String(),
      };

  WalletCategory copyWith({int? balance}) {
    return WalletCategory(
      id: id,
      walletId: walletId,
      category: category,
      balance: balance ?? this.balance,
      updatedAt: DateTime.now(),
    );
  }
}
