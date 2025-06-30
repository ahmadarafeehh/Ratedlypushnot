import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:helloworld/models/user.dart' as model;
import 'package:helloworld/providers/user_provider.dart';
import 'package:helloworld/resources/posts_firestore_methods.dart';
import 'package:helloworld/screens/comment_screen.dart';
import 'package:helloworld/screens/Profile_page/profile_page.dart';
import 'package:helloworld/utils/utils.dart';
import 'package:helloworld/widgets/rating_section.dart';
import 'package:helloworld/widgets/postshare.dart';
import 'package:helloworld/widgets/rating_list_screen_postcard.dart';
import 'package:helloworld/resources/block_firestore_methods.dart';
import 'package:helloworld/widgets/blocked_content_message.dart';

class PostCard extends StatefulWidget {
  final dynamic snap;
  final VoidCallback? onRateUpdate;

  const PostCard({
    Key? key,
    required this.snap,
    this.onRateUpdate,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late int _commentCount;
  bool _isBlocked = false;
  bool _viewRecorded = false;
  late List<dynamic> _localRatings;
  final List<String> _reportReasons = [
    'I just don’t like it',
    'Discriminatory content (e.g., religion, race, gender, or other)',
    'Bullying or harassment',
    'Violence, hate speech, or harmful content',
    'Selling prohibited items',
    'Pornography or nudity',
    'Scam or fraudulent activity',
    'Spam',
    'Misinformation',
  ];

  @override
  void initState() {
    super.initState();
    _localRatings = List.from(widget.snap['rate'] ?? []);
    _commentCount = widget.snap['comments']?.length ?? 0;
    _checkBlockStatus();
    _recordView();
    _setupCommentListener();
  }

  void _setupCommentListener() {
    FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.snap['postId'])
        .collection('comments')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _commentCount = snapshot.docs.length);
      }
    });
  }

  Future<void> _checkBlockStatus() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    final isBlocked = await FirestoreBlockMethods().isMutuallyBlocked(
      user.uid,
      widget.snap['uid'],
    );

    if (mounted) setState(() => _isBlocked = isBlocked);
  }

  Future<void> _recordView() async {
    if (_viewRecorded) return;

    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user != null) {
      await FireStorePostsMethods().recordPostView(
        widget.snap['postId'],
        user.uid,
      );
      if (mounted) setState(() => _viewRecorded = true);
    }
  }

  void _handleRatingSubmitted(double rating) async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    // Store original ratings for potential rollback
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
        widget.snap['postId'],
        user.uid,
        rating,
      );

      if (response != 'success' && mounted) {
        // Rollback if failed
        setState(() => _localRatings = originalRatings);
      }
    } catch (e) {
      if (mounted) setState(() => _localRatings = originalRatings);
    }
  }

  void _showReportDialog() {
    String? selectedReason;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF121212),
          title:
              const Text('Report Post', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thank you for helping keep our community safe.\n\nPlease let us know the reason for reporting this content.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ..._reportReasons
                    .map((reason) => RadioListTile<String>(
                          title: Text(reason,
                              style: const TextStyle(color: Colors.white)),
                          value: reason,
                          groupValue: selectedReason,
                          activeColor: Colors.white,
                          onChanged: (value) =>
                              setState(() => selectedReason = value),
                        ))
                    .toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: selectedReason != null
                  ? () => _submitReport(selectedReason!)
                  : null,
              child:
                  const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    Navigator.pop(context);
    try {
      await FireStorePostsMethods().reportPost(widget.snap['postId'], reason);
      showSnackBar(context, 'Report submitted successfully');
    } catch (e) {
      showSnackBar(context, 'Error submitting report: ${e.toString()}');
    }
  }

  Future<void> _deletePost() async {
    try {
      await FireStorePostsMethods().deletePost(widget.snap['postId']);
      showSnackBar(context, 'Post deleted successfully');
    } catch (e) {
      showSnackBar(context, 'Error deleting post: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isBlocked) {
      return const BlockedContentMessage(
        message: 'Post unavailable due to blocking',
      );
    }

    final user = Provider.of<UserProvider>(context).user;
    if (user == null) return const SizedBox.shrink();

    final numRatings = _localRatings.length;
    final averageRating = numRatings > 0
        ? _localRatings.fold(
                0.0, (sum, r) => sum + (r['rating'] as num).toDouble()) /
            numRatings
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF333333)),
        color: const Color(0xFF121212),
      ), // Added closing parenthesis and comma
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          _buildHeader(user, averageRating),
          _buildImageSection(),
          RatingSection(
            postId: widget.snap['postId'],
            userId: user.uid,
            ratings: _localRatings,
            onRatingEnd: _handleRatingSubmitted,
          ),
          _buildActionBar(user, numRatings, averageRating),
        ],
      ),
    );
  }

  Widget _buildHeader(model.AppUser user, double averageRating) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16)
          .copyWith(right: 0),
      child: Row(
        children: [
          _buildUserAvatar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _navigateToProfile(),
                    child: Text(
                      widget.snap['username'].toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFd9d9d9),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildMoreButton(user),
        ],
      ),
    );
  }

  Widget _buildActionBar(
      model.AppUser user, int numRatings, double averageRating) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          _buildCommentButton(),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFFd9d9d9)),
            onPressed: () => showDialog(
              context: context,
              builder: (context) => PostShare(
                currentUserId: user.uid,
                postId: widget.snap['postId'],
              ),
            ),
          ),
          const Spacer(),
          _buildRatingSummary(numRatings, averageRating),
        ],
      ),
    );
  }

  Widget _buildRatingSummary(int numRatings, double averageRating) {
    return InkWell(
      onTap: () => _navigateToRatingList(),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          'Rated ${averageRating.toStringAsFixed(1)} by $numRatings ${numRatings == 1 ? 'voter' : 'voters'}',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFFd9d9d9),
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  void _navigateToRatingList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RatingListScreen(
          postId: widget.snap['postId'],
          initialRatings: _localRatings,
        ),
      ),
    );
  }

  Widget _buildUserAvatar() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.snap['uid'])
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircleAvatar(
            radius: 21,
            backgroundColor: Color(0xFF333333),
          );
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final photoUrl = userData['photoUrl'] as String? ?? '';

        return GestureDetector(
          onTap: () => _navigateToProfile(),
          child: CircleAvatar(
            radius: 21,
            backgroundColor: const Color(0xFF333333),
            backgroundImage: photoUrl.isNotEmpty && photoUrl != "default"
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl.isEmpty || photoUrl == "default"
                ? Icon(Icons.account_circle, size: 42, color: Colors.grey[600])
                : null,
          ),
        );
      },
    );
  }

  Widget _buildMoreButton(model.AppUser user) {
    final isCurrentUserPost = widget.snap['uid'] == user.uid;

    return IconButton(
      icon: const Icon(Icons.more_vert, color: Color(0xFFd9d9d9)),
      onPressed: () =>
          isCurrentUserPost ? _showDeleteConfirmation() : _showReportDialog(),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Delete Post', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this post?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.network(
          widget.snap['postUrl'].toString(),
          fit: BoxFit.fitWidth,
          width: double.infinity,
        ),
        if (widget.snap['description']?.toString().isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Text(
              widget.snap['description'].toString(),
              style: const TextStyle(
                color: Color(0xFFd9d9d9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.comment_outlined, color: Color(0xFFd9d9d9)),
          onPressed: () => _navigateToComments(),
        ),
        if (_commentCount > 0)
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
                _commentCount.toString(),
                style: const TextStyle(
                  color: Color(0xFFd9d9d9),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(uid: widget.snap['uid']),
      ),
    );
  }

  void _navigateToComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(postId: widget.snap['postId']),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
