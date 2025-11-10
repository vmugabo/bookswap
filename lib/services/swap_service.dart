import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../models/swap_offer.dart';

class SwapService {
  final _firestore = FirebaseService.firestore;

  Future<void> createOffer(
      {required String bookId,
      required String fromUserId,
      required String toUserId}) async {
    await _firestore.collection('offers').add({
      'bookId': bookId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<SwapOffer>> offersForUser(String uid) {
    return _firestore
        .collection('offers')
        .where('toUserId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => SwapOffer.fromMap(d.id, d.data())).toList());
  }

  Future<void> updateOfferStatus(String offerId, String status) async {
    final offerRef = _firestore.collection('offers').doc(offerId);
    await offerRef.update({'status': status});

    // If accepted, transfer ownership of the book to the offer.fromUserId.
    if (status == 'accepted') {
      final snap = await offerRef.get();
      if (snap.exists) {
        final data = snap.data();
        final bookId = data?['bookId'] as String?;
        final fromUserId = data?['fromUserId'] as String?;
        if (bookId != null && fromUserId != null) {
          try {
            await _firestore
                .collection('books')
                .doc(bookId)
                .update({'ownerId': fromUserId});
          } catch (e) {
            // log but don't fail the offer status update
            print(
                'SwapService.updateOfferStatus: failed to transfer ownership: $e');
          }
        }
      }
    }
  }
}
