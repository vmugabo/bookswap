import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../models/book.dart';

class ListingsService {
  final _firestore = FirebaseService.firestore;
  final _storage = FirebaseService.storage;

  Stream<List<Book>> listingsStream() {
    return _firestore
        .collection('books')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => Book.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<String> _uploadImageBytes(Uint8List bytes,
      {String contentType = 'image/jpeg'}) async {
    final id = Uuid().v4();
    final ref = _storage.ref().child('book_covers/$id.jpg');
    try {
      await ref.putData(
          bytes, fb_storage.SettableMetadata(contentType: contentType));
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('ListingsService: image upload failed: $e');
      rethrow;
    }
  }

  Future<void> createListing(
      {required String title,
      required String author,
      required String condition,
      Uint8List? imageBytes,
      String? imageContentType,
      required String ownerId}) async {
    try {
      String imageUrl = '';
      if (imageBytes != null) {
        imageUrl = await _uploadImageBytes(imageBytes,
            contentType: imageContentType ?? 'image/jpeg');
      }
      await _firestore.collection('books').add({
        'title': title,
        'author': author,
        'condition': condition,
        'imageUrl': imageUrl,
        'ownerId': ownerId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('ListingsService.createListing failed: $e');
      rethrow;
    }
  }

  Future<void> updateListing(String id, Map<String, dynamic> changes,
      {Uint8List? imageBytes, String? imageContentType}) async {
    try {
      final docRef = _firestore.collection('books').doc(id);
      if (imageBytes != null) {
        // get existing document to delete old image
        final snap = await docRef.get();
        if (snap.exists) {
          final data = snap.data();
          final oldUrl = data?['imageUrl'] as String? ?? '';
          // upload new
          final newUrl = await _uploadImageBytes(imageBytes,
              contentType: imageContentType ?? 'image/jpeg');
          changes['imageUrl'] = newUrl;
          // delete old image if present
          if (oldUrl.isNotEmpty) {
            try {
              await _storage.refFromURL(oldUrl).delete();
            } catch (e) {
              // non-fatal: log and continue
              print(
                  'ListingsService.updateListing: failed to delete old image: $e');
            }
          }
        }
      } else if (changes.containsKey('imageUrl') &&
          (changes['imageUrl'] as String).isEmpty) {
        // User requested to remove the image without uploading a replacement.
        final snap = await docRef.get();
        if (snap.exists) {
          final data = snap.data();
          final oldUrl = data?['imageUrl'] as String? ?? '';
          if (oldUrl.isNotEmpty) {
            try {
              await _storage.refFromURL(oldUrl).delete();
            } catch (e) {
              print(
                  'ListingsService.updateListing: failed to delete old image on clear: $e');
            }
          }
        }
      }

      await _firestore.collection('books').doc(id).update(changes);
    } catch (e) {
      print('ListingsService.updateListing failed: $e');
      rethrow;
    }
  }

  Future<void> deleteListing(String id) async {
    try {
      final docRef = _firestore.collection('books').doc(id);
      final snap = await docRef.get();
      if (snap.exists) {
        final data = snap.data();
        final imageUrl = data?['imageUrl'] as String? ?? '';
        if (imageUrl.isNotEmpty) {
          try {
            await _storage.refFromURL(imageUrl).delete();
          } catch (e) {
            // log but continue with deletion
            print('ListingsService.deleteListing: failed to delete image: $e');
          }
        }
      }

      await docRef.delete();
    } catch (e) {
      print('ListingsService.deleteListing failed: $e');
      rethrow;
    }
  }
}
