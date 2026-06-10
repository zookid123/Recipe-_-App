import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'recipe_detail_screen.dart';
import 'community_post_detail_screen.dart';
import 'chat_screen.dart';
import 'fridge_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('알림', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: const Center(
          child: Text('로그인 후 이용할 수 있어요.',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('알림', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => _markAllRead(user.id),
            child: const Text('모두 읽음',
                style: TextStyle(color: Colors.orange, fontSize: 13)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.orange));
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('알림이 없어요.',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return _NotifCard(
                docId: docs[i].id,
                userId: user.id,
                data: d,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _markAllRead(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}

class _NotifCard extends StatelessWidget {
  final String docId;
  final String userId;
  final Map<String, dynamic> data;

  const _NotifCard({
    required this.docId,
    required this.userId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = data['isRead'] == true;
    final type = data['type'] as String? ?? '';

    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(14),
          border: isRead
              ? Border.all(color: const Color(0xFFEEEEEE))
              : Border.all(color: Colors.orange.withValues(alpha: 0.4)),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 6)
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _iconBg(type),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon(type), color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isRead ? FontWeight.normal : FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['body'] ?? '',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(data['createdAt']),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(docId)
        .update({'isRead': true});

    final type = data['type'] as String? ?? '';
    final targetId = data['targetId'] as String?;
    if (targetId == null || !context.mounted) return;

    if (type == 'recipe_comment' || type == 'recipe_reply' ||
        type == 'trending' || type == 'recipe_like') {
      final snap = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(targetId)
          .get();
      if (!context.mounted) return;
      if (!snap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('삭제된 게시물입니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(recipe: <String, dynamic>{...snap.data()!, 'id': snap.id})),
      );
    } else if (type == 'fridge_expiry') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FridgeScreen()),
      );
    } else if (type == 'chat_message') {
      final senderId = data['senderId'] as String?;
      if (senderId == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            targetUserId: senderId,
            targetNickname: data['senderName'] as String? ?? '익명',
            targetProfileImg: data['senderProfileImg'] as String?,
            contextId: data['contextId'] as String? ?? '',
            contextTitle: data['contextTitle'] as String? ?? '',
          ),
        ),
      );
    } else if (type == 'community_comment' || type == 'community_reply' ||
               type == 'community_like') {
      final snap = await FirebaseFirestore.instance
          .collection('community')
          .doc(targetId)
          .get();
      if (!context.mounted) return;
      if (!snap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('삭제된 게시물입니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CommunityPostDetailScreen(docId: targetId, post: snap.data()!),
        ),
      );
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'trending':
        return Icons.local_fire_department;
      case 'recipe_comment':
        return Icons.chat_bubble;
      case 'community_comment':
        return Icons.forum;
      case 'recipe_reply':
      case 'community_reply':
        return Icons.reply;
      case 'recipe_like':
      case 'community_like':
        return Icons.favorite;
      case 'chat_message':
        return Icons.mail;
      case 'fridge_expiry':
        return Icons.kitchen;
      default:
        return Icons.notifications;
    }
  }

  Color _iconBg(String type) {
    switch (type) {
      case 'trending':
        return Colors.red;
      case 'recipe_comment':
        return Colors.orange;
      case 'community_comment':
        return Colors.blue;
      case 'recipe_reply':
      case 'community_reply':
        return Colors.green;
      case 'recipe_like':
      case 'community_like':
        return Colors.pink;
      case 'chat_message':
        return Colors.purple;
      case 'fridge_expiry':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inHours < 1) return '${diff.inMinutes}분 전';
      if (diff.inDays < 1) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dt.month}/${dt.day}';
    }
    return '';
  }
}
