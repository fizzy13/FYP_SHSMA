class UserInfo {
  final String? uid;
  final String email;
  final String phoneNumber;
  final String address;
  final String fullName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserInfo({
    this.uid,
    required this.email,
    required this.phoneNumber,
    required this.address,
    required this.fullName,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert UserInfo to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'fullName': fullName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  // Create UserInfo from Firestore document
  factory UserInfo.fromMap(Map<String, dynamic> map) {
    return UserInfo(
      uid: map['uid'],
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      address: map['address'] ?? '',
      fullName: map['fullName'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  // Create a copy with modified fields
  UserInfo copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    String? address,
    String? fullName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserInfo(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      fullName: fullName ?? this.fullName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
