import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../providers/swap_provider.dart';
import '../providers/listings_provider.dart';
import '../services/firebase_service.dart';
import '../utils/display_name.dart';
import 'listing_form_screen.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  final Book book;
  const ListingDetailScreen({Key? key, required this.book}) : super(key: key);

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  bool _loading = false;

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('Delete listing'),
              content: Text('Are you sure you want to delete this listing?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text('Delete')),
              ],
            ));
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await ref.read(listingsControllerProvider).deleteListing(widget.book.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Listing deleted')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final currentUid = FirebaseService.auth.currentUser?.uid;
    final isOwner = currentUid != null && currentUid == book.ownerId;

    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (book.imageUrl.isNotEmpty)
              Hero(
                tag: 'book-image-${book.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(book.imageUrl,
                      height: 260, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
            SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text('By ${book.author}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey[300])),
                    SizedBox(height: 10),
                    Row(children: [
                      Chip(label: Text(book.condition)),
                      Spacer(),
                      FutureBuilder(
                        future: FirebaseService.firestore
                            .collection('users')
                            .doc(book.ownerId)
                            .get(),
                        builder: (context, snapshot) {
                          String ownerLabel = 'Unknown user';
                          if (snapshot.connectionState ==
                              ConnectionState.done) {
                            final data = snapshot.data?.data();
                            ownerLabel = resolveDisplayNameFromUserData(data);
                          }
                          return Text('Listed by: $ownerLabel',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12));
                        },
                      )
                    ]),
                    SizedBox(height: 8),
                    Divider(),
                    SizedBox(height: 8),
                    Text('Description',
                        style: Theme.of(context).textTheme.titleMedium),
                    SizedBox(height: 6),
                    Text(
                        'Listed on ${book.createdAt.toDate().toLocal().toString().split(' ').first}',
                        style: Theme.of(context).textTheme.bodySmall),
                    SizedBox(height: 12),
                    if (isOwner)
                      Row(children: [
                        ElevatedButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => ListingFormScreen(
                                                editingId: book.id)));
                                  },
                            child: Text('Edit')),
                        SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent),
                          onPressed: _loading ? null : _confirmAndDelete,
                          child: _loading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Text('Delete'),
                        )
                      ])
                    else if (currentUid != null && currentUid != book.ownerId)
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await ref.read(swapControllerProvider).createOffer(
                                bookId: book.id, toUserId: book.ownerId);
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Swap offer sent')));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')));
                          }
                        },
                        child: Text('Swap'),
                      )
                  ],
                ),
              ),
            )
          ]),
        ),
      ),
    );
  }
}
