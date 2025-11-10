import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class ChatService {
  final _firestore = FirebaseService.firestore;

  /// Deterministic chat id between two users: smallerUid_largerUid
  String _chatIdFor(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Create or ensure a chat document exists and return its id.
  Future<String> getOrCreateChat(String currentUid, String otherUid) async {
    final chatId = _chatIdFor(currentUid, otherUid);
    final ref = _firestore.collection('chats').doc(chatId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'chatId': chatId,
        'participants': [currentUid, otherUid],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return chatId;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Send a message. Optionally include a clientId to support optimistic UI
  /// de-duplication: the client may add a local message with clientId and
  /// the server-side document will include the same `clientId` so the
  /// client can match and remove the pending placeholder when the real
  /// message arrives.
  Future<void> sendMessage(
      {required String chatId,
      required String fromUid,
      required String text,
      String? clientId}) async {
    final ref =
        _firestore.collection('chats').doc(chatId).collection('messages');
    final data = <String, dynamic>{
      'from': fromUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (clientId != null) data['clientId'] = clientId;
    await ref.add(data);
    // update chat's updatedAt and lastMessage
    await _firestore.collection('chats').doc(chatId).update({
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': text,
    });
  }
}
