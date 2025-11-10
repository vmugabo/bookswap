import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/swap_service.dart';
import '../models/swap_offer.dart';
import '../services/firebase_service.dart';

final swapServiceProvider = Provider<SwapService>((ref) => SwapService());

final userOffersProvider =
    StreamProvider.autoDispose.family<List<SwapOffer>, String>((ref, uid) {
  return ref.watch(swapServiceProvider).offersForUser(uid);
});

final swapControllerProvider =
    Provider<SwapController>((ref) => SwapController(ref));

class SwapController {
  final Ref _ref;
  SwapController(this._ref);

  Future<void> createOffer(
      {required String bookId, required String toUserId}) async {
    final fromUserId = FirebaseService.auth.currentUser?.uid ?? '';
    await _ref.read(swapServiceProvider).createOffer(
        bookId: bookId, fromUserId: fromUserId, toUserId: toUserId);
  }

  Future<void> updateOfferStatus(String id, String status) async {
    await _ref.read(swapServiceProvider).updateOfferStatus(id, status);
  }
}
