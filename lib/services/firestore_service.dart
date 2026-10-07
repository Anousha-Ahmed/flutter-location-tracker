import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Saves to user_locations/{uid}. Same document is updated every time.
  Future<void> saveUserLocation({
    required String uid,
    required double latitude,
    required double longitude,
  }) {
    return _db.collection('user_locations').doc(uid).set({
      'userId': uid,
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}