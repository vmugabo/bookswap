import 'package:cloud_firestore/cloud_firestore.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String condition; // New, Like New, Good, Used
  final String imageUrl;
  final String ownerId;
  final Timestamp createdAt;

  Book(
      {required this.id,
      required this.title,
      required this.author,
      required this.condition,
      required this.imageUrl,
      required this.ownerId,
      required this.createdAt});

  factory Book.fromMap(String id, Map<String, dynamic> m) {
    return Book(
      id: id,
      title: m['title'] ?? '',
      author: m['author'] ?? '',
      condition: m['condition'] ?? 'Used',
      imageUrl: m['imageUrl'] ?? '',
      ownerId: m['ownerId'] ?? '',
      createdAt: m['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'author': author,
      'condition': condition,
      'imageUrl': imageUrl,
      'ownerId': ownerId,
      'createdAt': createdAt,
    };
  }
}
