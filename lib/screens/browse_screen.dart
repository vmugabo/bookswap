import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/listings_provider.dart';
import '../models/book.dart';
import 'listing_detail_screen.dart';
import 'listing_form_screen.dart';

class BrowseScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(listingsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Browse Listings')),
      body: listings.when(
        data: (items) {
          if (items.isEmpty) return Center(child: Text('No listings yet'));
          return ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: _BookCard(book: items[i]),
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => ListingFormScreen())),
        child: Icon(Icons.add),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;
  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ListingDetailScreen(book: book))),
        child: Row(
          children: [
            Hero(
              tag: 'book-image-${book.id}',
              child: Container(
                width: 110,
                height: 140,
                decoration: BoxDecoration(
                  image: book.imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(book.imageUrl), fit: BoxFit.cover)
                      : null,
                  color: book.imageUrl.isEmpty ? Colors.grey[800] : null,
                ),
                child: book.imageUrl.isEmpty
                    ? Center(
                        child:
                            Icon(Icons.book, size: 40, color: Colors.white70))
                    : null,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                    SizedBox(height: 6),
                    Text(book.author,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[300], fontSize: 13)),
                    SizedBox(height: 12),
                    Row(children: [
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.indigo.shade700,
                            borderRadius: BorderRadius.circular(16)),
                        child: Text(book.condition,
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      Spacer(),
                      IconButton(
                          onPressed: () {},
                          icon: Icon(Icons.favorite_border,
                              color: Colors.amber[200]))
                    ])
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
