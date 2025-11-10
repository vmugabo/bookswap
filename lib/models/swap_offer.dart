import 'package:cloud_firestore/cloud_firestore.dart';

enum SwapStatus { pending, accepted, rejected }

class SwapOffer {
  final String id;
  final String bookId;
  final String fromUserId;
  final String toUserId;
  final SwapStatus status;
  final Timestamp createdAt;

  SwapOffer(
      {required this.id,
      required this.bookId,
      required this.fromUserId,
      required this.toUserId,
      required this.status,
      required this.createdAt});

  factory SwapOffer.fromMap(String id, Map<String, dynamic> m) {
    final statusRaw = (m['status'] ?? 'pending') as String;
    return SwapOffer(
      id: id,
      bookId: m['bookId'] ?? '',
      fromUserId: m['fromUserId'] ?? '',
      toUserId: m['toUserId'] ?? '',
      status: statusRaw == 'accepted'
          ? SwapStatus.accepted
          : statusRaw == 'rejected'
              ? SwapStatus.rejected
              : SwapStatus.pending,
      createdAt: m['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final statusString = status == SwapStatus.accepted
        ? 'accepted'
        : status == SwapStatus.rejected
            ? 'rejected'
            : 'pending';
    return {
      'bookId': bookId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': statusString,
      'createdAt': createdAt,
    };
  }
}
