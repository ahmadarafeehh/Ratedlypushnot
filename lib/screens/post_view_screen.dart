// ImageViewScreen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:helloworld/providers/user_provider.dart';
import 'package:helloworld/resources/posts_firestore_methods.dart';
import 'package:helloworld/screens/comment_screen.dart';
import 'package:helloworld/screens/Profile_page/profile_page.dart';
import 'package:helloworld/utils/utils.dart';
import 'package:helloworld/widgets/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:helloworld/widgets/postshare.dart';
import 'package:helloworld/widgets/rating_list_screen_postcard.dart';
import 'package:helloworld/resources/block_firestore_methods.dart';
import 'package:helloworld/widgets/blocked_content_message.dart';

class ImageViewScreen extends StatefulWidget {
  final String imageUrl;
  final String postId;
  final String description;
  final String userId;
  final String username;
  final String profImage;
  final VoidCallback? onPostDeleted;

  const ImageViewScreen({
    Key? key,
    required this.imageUrl,
    required this.postId,
    required this.description,
    required this.userId,
    required this.username,
    required this.profImage,
    this.onPostDeleted,
  }) : super(key: key);

  @override
  State<ImageViewScreen> createState() => _ImageViewScreenState();
}

class _ImageViewScreenState extends State<ImageViewScreen> {
  int commentLen = 0;
  List<dynamic> _localRatings = [];
  bool _isBlocked = false;
  final List<String> reportReasons = [
    'I just don’t like it',
    'Discriminatory content',
    'Bullying or harassment',
    'Violence or hate speech',
    'Selling prohibited items',
    'Pornography or nudity',
    'Scam or fraudulent activity',
    'Spam',
    'Misinformation',
  ];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _checkBlockStatus();
  }

  Future<void> _fetchInitialData() async {
    try {
      // Fetch comments
      final comments = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .get();
      setState(() => commentLen = comments.docs.length);

      // Fetch ratings
      final postSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();
      setState(() {
        _localRatings = List.from(postSnapshot['rate'] ?? []);
      });
    } catch (err) {
      if (mounted) showSnackBar(context, err.toString());
    }
  }

  Future<void> _checkBlockStatus() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    final isBlocked = await FirestoreBlockMethods().isMutuallyBlocked(
      user.uid,
      widget.userId,
    );

    if (mounted) setState(() => _isBlocked = isBlocked);
  }

  void _handleRatingSubmitted(double rating) async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    // Store original ratings for rollback
    final originalRatings = List.from(_localRatings);

    // Optimistic UI update
    setState(() {
      _localRatings.removeWhere((r) => r['userId'] == user.uid);
      _localRatings.add({
        'userId': user.uid,
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    try {
      final response = await FireStorePostsMethods().ratePost(
        widget.postId,
        user.uid,
        rating,
      );

      if (response != 'success' && mounted) {
        // Rollback if failed
        setState(() => _localRatings = originalRatings);
        showSnackBar(context, 'Failed to submit rating');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _localRatings = originalRatings);
        showSnackBar(context, 'Error: ${e.toString()}');
      }
    }
  }

  deletePost(String postId) async {
    try {
      await FireStorePostsMethods().deletePost(postId);
      if (mounted) {
        widget.onPostDeleted?.call();
        Navigator.of(context).pop();
      }
    } catch (err) {
      if (mounted) {
        showSnackBar(context, err.toString());
      }
    }
  }

  void _showReportDialog() {
    String? selectedReason;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF121212),
              title: const Text('Report Post',
                  style: TextStyle(color: Color(0xFFd9d9d9))),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thank you for helping keep our community safe.\n\nPlease let us know the reason for reporting this content. Your report is anonymous, and our moderators will review it as soon as possible. \n\n If you prefer not to see this user posts or content, you can choose to block them.',
                      style: TextStyle(color: Color(0xFFd9d9d9), fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select a reason: \n',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFd9d9d9),
                      ),
                    ),
                    ...reportReasons.map((reason) {
                      return RadioListTile<String>(
                        title: Text(reason,
                            style: const TextStyle(color: Color(0xFFd9d9d9))),
                        value: reason,
                        groupValue: selectedReason,
                        activeColor: const Color(0xFFd9d9d9),
                        onChanged: (value) {
                          setState(() => selectedReason = value);
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFFd9d9d9))),
                ),
                TextButton(
                  onPressed: selectedReason != null
                      ? () {
                          FireStorePostsMethods()
                              .reportPost(
                            widget.postId,
                            selectedReason!,
                          )
                              .then((res) {
                            Navigator.pop(context);
                            if (res == 'success') {
                              showSnackBar(
                                  context, 'Report submitted. Thank you!');
                            } else {
                              showSnackBar(
                                  context, 'Failed to submit report: $res');
                            }
                          });
                        }
                      : null,
                  child: const Text('Submit',
                      style: TextStyle(color: Color(0xFFd9d9d9))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    if (user == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_isBlocked) {
      return Scaffold(
        appBar: AppBar(),
        body: const BlockedContentMessage(
          message: 'Post unavailable due to blocking',
        ),
      );
    }

    // Calculate ratings from local state
    final numRatings = _localRatings.length;
    final averageRating = numRatings > 0
        ? _localRatings.fold(
                0.0, (sum, r) => sum + (r['rating'] as num).toDouble()) /
            numRatings
        : 0.0;

    // Get current user's rating
    final userRating = _localRatings.firstWhere(
      (r) => r['userId'] == user.uid,
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Color(0xFFd9d9d9)),
        backgroundColor: const Color(0xFF121212),
        title: Text(
          widget.username,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFd9d9d9),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFd9d9d9)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFFd9d9d9)),
            onPressed: () {
              if (FirebaseAuth.instance.currentUser?.uid == widget.userId) {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: const Color(0xFF121212),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shrinkWrap: true,
                      children: [
                        InkWell(
                          onTap: () {
                            deletePost(widget.postId);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Color(0xFFd9d9d9)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                _showReportDialog();
              }
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // User header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16)
                  .copyWith(right: 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(uid: widget.userId),
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 21,
                      backgroundColor: const Color(0xFF333333),
                      backgroundImage: (widget.profImage.isNotEmpty &&
                              widget.profImage != "default")
                          ? NetworkImage(widget.profImage)
                          : null,
                      child: (widget.profImage.isEmpty ||
                              widget.profImage == "default")
                          ? Icon(Icons.account_circle,
                              size: 42, color: Colors.grey[600])
                          : null,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProfileScreen(uid: widget.userId),
                              ),
                            ),
                            child: Text(
                              widget.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFd9d9d9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Image
            Image.network(
              widget.imageUrl,
              fit: BoxFit.fitWidth,
              width: double.infinity,
            ),

            // Description
            if (widget.description.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.description,
                    style: const TextStyle(
                      color: Color(0xFFd9d9d9),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            // Rating section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RatingBar(
                    initialRating: userRating?['rating']?.toDouble() ?? 1.0,
                    hasRated: userRating != null,
                    userRating: userRating?['rating']?.toDouble() ?? 1.0,
                    onRatingEnd: _handleRatingSubmitted,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        // Comment button
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.comment_outlined,
                                  color: Color(0xFFd9d9d9)),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CommentsScreen(postId: widget.postId),
                                ),
                              ),
                            ),
                            if (commentLen > 0)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF333333),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    commentLen.toString(),
                                    style: const TextStyle(
                                      color: Color(0xFFd9d9d9),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Share button
                        IconButton(
                          icon:
                              const Icon(Icons.send, color: Color(0xFFd9d9d9)),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => PostShare(
                                currentUserId: user.uid,
                                postId: widget.postId,
                              ),
                            );
                          },
                        ),

                        const Spacer(),

                        // Rating summary
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RatingListScreen(
                                  postId: widget.postId,
                                  initialRatings: _localRatings,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Text(
                              'Rated ${averageRating.toStringAsFixed(1)} by $numRatings ${numRatings == 1 ? 'voter' : 'voters'}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFd9d9d9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
