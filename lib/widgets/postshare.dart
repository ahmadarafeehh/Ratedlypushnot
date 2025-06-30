import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:helloworld/resources/posts_firestore_methods.dart';
import 'package:helloworld/resources/messages_firestore_methods.dart';
import 'package:helloworld/utils/colors.dart';

class PostShare extends StatefulWidget {
  final String currentUserId;
  final String postId;

  const PostShare({
    Key? key,
    required this.currentUserId,
    required this.postId,
  }) : super(key: key);

  @override
  _PostShareState createState() => _PostShareState();
}

class _PostShareState extends State<PostShare> {
  List<String> selectedUsers = [];
  bool _isSharing = false;
  final _firestore = FirebaseFirestore.instance;

  Future<void> _sharePost() async {
    if (_isSharing || selectedUsers.isEmpty) return;

    setState(() => _isSharing = true);

    try {
      final postSnapshot =
          await _firestore.collection('posts').doc(widget.postId).get();
      if (!postSnapshot.exists) {
        throw Exception('Post does not exist');
      }

      final postData = postSnapshot.data() as Map<String, dynamic>;
      final String postImageUrl = postData['postUrl'] ?? '';
      final String postCaption = postData['description'] ?? '';
      final String postOwnerId = postData['uid'] ?? '';

      final userDoc =
          await _firestore.collection('users').doc(postOwnerId).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final String postOwnerUsername = userData['username'] ?? 'Unknown User';
      final String postOwnerPhotoUrl =
          userData['photoUrl']?.toString().trim() ?? '';

      for (String userId in selectedUsers) {
        final chatId = await FireStoreMessagesMethods()
            .getOrCreateChat(widget.currentUserId, userId);

        await FireStorePostsMethods().sharePostThroughChat(
          chatId: chatId,
          senderId: widget.currentUserId,
          receiverId: userId,
          postId: widget.postId,
          postImageUrl: postImageUrl,
          postCaption: postCaption,
          postOwnerId: postOwnerId,
          postOwnerUsername: postOwnerUsername,
          postOwnerPhotoUrl: postOwnerPhotoUrl,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post shared with ${selectedUsers.length} user(s)'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing post: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: mobileBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.grey[800]!),
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share Post',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chats')
                    .where('participants', arrayContains: widget.currentUserId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                        child: CircularProgressIndicator(color: primaryColor));
                  }

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_alt_outlined,
                              size: 40, color: primaryColor.withOpacity(0.6)),
                          const SizedBox(height: 16),
                          Text(
                            'No users to share with yet!\nFollow other users to share content.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: primaryColor.withOpacity(0.8),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final chat = snapshot.data!.docs[index];
                      final participants =
                          List<String>.from(chat['participants'] ?? []);
                      final otherUserId = participants.firstWhere(
                        (userId) => userId != widget.currentUserId,
                        orElse: () => '',
                      );

                      if (otherUserId.isEmpty) return const SizedBox.shrink();

                      return FutureBuilder<DocumentSnapshot>(
                        future: _firestore
                            .collection('users')
                            .doc(otherUserId)
                            .get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const ListTile(
                              title: Text('Loading...'),
                            );
                          }

                          if (!userSnapshot.hasData ||
                              !userSnapshot.data!.exists) {
                            return const ListTile(
                              title: Text('User not found'),
                            );
                          }

                          final userData = userSnapshot.data!.data()
                                  as Map<String, dynamic>? ??
                              {};
                          return ListTile(
                            tileColor: mobileBackgroundColor,
                            leading: CircleAvatar(
                              radius: 21,
                              backgroundColor: Colors.transparent,
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
                                      color: primaryColor,
                                    )
                                  : null,
                            ),
                            title: Text(
                              userData['username'] ?? 'Unknown User',
                              style: TextStyle(color: primaryColor),
                            ),
                            trailing: Checkbox(
                              value: selectedUsers.contains(otherUserId),
                              checkColor: primaryColor,
                              fillColor:
                                  MaterialStateProperty.all(secondaryColor),
                              onChanged: _isSharing
                                  ? null
                                  : (bool? selected) {
                                      setState(() {
                                        if (selected == true) {
                                          selectedUsers.add(otherUserId);
                                        } else {
                                          selectedUsers.remove(otherUserId);
                                        }
                                      });
                                    },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isSharing || selectedUsers.isEmpty ? null : _sharePost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueColor,
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSharing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : const Text('Share Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
