import 'package:cloud_firestore/cloud_firestore.dart';

class UserInfo {
  final String? uid;
  final String email;
  final String phoneNumber;
  final String address;
  final String country;
  final String fullName;
  final String role;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool twoFactorEnabled;
  final String? twoFactorPinHash;

  UserInfo({
    this.uid,
    required this.email,
    required this.phoneNumber,
    required this.address,
    this.country = '',
    required this.fullName,
    this.role = 'Home Owner',
    required this.createdAt,
    this.updatedAt,
    this.twoFactorEnabled = false,
    this.twoFactorPinHash,
  });

  // Convert UserInfo to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'country': country,
      'fullName': fullName,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'twoFactorEnabled': twoFactorEnabled,
      'twoFactorPinHash': twoFactorPinHash,
    };
  }

  // Create UserInfo from Firestore document
  factory UserInfo.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    final resolvedFullName = (map['fullName'] ?? map['name'] ?? map['Name'] ?? '').toString();
    final resolvedPhoneNumber = (map['phoneNumber'] ?? map['phone'] ?? map['Phone'] ?? '').toString();
    final resolvedAddress = (map['address'] ?? map['Address'] ?? '').toString();
    final resolvedCountry = (map['country'] ?? map['Country'] ?? '').toString();

    return UserInfo(
      uid: map['uid'],
      email: map['email'] ?? '',
      phoneNumber: resolvedPhoneNumber,
      address: resolvedAddress,
      country: resolvedCountry,
      fullName: resolvedFullName,
      role: (map['role'] ?? 'Home Owner').toString(),
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
      twoFactorEnabled: map['twoFactorEnabled'] ?? false,
      twoFactorPinHash: map['twoFactorPinHash'],
    );
  }

  // Create a copy with modified fields
  UserInfo copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    String? address,
    String? country,
    String? fullName,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? twoFactorEnabled,
    String? twoFactorPinHash,
  }) {
    return UserInfo(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      country: country ?? this.country,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      twoFactorPinHash: twoFactorPinHash ?? this.twoFactorPinHash,
    );
  }
}
