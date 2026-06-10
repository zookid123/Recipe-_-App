import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    final dt = (ts as Timestamp).toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('채팅'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: const Center(child: Text('로그인 후 채팅 내역을 볼 수 있어요.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('채팅', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chatRooms')
            .where('participants', arrayContains: user.id)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('아직 채팅이 없어요',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
                  const SizedBox(height: 6),
                  Text('커뮤니티 게시글에서 작성자와 채팅해보세요',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                ],
              ),
            );
          }

          final docs = snap.data!.docs.toList()
            ..sort((a, b) {
              final aTs = (a.data() as Map)['lastTimestamp'];
              final bTs = (b.data() as Map)['lastTimestamp'];
              if (aTs == null) return 1;
              if (bTs == null) return -1;
              return (bTs as Timestamp).compareTo(aTs as Timestamp);
            });

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final participants = List<String>.from(data['participants'] ?? []);
              final otherId = participants.firstWhere(
                (id) => id != user.id,
                orElse: () => '',
              );
              // 대화 상대 닉네임: 내가 보낸 쪽이면 targetNickname, 아니면 역방향
              final targetNickname = data['targetNickname'] as String? ?? '상대방';
              final targetProfileImg = data['targetProfileImg'] as String?;
              final lastMsg = data['lastMessage'] as String? ?? '';
              final lastTs = data['lastTimestamp'];
              final contextTitle = data['contextTitle'] as String? ?? '';

              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.orange.shade100,
                  backgroundImage: (targetProfileImg?.isNotEmpty == true)
                      ? NetworkImage(targetProfileImg!)
                      : null,
                  child: (targetProfileImg?.isNotEmpty != true)
                      ? const Icon(Icons.person, color: Colors.orange)
                      : null,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        otherId == user.id ? '나 (${user.nickname})' : targetNickname,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(_formatTime(lastTs),
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lastMsg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    if (contextTitle.isNotEmpty)
                      Text('게시글: $contextTitle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.orange)),
                  ],
                ),
                isThreeLine: contextTitle.isNotEmpty,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        targetUserId: otherId,
                        targetNickname: targetNickname,
                        targetProfileImg: targetProfileImg,
                        contextId: data['contextId'] ?? '',
                        contextTitle: contextTitle,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
