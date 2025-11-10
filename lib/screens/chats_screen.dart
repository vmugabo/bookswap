import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/swap_provider.dart';
import '../services/firebase_service.dart';
import '../models/swap_offer.dart';
import 'auth/login_screen.dart';
import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import '../utils/display_name.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseService.auth.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Offers')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please sign in to view offers'),
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                  child: const Text('Sign in'))
            ],
          ),
        ),
      );
    }

    final offersAsync = ref.watch(userOffersProvider(uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: offersAsync.when(
        data: (offers) {
          if (offers.isEmpty) return const Center(child: Text('No offers'));
          return ListView.builder(
            itemCount: offers.length,
            itemBuilder: (ctx, i) {
              final o = offers[i];
              return FutureBuilder(
                future: Future.wait([
                  ref.read(userProfileByIdProvider(o.fromUserId).future),
                  FirebaseService.firestore
                      .collection('books')
                      .doc(o.bookId)
                      .get()
                ]),
                builder: (context, snap) {
                  String name = 'Unknown user';
                  String bookTitle = o.bookId;
                  if (snap.connectionState == ConnectionState.done &&
                      snap.hasData) {
                    final list = snap.data as List<dynamic>;
                    final profile = list[0];
                    final bookDoc = list[1];
                    name = resolveDisplayNameFromUserData(
                        profile is Map<String, dynamic>
                            ? profile
                            : (profile?.toMap?.call() ?? profile));
                    try {
                      final bd = bookDoc as dynamic;
                      final bdata = bd.data() as Map<String, dynamic>?;
                      if (bdata != null &&
                          (bdata['title'] ?? '').toString().isNotEmpty) {
                        bookTitle = bdata['title'];
                      }
                    } catch (_) {
                      // ignore and fallback to id
                    }
                  }

                  return ListTile(
                    title: Text('Book: $bookTitle'),
                    subtitle: Text(
                        'From: $name — ${o.status.toString().split('.').last}'),
                    onTap: () async {
                      // open chat with the offer sender
                      final currentUid =
                          FirebaseService.auth.currentUser?.uid ?? '';
                      if (currentUid.isEmpty) {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const LoginScreen()));
                        return;
                      }
                      final cs = ChatService();
                      final chatId =
                          await cs.getOrCreateChat(currentUid, o.fromUserId);
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            ChatScreen(chatId: chatId, otherUid: o.fromUserId),
                      ));
                    },
                    trailing: o.status == SwapStatus.pending
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            TextButton(
                                onPressed: () async {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  try {
                                    await ref
                                        .read(swapControllerProvider)
                                        .updateOfferStatus(o.id, 'accepted');
                                    messenger.showSnackBar(const SnackBar(
                                        content: Text('Offer accepted')));
                                  } catch (e) {
                                    messenger.showSnackBar(
                                        SnackBar(content: Text('Error: $e')));
                                  }
                                },
                                child: const Text('Accept')),
                            TextButton(
                                onPressed: () async {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  try {
                                    await ref
                                        .read(swapControllerProvider)
                                        .updateOfferStatus(o.id, 'rejected');
                                    messenger.showSnackBar(const SnackBar(
                                        content: Text('Offer rejected')));
                                  } catch (e) {
                                    messenger.showSnackBar(
                                        SnackBar(content: Text('Error: $e')));
                                  }
                                },
                                child: const Text('Reject'))
                          ])
                        : Text(o.status.toString().split('.').last),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
