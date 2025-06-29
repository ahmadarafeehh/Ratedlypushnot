import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Ratedly/screens/messaging_screen.dart';
import 'package:Ratedly/resources/messages_firestore_methods.dart';
import 'package:Ratedly/resources/block_firestore_methods.dart';

class FeedMessages extends StatelessWidget {
  final String currentUserId;
  final Color _textColor = const Color(0xFFd9d9d9);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF333333);
  final Color _iconColor = const Color(0xFFd9d9d9);

  const FeedMessages({Key? key, required this.currentUserId}) : super(key: key);

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final DateTime date = timestamp.toDate();
    final Duration difference = DateTime.now().difference(date);

    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'Just now';
  }

  Future<List<String>> _getSuggestedUsers(
      List<String> existingUserIds, int remaining) async {
    final blockedUsers =
        await FirestoreBlockMethods().getBlockedUsers(currentUserId);

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();

    final following = List<String>.from(userDoc['following'] ?? []);
    final followers = List<String>.from(userDoc['followers'] ?? []);

    List<String> candidates = [...following, ...followers]
        .where((id) => id != currentUserId)
        .where((id) => !existingUserIds.contains(id))
        .where((id) => !blockedUsers.contains(id))
        .toSet()
        .toList();

    List<String> suggested = candidates.take(remaining).toList();
    remaining -= suggested.length;

    if (remaining > 0) {
      final allUsers = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereNotIn: [
            ...existingUserIds,
            currentUserId,
            ...candidates,
            ...blockedUsers
          ])
          .limit(50)
          .get();

      final allUserIds = allUsers.docs.map((doc) => doc.id).toList();
      allUserIds.shuffle();
      suggested.addAll(allUserIds.take(remaining));
    }

    return suggested;
  }

  Widget _buildBlockedMessageItem() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.block, color: Colors.red[400], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This conversation is unavailable due to blocking',
              style: TextStyle(
                color: _textColor.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String photoUrl) {
    return CircleAvatar(
      radius: 21,
      backgroundColor: _cardColor,
      backgroundImage: (photoUrl.isNotEmpty && photoUrl != "default")
          ? NetworkImage(photoUrl)
          : null,
      child: (photoUrl.isEmpty || photoUrl == "default")
          ? Icon(
              Icons.account_circle,
              size: 42,
              color: _iconColor,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        iconTheme: IconThemeData(color: _textColor),
        backgroundColor: _backgroundColor,
        title: Text('Messages', style: TextStyle(color: _textColor)),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .snapshots(),
        builder: (context, chatSnapshot) {
          if (chatSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _textColor));
          }

          final existingChats = chatSnapshot.data?.docs ?? [];

          return FutureBuilder<List<String>>(
            future: FirestoreBlockMethods().getBlockedUsers(currentUserId),
            builder: (context, blockedSnapshot) {
              final blockedUsers = blockedSnapshot.data ?? [];

              // Filter out blocked chats
              final filteredChats = existingChats.where((chat) {
                final participants = List<String>.from(chat['participants']);
                final otherUserId =
                    participants.firstWhere((id) => id != currentUserId);
                return !blockedUsers.contains(otherUserId);
              }).toList();

              final existingUserIds = filteredChats.map((chat) {
                final participants = List<String>.from(chat['participants']);
                return participants.firstWhere((id) => id != currentUserId);
              }).toList();

              final remaining = 3 - existingUserIds.length;

              return FutureBuilder<List<String>>(
                future: remaining > 0
                    ? _getSuggestedUsers(existingUserIds, remaining)
                    : Future.value([]),
                builder: (context, suggestionSnapshot) {
                  final allUserIds = [
                    ...existingUserIds,
                    ...(suggestionSnapshot.data ?? [])
                  ].take(3).toList();

                  if (allUserIds.isEmpty) {
                    return Center(
                      child: Text(
                        'No users to display',
                        style: TextStyle(color: _textColor.withOpacity(0.6)),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 20),
                    itemCount: allUserIds.length,
                    itemBuilder: (context, index) {
                      final userId = allUserIds[index];
                      final isExistingChat = index < existingUserIds.length;
                      final chatDoc =
                          isExistingChat ? filteredChats[index] : null;

                      return FutureBuilder(
                        future: Future.wait([
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .get(),
                          FirestoreBlockMethods()
                              .isMutuallyBlocked(currentUserId, userId)
                        ]),
                        builder:
                            (context, AsyncSnapshot<List<dynamic>> snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();

                          final userDoc = snapshot.data![0] as DocumentSnapshot;
                          final isMutuallyBlocked = snapshot.data![1] as bool;

                          if (isMutuallyBlocked) {
                            return _buildBlockedMessageItem();
                          }
                          if (!userDoc.exists) {
                            return ListTile(
                              title: Text('Unknown User',
                                  style: TextStyle(color: _textColor)),
                            );
                          }
                          final userData =
                              userDoc.data() as Map<String, dynamic>;
                          final username = userData['username'] ?? 'Unknown';
                          final photoUrl = userData['photoUrl'] ?? '';

                          if (!isExistingChat) {
                            return ListTile(
                              leading: _buildUserAvatar(photoUrl),
                              title: Text(username,
                                  style: TextStyle(color: _textColor)),
                              trailing: Icon(Icons.person_add_alt_1,
                                  color: _iconColor),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MessagingScreen(
                                    recipientUid: userId,
                                    recipientUsername: username,
                                    recipientPhotoUrl: photoUrl,
                                  ),
                                ),
                              ),
                            );
                          }

                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('chats')
                                .doc(chatDoc!.id)
                                .collection('messages')
                                .orderBy('timestamp', descending: true)
                                .limit(1)
                                .snapshots(),
                            builder: (context, messageSnapshot) {
                              String lastMessage = 'No messages yet';
                              String timestampText = '';
                              bool isCurrentUserSender = false;
                              bool isMessageRead = false;

                              if (messageSnapshot.hasData &&
                                  messageSnapshot.data!.docs.isNotEmpty) {
                                final messageData =
                                    messageSnapshot.data!.docs.first.data()
                                        as Map<String, dynamic>;

                                isMessageRead = messageData['isRead'] ?? false;

                                if (messageData['type'] == 'post') {
                                  lastMessage = messageData['postCaption'] ??
                                      'Shared a post';
                                } else {
                                  lastMessage = messageData['message'] ?? '';
                                }

                                final Timestamp? timestamp =
                                    messageData['timestamp'] as Timestamp?;
                                timestampText = _formatTimestamp(timestamp);
                                isCurrentUserSender =
                                    messageData['senderId'] == currentUserId;
                              }

                              return StreamBuilder<int>(
                                stream: FireStoreMessagesMethods()
                                    .getUnreadCount(chatDoc.id, currentUserId),
                                builder: (context, unreadSnapshot) {
                                  final unreadCount = unreadSnapshot.data ?? 0;

                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                            color: _cardColor, width: 0.5),
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: _buildUserAvatar(photoUrl),
                                      title: Text(username,
                                          style: TextStyle(color: _textColor)),
                                      subtitle: Row(
                                        children: [
                                          if (isCurrentUserSender)
                                            Icon(
                                              isMessageRead
                                                  ? Icons.done_all
                                                  : Icons.done,
                                              size: 16,
                                              color:
                                                  _textColor.withOpacity(0.6),
                                            ),
                                          Expanded(
                                            child: Text(
                                              lastMessage,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: _textColor
                                                      .withOpacity(0.6)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            timestampText,
                                            style: TextStyle(
                                                color:
                                                    _textColor.withOpacity(0.6),
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      trailing: unreadCount > 0
                                          ? Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color:
                                                    _textColor.withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                unreadCount.toString(),
                                                style: TextStyle(
                                                    color: _textColor,
                                                    fontSize: 12),
                                              ),
                                            )
                                          : null,
                                      onTap: () {
                                        FireStoreMessagesMethods()
                                            .markMessagesAsRead(
                                                chatDoc.id, currentUserId);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                MessagingScreen(
                                              recipientUid: userId,
                                              recipientUsername: username,
                                              recipientPhotoUrl: photoUrl,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
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
