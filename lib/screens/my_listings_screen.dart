import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/listings_provider.dart';
import '../services/firebase_service.dart';
import 'listing_detail_screen.dart';
import 'listing_form_screen.dart';
import '../providers/swap_provider.dart';
import '../models/swap_offer.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class MyListingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(listingsStreamProvider);
    final uid = FirebaseService.auth.currentUser?.uid;
    final offersAsync = ref.watch(userOffersProvider(uid ?? ''));

    return Scaffold(
      appBar: AppBar(title: Text('My Listings')),
      body: listings.when(
        data: (items) {
          return Column(
            children: [
              // Offers section for this user's listings
              offersAsync.when(
                data: (offers) {
                  if (offers.isEmpty) {
                    // nothing to show here — fall through to listings
                    return SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('Offers on your books',
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      ...offers.map((o) => FutureBuilder(
                            future: FirebaseService.firestore
                                .collection('books')
                                .doc(o.bookId)
                                .get(),
                            builder: (ctx, snap) {
                              if (!snap.hasData)
                                return ListTile(title: Text('Loading...'));
                              final doc = snap.data as dynamic;
                              final bookData =
                                  doc.data() as Map<String, dynamic>?;
                              final title = bookData?['title'] ?? 'Unknown';
                              final imageUrl =
                                  bookData?['imageUrl'] as String? ?? '';
                              return FutureBuilder(
                                future: FirebaseService.firestore
                                    .collection('users')
                                    .doc(o.fromUserId)
                                    .get(),
                                builder: (ctx2, userSnap) {
                                  String fromName = 'Unknown user';
                                  if (userSnap.hasData) {
                                    final ud = (userSnap.data as dynamic).data()
                                        as Map<String, dynamic>?;
                                    if (ud != null &&
                                        (ud['displayName'] ?? '')
                                            .toString()
                                            .isNotEmpty) {
                                      fromName = ud['displayName'];
                                    } else if (ud != null &&
                                        (ud['email'] ?? '')
                                            .toString()
                                            .isNotEmpty) {
                                      fromName = ud['email'];
                                    }
                                  }

                                  return ListTile(
                                    leading: imageUrl.isNotEmpty
                                        ? Image.network(imageUrl,
                                            width: 56, fit: BoxFit.cover)
                                        : Icon(Icons.book),
                                    title: Text(title),
                                    subtitle: Text(
                                        'From: $fromName — ${o.status.toString().split('.').last}'),
                                    onTap: () async {
                                      final currentUid = FirebaseService
                                              .auth.currentUser?.uid ??
                                          '';
                                      if (currentUid.isEmpty) return;
                                      final cs = ChatService();
                                      final chatId = await cs.getOrCreateChat(
                                          currentUid, o.fromUserId);
                                      Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) => ChatScreen(
                                                  chatId: chatId,
                                                  otherUid: o.fromUserId)));
                                    },
                                    trailing: o.status == SwapStatus.pending
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                                TextButton(
                                                    onPressed: () async {
                                                      await ref
                                                          .read(
                                                              swapControllerProvider)
                                                          .updateOfferStatus(
                                                              o.id, 'accepted');
                                                    },
                                                    child: Text('Accept')),
                                                TextButton(
                                                    onPressed: () async {
                                                      await ref
                                                          .read(
                                                              swapControllerProvider)
                                                          .updateOfferStatus(
                                                              o.id, 'rejected');
                                                    },
                                                    child: Text('Reject'))
                                              ])
                                        : Text(o.status
                                            .toString()
                                            .split('.')
                                            .last),
                                  );
                                },
                              );
                            },
                          ))
                    ],
                  );
                },
                loading: () => SizedBox.shrink(),
                error: (_, __) => SizedBox.shrink(),
              ),

              // Listings list
              Builder(builder: (ctx) {
                final mine = items.where((b) => b.ownerId == uid).toList();
                if (mine.isEmpty) return Center(child: Text('No listings yet'));
                return Expanded(
                  child: ListView.builder(
                    itemCount: mine.length,
                    itemBuilder: (ctx, i) {
                      final b = mine[i];
                      return ListTile(
                        leading: b.imageUrl.isNotEmpty
                            ? Image.network(b.imageUrl,
                                width: 56, fit: BoxFit.cover)
                            : Icon(Icons.book),
                        title: Text(b.title),
                        subtitle: Text('${b.author} · ${b.condition}'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => ListingDetailScreen(book: b))),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              tooltip: 'Edit',
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ListingFormScreen(editingId: b.id))),
                              icon: Icon(Icons.edit)),
                          IconButton(
                              tooltip: 'Delete',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                          title: Text('Delete listing'),
                                          content: Text(
                                              'Are you sure you want to delete this listing?'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx)
                                                        .pop(false),
                                                child: Text('Cancel')),
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(true),
                                                child: Text('Delete')),
                                          ],
                                        ));
                                if (confirmed != true) return;
                                try {
                                  await ref
                                      .read(listingsControllerProvider)
                                      .deleteListing(b.id);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('Listing deleted')));
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')));
                                }
                              },
                              icon: Icon(Icons.delete, color: Colors.red)),
                        ]),
                      );
                    },
                  ),
                );
              })
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
