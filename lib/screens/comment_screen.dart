import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Ratedly/models/user.dart';
import 'package:Ratedly/providers/user_provider.dart';
import 'package:Ratedly/resources/posts_firestore_methods.dart';
import 'package:Ratedly/utils/utils.dart';
import 'package:Ratedly/widgets/comment_card.dart';
import 'package:provider/provider.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  const CommentsScreen({Key? key, required this.postId}) : super(key: key);

  @override
  CommentsScreenState createState() =>
      CommentsScreenState(); // Fixed: Public state class
}

class CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController commentEditingController =
      TextEditingController();
  final Color _textColor = const Color(0xFFd9d9d9);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF333333);
  final Color _iconColor = const Color(0xFFd9d9d9);

  void postComment(String uid, String name, String profilePic) async {
    try {
      if (commentEditingController.text.trim().isEmpty) {
        showSnackBar(context, "Comment cannot be empty");
        return;
      }
      String res = await FireStorePostsMethods().postComment(
        widget.postId,
        commentEditingController.text.trim(),
        uid,
        name,
        profilePic,
      );

      if (res != 'success') {
        if (mounted) {
          // Added mounted check
          showSnackBar(context, "Comment cannot be empty");
        }
      } else {
        setState(() {
          commentEditingController.clear();
        });
      }
    } catch (err) {
      showSnackBar(context, err.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserProvider userProvider = Provider.of<UserProvider>(context);
    final AppUser? user = userProvider.user;

    if (user == null) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(child: CircularProgressIndicator(color: _textColor)),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        iconTheme: IconThemeData(color: _textColor),
        backgroundColor: _backgroundColor,
        title: Text(
          'Comments',
          style: TextStyle(color: _textColor),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .orderBy('likeCount', descending: true)
            .orderBy('datePublished', descending: true)
            .snapshots(),
        builder: (context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: _textColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading comments: ${snapshot.error}',
                  style: TextStyle(color: _textColor)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No comments yet, be the first to comment!',
                style: TextStyle(color: _textColor),
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (ctx, index) {
              final commentSnap = snapshot.data!.docs[index];
              return CommentCard(
                snap: commentSnap,
                currentUserId: user.uid,
                postId: widget.postId,
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: kToolbarHeight,
          margin:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          padding: const EdgeInsets.only(left: 16, right: 8),
          decoration: BoxDecoration(
            color: _cardColor,
            border: Border(top: BorderSide(color: _cardColor)),
          ), // Added comma here
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: _cardColor,
                backgroundImage:
                    (user.photoUrl.isNotEmpty && user.photoUrl != "default")
                        ? NetworkImage(user.photoUrl)
                        : null,
                child: (user.photoUrl.isEmpty || user.photoUrl == "default")
                    ? Icon(
                        Icons.account_circle,
                        size: 42,
                        color: _iconColor,
                      )
                    : null,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: TextField(
                    controller: commentEditingController,
                    style: TextStyle(color: _textColor),
                    decoration: InputDecoration(
                      hintText: 'Comment as ${user.username}',
                      hintStyle: TextStyle(color: _textColor.withOpacity(0.6)),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: () => postComment(
                  user.uid,
                  user.username,
                  user.photoUrl,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Text(
                    'Post',
                    style: TextStyle(color: _textColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
