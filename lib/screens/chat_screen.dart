import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/chat_service.dart';
import '../services/firebase_service.dart';
// user_profile import intentionally omitted; we fetch profile data directly in this screen.
// auth_provider import intentionally omitted — we use FirebaseService directly for current user id.

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String otherUid;
  const ChatScreen({Key? key, required this.chatId, required this.otherUid})
      : super(key: key);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  // server-provided messages
  List<Map<String, dynamic>> _serverMessages = [];
  // pending local messages not yet acknowledged by server
  List<Map<String, dynamic>> _pendingMessages = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  String _otherName = '';
  String? _otherImageUrl;

  @override
  void initState() {
    super.initState();
    _loadOtherProfile();
    _subscribe();
  }

  void _loadOtherProfile() async {
    final doc = await FirebaseService.firestore
        .collection('users')
        .doc(widget.otherUid)
        .get();
    if (!mounted) return;
    if (doc.exists && doc.data() != null) {
      final map = doc.data() as Map<String, dynamic>;
      setState(() {
        _otherName = (map['displayName'] ?? '') as String;
        _otherImageUrl = (map['imageUrl'] ?? '') as String?;
      });
    }
  }

  void _subscribe() {
    final cs = ChatService();
    _sub = cs.messagesStream(widget.chatId).listen((snap) {
      final server = <Map<String, dynamic>>[];
      final serverClientIds = <String>{};
      for (final d in snap.docs) {
        final m = d.data();
        final created = (m['createdAt'] is Timestamp)
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now();
        server.add({
          'id': d.id,
          'from': m['from'] as String? ?? '',
          'text': m['text'] as String? ?? '',
          'createdAt': created,
          'clientId': m['clientId'] as String?,
          'pending': false,
        });
        final cid = m['clientId'] as String?;
        if (cid != null) serverClientIds.add(cid);
      }

      // remove pending messages that the server acknowledged
      _pendingMessages.removeWhere((p) =>
          p['clientId'] != null && serverClientIds.contains(p['clientId']));

      setState(() {
        _serverMessages = server;
      });
      // scroll to bottom
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseService.auth.currentUser?.uid ?? '';
    final chatService = ChatService();

    // combined view: server messages, then local pending messages
    final combined = <Map<String, dynamic>>[];
    combined.addAll(_serverMessages);
    combined.addAll(_pendingMessages);
    combined.sort((a, b) {
      final ad = a['createdAt'] as DateTime;
      final bd = b['createdAt'] as DateTime;
      return ad.compareTo(bd);
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          if (_otherImageUrl != null && _otherImageUrl!.isNotEmpty)
            CircleAvatar(
                backgroundImage: NetworkImage(_otherImageUrl!), radius: 16)
          else
            CircleAvatar(
                child: Text(_otherName.isNotEmpty ? _otherName[0] : '?')),
          const SizedBox(width: 8),
          Text(_otherName.isNotEmpty ? _otherName : 'Chat')
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              itemCount: combined.length,
              itemBuilder: (ctx, i) {
                final m = combined[i];
                final from = m['from'] as String? ?? '';
                final text = m['text'] as String? ?? '';
                final created = m['createdAt'] as DateTime? ?? DateTime.now();
                final isMe = from == currentUid;
                final pending = m['pending'] as bool? ?? false;
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(text,
                                style: TextStyle(
                                    color:
                                        isMe ? Colors.white : Colors.black87)),
                            const SizedBox(height: 6),
                            Row(children: [
                              Text(_formatTime(created),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.black54)),
                              if (pending) ...[
                                const SizedBox(width: 8),
                                const Text('●',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.orange))
                              ]
                            ])
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Message...'),
                    ),
                  ),
                  IconButton(
                      onPressed: () async {
                        final text = _controller.text.trim();
                        if (text.isEmpty) return;
                        final clientId =
                            DateTime.now().microsecondsSinceEpoch.toString();
                        final localMessage = {
                          'clientId': clientId,
                          'from': currentUid,
                          'text': text,
                          'createdAt': DateTime.now(),
                          'pending': true,
                        };
                        setState(() {
                          _pendingMessages.add(localMessage);
                        });
                        _controller.clear();
                        // scroll to bottom quickly
                        await Future.delayed(const Duration(milliseconds: 50));
                        if (_scroll.hasClients)
                          _scroll.jumpTo(_scroll.position.maxScrollExtent);

                        try {
                          await chatService.sendMessage(
                              chatId: widget.chatId,
                              fromUid: currentUid,
                              text: text,
                              clientId: clientId);
                        } catch (e) {
                          // mark pending message as failed
                          setState(() {
                            final idx = _pendingMessages
                                .indexWhere((m) => m['clientId'] == clientId);
                            if (idx != -1)
                              _pendingMessages[idx]['failed'] = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Send failed: $e')));
                        }
                      },
                      icon: const Icon(Icons.send))
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
