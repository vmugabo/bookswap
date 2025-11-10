import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../services/listings_service.dart';
import '../services/firebase_service.dart';

final listingsServiceProvider =
    Provider<ListingsService>((ref) => ListingsService());

final listingsStreamProvider = StreamProvider<List<Book>>(
    (ref) => ref.watch(listingsServiceProvider).listingsStream());

final listingsControllerProvider =
    Provider<ListingsController>((ref) => ListingsController(ref));

class ListingsController {
  final Ref _ref;
  ListingsController(this._ref);

  Future<void> createListing(
      {required String title,
      required String author,
      required String condition,
      Uint8List? image,
      String? imageContentType}) async {
    final ownerId = FirebaseService.auth.currentUser?.uid ?? '';
    await _ref.read(listingsServiceProvider).createListing(
        title: title,
        author: author,
        condition: condition,
        imageBytes: image,
        imageContentType: imageContentType,
        ownerId: ownerId);
  }

  Future<void> updateListing(String id, Map<String, dynamic> changes,
      {Uint8List? image, String? imageContentType}) async {
    await _ref.read(listingsServiceProvider).updateListing(id, changes,
        imageBytes: image, imageContentType: imageContentType);
  }

  Future<void> deleteListing(String id) async {
    await _ref.read(listingsServiceProvider).deleteListing(id);
  }
}
