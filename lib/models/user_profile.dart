import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String imageUrl;
  final bool notifications;
  final DateTime? createdAt;

  UserProfile(
      {required this.uid,
      required this.email,
      required this.displayName,
      required this.imageUrl,
      required this.notifications,
      this.createdAt});

  factory UserProfile.fromMap(Map<String, dynamic> m) {
    DateTime? created;
    final raw = m['createdAt'];
    if (raw is Timestamp) {
      created = raw.toDate();
    } else if (raw is DateTime) {
      created = raw;
    }

    return UserProfile(
      uid: m['uid'] ?? '',
      email: m['email'] ?? '',
      displayName: m['displayName'] ?? '',
      imageUrl: m['imageUrl'] ?? '',
      notifications: m['notifications'] ?? true,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'imageUrl': imageUrl,
      'notifications': notifications,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }
}
