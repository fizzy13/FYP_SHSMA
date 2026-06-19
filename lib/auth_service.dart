import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'models/user_model.dart';
import 'services/user_info_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserInfoService _userInfoService = UserInfoService();

  /// Get current authenticated user
  User? get currentUser => _auth.currentUser;

  Future<User?> login(String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Login error: $e");
      return null;
    }
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