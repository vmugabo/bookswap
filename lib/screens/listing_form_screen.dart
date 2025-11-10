import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/listings_provider.dart';
import '../services/firebase_service.dart';

class ListingFormScreen extends ConsumerStatefulWidget {
  final String? editingId;
  const ListingFormScreen({Key? key, this.editingId}) : super(key: key);

  @override
  ConsumerState<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends ConsumerState<ListingFormScreen> {
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  String _condition = 'Good';
  Uint8List? _imageBytes;
  String? _imageContentType;
  bool _loading = false;
  String? _existingImageUrl;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final res =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (res != null) {
      final bytes = await res.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageContentType = res.mimeType ?? 'image/jpeg';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.editingId != null) {
      // load existing listing
      FirebaseService.firestore
          .collection('books')
          .doc(widget.editingId)
          .get()
          .then((snap) {
        if (!mounted) return;
        final data = snap.data();
        if (data == null) return;
        setState(() {
          _titleCtrl.text = data['title'] ?? '';
          _authorCtrl.text = data['author'] ?? '';
          _condition = data['condition'] ?? 'Good';
          _existingImageUrl = data['imageUrl'] as String?;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editingId == null ? 'Post a Book' : 'Edit Listing'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Book Title',
                filled: true,
                fillColor: Colors.white,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _authorCtrl,
              decoration: InputDecoration(
                labelText: 'Author',
                filled: true,
                fillColor: Colors.white,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _condition,
              decoration: InputDecoration(
                labelText: 'Condition',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: ['New', 'Like New', 'Good', 'Used']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _condition = v ?? 'Good'),
            ),
            SizedBox(height: 12),
            _imageBytes == null
                ? (_existingImageUrl == null
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _pickImage,
                        icon: Icon(Icons.photo),
                        label: Text('Pick cover image'),
                      )
                    : Column(children: [
                        // show existing image url
                        ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child:
                                Image.network(_existingImageUrl!, height: 180)),
                        Row(
                          children: [
                            TextButton(
                                onPressed: _pickImage, child: Text('Replace')),
                            TextButton(
                                onPressed: () =>
                                    setState(() => _existingImageUrl = null),
                                child: Text('Remove'))
                          ],
                        )
                      ]))
                : Column(children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_imageBytes!, height: 180)),
                    TextButton(
                        onPressed: () => setState(() => _imageBytes = null),
                        child: Text('Remove'))
                  ]),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          try {
                            if (widget.editingId == null) {
                              await ref
                                  .read(listingsControllerProvider)
                                  .createListing(
                                      title: _titleCtrl.text.trim(),
                                      author: _authorCtrl.text.trim(),
                                      condition: _condition,
                                      image: _imageBytes,
                                      imageContentType: _imageContentType);
                            } else {
                              final changes = {
                                'title': _titleCtrl.text.trim(),
                                'author': _authorCtrl.text.trim(),
                                'condition': _condition,
                              };
                              // If user removed existing image and didn't pick a new one,
                              // clear the imageUrl field so the stored listing no longer has an image.
                              if (_imageBytes == null &&
                                  _existingImageUrl == null) {
                                changes['imageUrl'] = '';
                              }

                              await ref
                                  .read(listingsControllerProvider)
                                  .updateListing(widget.editingId!, changes,
                                      image: _imageBytes,
                                      imageContentType: _imageContentType);
                            }
                            if (!mounted) return;
                            Navigator.of(context).pop();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')));
                          }
                          setState(() => _loading = false);
                        },
                  child: _loading
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(widget.editingId == null ? 'Post' : 'Update',
                          style: TextStyle(fontSize: 16))),
            )
          ]),
        ),
      ),
    );
  }
}
