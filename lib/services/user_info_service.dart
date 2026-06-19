import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserInfoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Use the 'Users' collection which matches your Firestore console screenshot
  final String _collectionName = 'Users';

  /// Save or update user information in Firestore
  /// If `userInfo.uid` is present we use that as the document ID.
  Future<void> saveUserInfo(UserInfo userInfo) async {
    try {
      final docId = userInfo.uid ?? userInfo.email;
      await _firestore
          .collection(_collectionName)
          .doc(docId)
          .set(userInfo.toMap(), SetOptions(merge: true));
    } catch (e) {
      print("Error saving user info: $e");
      rethrow;
    }
  }

  /// Get user information by email.
  /// Tries document ID first, then falls back to a query by the `email` field.
  Future<UserInfo?> getUserInfoByEmail(String email) async {
    try {
      // Try direct document id (some code may have used email as the doc id)
      final docById = await _firestore.collection(_collectionName).doc(email).get();
      if (docById.exists && docById.data() != null) {
        return UserInfo.fromMap(docById.data() as Map<String, dynamic>);
      }

      // Otherwise query the collection for a document where email == email
      final query = await _firestore
          .collection(_collectionName)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        return UserInfo.fromMap(data);
      }

      return null;
    } catch (e) {
      print("Error getting user info by email: $e");
      rethrow;
    }
  }

  /// Get user information by UID (preferred when using Firebase Authentication)
  Future<UserInfo?> getUserInfoByUid(String uid) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserInfo.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print("Error getting user info by uid: $e");
      rethrow;
    }
  }

  /// Update specific fields of user information by UID
  Future<void> updateUserInfoByUid(String uid, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = DateTime.now().toIso8601String();
      await _firestore.collection(_collectionName).doc(uid).update(updates);
    } catch (e) {
      print("Error updating user info by uid: $e");
      rethrow;
    }
  }

  /// Delete user information (when account is deleted)
  Future<void> deleteUserInfoByUid(String uid) async {
    try {
      await _firestore.collection(_collectionName).doc(uid).delete();
    } catch (e) {
      print("Error deleting user info: $e");
      rethrow;
    }
  }

  /// Get real-time stream of user information by UID
  Stream<UserInfo?> getUserInfoStreamByUid(String uid) {
    return _firestore.collection(_collectionName).doc(uid).snapshots().map((docSnapshot) {
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return UserInfo.fromMap(docSnapshot.data() as Map<String, dynamic>);
      }
      return null;
    });
  }

  /// Check if user info exists for a given UID
  Future<bool> userInfoExistsByUid(String uid) async {
    try {
      final docSnapshot = await _firestore.collection(_collectionName).doc(uid).get();
      return docSnapshot.exists;
    } catch (e) {
      print("Error checking user info existence by uid: $e");
      return false;
    }
  }
}
