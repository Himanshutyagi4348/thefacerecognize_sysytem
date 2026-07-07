import 'dart:convert';

/// ===============================================================
/// User Model
/// ===============================================================
///
/// Represents one registered person.
///
/// Each user has:
/// - unique userId
/// - display name
/// - registration timestamp
///
/// The actual facial embeddings are stored separately in the
/// `embeddings` table.
/// ===============================================================

class UserModel {
  final String userId;
  final String userName;
  final DateTime createdAt;

  const UserModel({
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  /// -------------------------------------------------------------
  /// Creates a modified copy.
  /// -------------------------------------------------------------
  UserModel copyWith({String? userId, String? userName, DateTime? createdAt}) {
    return UserModel(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// -------------------------------------------------------------
  /// Convert to SQLite Map
  /// -------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      "user_id": userId,
      "user_name": userName,
      "created_at": createdAt.toIso8601String(),
    };
  }

  /// -------------------------------------------------------------
  /// Create from SQLite Map
  /// -------------------------------------------------------------
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map["user_id"] as String,
      userName: map["user_name"] as String,
      createdAt: DateTime.parse(map["created_at"] as String),
    );
  }

  /// -------------------------------------------------------------
  /// JSON Support
  /// -------------------------------------------------------------
  String toJson() => jsonEncode(toMap());

  factory UserModel.fromJson(String source) {
    return UserModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }

  /// -------------------------------------------------------------
  /// Equality
  /// -------------------------------------------------------------
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserModel &&
        other.userId == userId &&
        other.userName == userName &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(userId, userName, createdAt);
  }

  @override
  String toString() {
    return '''
UserModel(
  userId: $userId,
  userName: $userName,
  createdAt: $createdAt
)
''';
  }
}
