import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final String targetUserId;
  final String targetNickname;
  final String? targetProfileImg;
  final String contextId; // 게시글 ID 또는 레시피 ID
  final String contextTitle; // 게시글 제목 또는 레시피 이름

  const ChatScreen({
    super.key,
    required this.targetUserId,
    required this.targetNickname,
    this.targetProfileImg,
    required this.contextId,
    required this.contextTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String get _chatRoomId {
    final myId = AuthService.instance.currentUser?.id ?? 'guest';
    final ids = [myId, widget.targetUserId]..sort();
    return '${ids[0]}_${ids[1]}_${widget.contextId}';
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final roomId = _chatRoomId;
    final batch = FirebaseFirestore.instance.batch();

    // 1. 메시지 추가
    final msgRef = FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .doc();
    batch.set(msgRef, {
      'text': text,
      'senderId': user.id,
      'senderName': user.nickname,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. 방 메타데이터 업데이트 (목록용)
    final roomRef = FirebaseFirestore.instance.collection('chatRooms').doc(roomId);
    batch.set(roomRef, {
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'participants': [user.id, widget.targetUserId],
      'contextId': widget.contextId,
      'contextTitle': widget.contextTitle,
      'targetNickname': widget.targetNickname,
      'targetProfileImg': widget.targetProfileImg,
    }, SetOptions(merge: true));

    await batch.commit();
    _msgCtrl.clear();
    _scrollDown();

    // 받는 사람에게 쪽지 알림
    if (widget.targetUserId != user.id) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.targetUserId)
            .collection('notifications')
            .add({
          'type': 'chat_message',
          'title': '새 쪽지가 도착했어요 💌',
          'body': '${user.nickname}님: ${text.length > 30 ? '${text.substring(0, 30)}...' : text}',
          'isRead': false,
          'targetId': roomId,
          'senderId': user.id,
          'senderName': user.nickname,
          'senderProfileImg': user.profileImageUrl,
          'contextId': widget.contextId,
          'contextTitle': widget.contextTitle,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(widget.targetNickname,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.contextTitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chatRooms')
                  .doc(_chatRoomId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == AuthService.instance.currentUser?.id;
                    return _buildBubble(data, isMe);
                  },
                );
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요...',
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _send,
            icon: const Icon(Icons.send_rounded, color: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> data, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? Colors.orange : Colors.white,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isMe ? const Radius.circular(0) : null,
                bottomLeft: isMe ? null : const Radius.circular(0),
              ),
              boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Text(
              data['text'] ?? '',
              style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
