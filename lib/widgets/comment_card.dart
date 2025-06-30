import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Ratedly/resources/posts_firestore_methods.dart';
import 'package:Ratedly/resources/block_firestore_methods.dart';
import 'package:Ratedly/screens/Profile_page/profile_page.dart';
import 'package:flutter/gestures.dart';

class CommentCard extends StatelessWidget {
  final dynamic snap;
  final String currentUserId;
  final String postId;

  const CommentCard({
    super.key,
    required this.snap,
    required this.currentUserId,
    required this.postId,
  });

  final Color _textColor = const Color(0xFFd9d9d9);
  final Color _cardColor = const Color(0xFF333333);

  void _deleteComment(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Delete Comment', style: TextStyle(color: _textColor)),
        content: Text('Are you sure you want to delete this comment?',
            style: TextStyle(color: _textColor.withOpacity(0.8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _textColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red[400])),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        await FireStorePostsMethods().deleteComment(
          postId,
          snap['commentId'],
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> likes = List<String>.from(snap['likes'] ?? []);
    bool isLiked = likes.contains(currentUserId);
    int likeCount = snap['likeCount'] ?? 0;

    return FutureBuilder<bool>(
      future: FirestoreBlockMethods().isMutuallyBlocked(
        currentUserId,
        snap['uid'],
      ),
      builder: (context, blockSnapshot) {
        final isBlocked = blockSnapshot.data ?? false;

        if (isBlocked) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          color: _cardColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(snap['uid'])
                    .get(),
                builder: (context, userSnapshot) {
                  final userData =
                      (userSnapshot.data?.data() as Map<String, dynamic>?) ??
                          {};

                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(uid: snap['uid']),
                      ),
                    ),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 21,
                            backgroundColor: _cardColor,
                            backgroundImage: (userData['photoUrl'] != null &&
                                    userData['photoUrl'].isNotEmpty &&
                                    userData['photoUrl'] != "default")
                                ? NetworkImage(userData['photoUrl'])
                                : null,
                            child: (userData['photoUrl'] == null ||
                                    userData['photoUrl'].isEmpty ||
                                    userData['photoUrl'] == "default")
                                ? Icon(
                                    Icons.account_circle,
                                    size: 42,
                                    color: _textColor.withOpacity(0.8),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: snap['name'],
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _textColor),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ProfileScreen(uid: snap['uid']),
                                      ),
                                    ),
                            ),
                            TextSpan(
                                text: ' ${snap['text']}',
                                style: TextStyle(
                                    color: _textColor.withOpacity(0.9))),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat.yMMMd()
                              .format(snap['datePublished'].toDate()),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: _textColor.withOpacity(0.6)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (snap['uid'] == currentUserId)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        size: 16, color: _textColor.withOpacity(0.8)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: _cardColor,
                    onSelected: (value) => _deleteComment(context),
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete Comment',
                            style: TextStyle(color: _textColor)),
                      ),
                    ],
                  ),
                ),
              Column(
                children: [
                  IconButton(
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      try {
                        await FireStorePostsMethods().likeComment(
                          postId,
                          snap['commentId'],
                          currentUserId,
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${e.toString()}')),
                        );
                      }
                    },
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked
                          ? Colors.red[400]
                          : _textColor.withOpacity(0.6),
                      size: 16,
                    ),
                  ),
                  Text(
                    likeCount.toString(),
                    style: TextStyle(
                        fontSize: 12, color: _textColor.withOpacity(0.8)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
