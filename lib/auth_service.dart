import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'models/user_model.dart';
import 'services/credential_storage.dart';
import 'services/user_info_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserInfoService _userInfoService = UserInfoService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final CredentialStorage _credentialStorage = CredentialStorage();
  static const String _biometricEnabledKey = 'biometric_enabled';

  /// Get current authenticated user
  User? get currentUser => _auth.currentUser;

  Future<User?> login(String email, String password) async {
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  }

  Future<User?> loginWithBiometrics() async {
    try {
      if (!kIsWeb) {
        final canAuthenticate = await _localAuth.canCheckBiometrics ||
            await _localAuth.isDeviceSupported();
        if (!canAuthenticate) {
          return null;
        }

        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Authenticate to sign in',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        if (!authenticated) {
          return null;
        }
      }

      final storedEmail = await _credentialStorage.read('biometric_email');
      final storedPassword = await _credentialStorage.read('biometric_password');
      if (storedEmail == null || storedPassword == null) {
        return null;
      }

      return await login(storedEmail, storedPassword);
    } catch (e) {
      debugPrint('Biometric login error: $e');
      return null;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _credentialStorage.read(_biometricEnabledKey);
    return value == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _credentialStorage.write(_biometricEnabledKey, enabled ? 'true' : 'false');
    if (!enabled) {
      await clearBiometricCredentials();
    }
  }

  Future<void> saveBiometricCredentials(String email, String password) async {
    await _credentialStorage.write('biometric_email', email);
    await _credentialStorage.write('biometric_password', password);
  }

  Future<void> clearBiometricCredentials() async {
    await _credentialStorage.delete('biometric_email');
    await _credentialStorage.delete('biometric_password');
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print("Password reset error: $e");
      rethrow;
    }
  }

  /// Create a new user and initialize their info in Firestore
  Future<User?> register(
    String email,
    String password,
    String fullName,
    String phoneNumber,
    String address,
  ) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final uid = userCredential.user!.uid;
        await userCredential.user!.updateDisplayName(fullName);
        final userInfo = UserInfo(
          uid: uid,
          email: email,
          phoneNumber: phoneNumber,
          address: address,
          fullName: fullName,
          createdAt: DateTime.now(),
        );
        await _userInfoService.saveUserInfo(userInfo);
      }

      return userCredential.user;
    } catch (e) {
      print("Registration error: $e");
      rethrow;
    }
  }

  String hashSecret(String secret) {
    final bytes = utf8.encode(secret);
    return sha256.convert(bytes).toString();
  }

  Future<UserInfo?> getCurrentUserInfo() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;
    final userInfo = await _userInfoService.getUserInfoByUid(currentUser.uid);
    if (userInfo != null) {
      if (userInfo.fullName.isNotEmpty && currentUser.displayName != userInfo.fullName) {
        await currentUser.updateDisplayName(userInfo.fullName);
      }
      return userInfo;
    }
    if (currentUser.email != null) {
      final fallbackUserInfo = await _userInfoService.getUserInfoByEmail(currentUser.email!);
      if (fallbackUserInfo != null &&
          fallbackUserInfo.fullName.isNotEmpty &&
          currentUser.displayName != fallbackUserInfo.fullName) {
        await currentUser.updateDisplayName(fallbackUserInfo.fullName);
      }
      return fallbackUserInfo;
    }
    return null;
  }

  Future<void> enableTwoFactor(UserInfo userInfo, String pin) async {
    final pinHash = hashSecret(pin);
    final updated = userInfo.copyWith(twoFactorEnabled: true, twoFactorPinHash: pinHash);
    await _userInfoService.saveUserInfo(updated);
  }

  Future<bool> validateTwoFactor(UserInfo userInfo, String pin) async {
    if (!userInfo.twoFactorEnabled || userInfo.twoFactorPinHash == null) return false;
    return userInfo.twoFactorPinHash == hashSecret(pin);
  }

  Future<void> disableTwoFactor(UserInfo userInfo) async {
    final updated = userInfo.copyWith(twoFactorEnabled: false, twoFactorPinHash: null);
    await _userInfoService.saveUserInfo(updated);
  }

  /// Get user information by email
  Future<UserInfo?> getUserInfo(String email) async {
    return await _userInfoService.getUserInfoByEmail(email);
  }

  /// Update the current user's Firebase Authentication password.
  Future<void> changePassword(String newPassword) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user found.',
      );
    }

    await currentUser.updatePassword(newPassword);
  }

  /// Get user info stream for real-time updates by UID
  Stream<UserInfo?> getUserInfoStreamByUid(String uid) {
    return _userInfoService.getUserInfoStreamByUid(uid);
  }

  /// Update user information
  Future<void> updateUserInfo(UserInfo userInfo) async {
    await _userInfoService.saveUserInfo(userInfo);
    if (_auth.currentUser != null && userInfo.fullName.isNotEmpty) {
      await _auth.currentUser!.updateDisplayName(userInfo.fullName);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Delete user account and their info from Firestore
  Future<void> deleteAccount(String uid) async {
    try {
      await _userInfoService.deleteUserInfoByUid(uid);
      await _auth.currentUser?.delete();
    } catch (e) {
      print("Error deleting account: $e");
      rethrow;
    }
  }
}