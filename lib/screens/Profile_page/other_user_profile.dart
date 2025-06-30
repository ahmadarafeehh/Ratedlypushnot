import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:helloworld/resources/profile_firestore_methods.dart';
import 'package:helloworld/utils/utils.dart';
import 'package:helloworld/screens/post_view_screen.dart';
import 'package:helloworld/screens/messaging_screen.dart';
import 'package:helloworld/screens/Profile_page/blocked_profile_screen.dart';
import 'package:helloworld/widgets/user_list_screen.dart';
import 'package:helloworld/resources/block_firestore_methods.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String uid;
  const OtherUserProfileScreen({Key? key, required this.uid}) : super(key: key);

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  var userData = {};
  int postLen = 0;
  int followers = 0;
  bool isFollowing = false;
  bool isLoading = false;
  bool _isBlockedByMe = false;
  bool _isBlocked = false;
  bool _isBlockedByThem = false;
  bool _isViewerFollower = false;
  bool hasPendingRequest = false;
  List<dynamic> _followersList = [];
  int following = 0;

  final List<String> profileReportReasons = [
    'Impersonation (Pretending to be someone else)',
    'Fake Account (Misleading or suspicious profile)',
    'Bullying or Harassment',
    'Hate Speech or Discrimination (e.g., race, religion, gender, sexual orientation)',
    'Scam or Fraud (Deceptive activity, phishing, or financial fraud)',
    'Spam (Unwanted promotions or repetitive content)',
    'Inappropriate Content (Explicit, offensive, or disturbing profile)',
  ];

  @override
  void initState() {
    super.initState();
    _otherGetData();
    _checkBlockStatus();
  }

  // In OtherUserProfileScreen's _checkBlockStatus
  Future<void> _checkBlockStatus() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    final isBlockedByMe = await FirestoreBlockMethods().isBlockInitiator(
      currentUserId: currentUserId,
      targetUserId: widget.uid,
    );

    final isBlockedByThem = await FirestoreBlockMethods().isUserBlocked(
      currentUserId: currentUserId,
      targetUserId: widget.uid,
    );

    if (mounted) {
      setState(() {
        _isBlockedByMe = isBlockedByMe;
        _isBlockedByThem = isBlockedByThem;
        _isBlocked = isBlockedByMe || isBlockedByThem;
      });
    }

    if (_isBlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BlockedProfileScreen(
                uid: widget.uid,
                isBlocker:
                    _isBlockedByMe, // True only if current user initiated block
              ),
            ),
          );
        }
      });
    }
  }

  Future<void> _otherGetData() async {
    setState(() => isLoading = true);
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      // Setup real-time listener for user updates
      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(widget.uid);
      userDocRef.snapshots().listen((snapshot) {
        if (snapshot.exists && mounted) {
          final updatedData = snapshot.data()!;
          setState(() {
            // Update follow request status
            final updatedRequests =
                _otherConvertToList(updatedData['followRequests']);
            hasPendingRequest =
                updatedRequests.any((req) => req['userId'] == currentUserId);

            // Update following status from followers
            final updatedFollowers =
                _otherConvertToList(updatedData['followers']);
            isFollowing =
                updatedFollowers.any((f) => f['userId'] == currentUserId);

            // Update other metrics
            userData = updatedData;
            followers = updatedFollowers.length;
            _followersList = updatedFollowers;
            userData['isPrivate'] = updatedData['isPrivate'] ?? false;
          });
        }
      });
      // Check blocking status in both directions
      final isBlockedByMe = await FirestoreBlockMethods().isBlockInitiator(
        currentUserId: currentUserId,
        targetUserId: widget.uid,
      );

      final isBlockedByThem = await FirestoreBlockMethods().isUserBlocked(
        currentUserId: currentUserId,
        targetUserId: widget.uid,
      );

      if (isBlockedByMe || isBlockedByThem) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BlockedProfileScreen(
                uid: widget.uid,
                isBlocker: isBlockedByMe,
              ),
            ),
          );
        }
        return;
      }
      // Proceed with loading profile data if not blocked
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        showSnackBar(context, "User profile not found");
        return;
      }

      final data = userDoc.data()!;
      final isPrivate = data['isPrivate'] ?? false;

      final followRequests = _otherConvertToList(data['followRequests']);
      final posts = await FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: widget.uid)
          .get();

      // Process followers and following with null safety
      final followersList = _otherConvertToList(data['followers'])
          .where((f) => f['userId'] != null)
          .toList();

      final followingList = _otherConvertToList(data['following'])
          .where((f) => f['userId'] != null)
          .toList();

      // Update state with fresh data
      if (mounted) {
        setState(() {
          userData = data;
          postLen = posts.docs.length;
          followers = followersList.length;
          following = followingList.length;
          _followersList = followersList;
          hasPendingRequest =
              followRequests.any((req) => req['userId'] == currentUserId);
          userData['isPrivate'] = isPrivate;
          isFollowing = followersList.any((f) => f['userId'] == currentUserId);
        });
      }
      await _checkIfViewerIsFollower();
    } on FirebaseException catch (e) {
      showSnackBar(context, "Database error: ${e.message}");
    } catch (e) {
      showSnackBar(context, "Unexpected error: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _checkIfViewerIsFollower() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();

    final followers = (currentUserDoc.data()?['followers'] as List?) ?? [];
    if (mounted) {
      setState(() {
        _isViewerFollower = followers.any((f) => f['userId'] == widget.uid);
      });
    }
  }

  List<dynamic> _otherConvertToList(dynamic value) {
    if (value is List) return value;
    if (value is Map) return value.keys.map((k) => value[k]).toList();
    return [];
  }

  void _otherHandleFollow() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final targetUserId = widget.uid;
      final isPrivate = userData['isPrivate'] ?? false;

      if (isFollowing) {
        // Handle unfollow for both public and private accounts
        await FireStoreProfileMethods()
            .unfollowUser(currentUserId, targetUserId);
        if (mounted) {
          setState(() {
            isFollowing = false;
          });
        }
      } else if (hasPendingRequest) {
        // Cancel pending request for private accounts
        await FireStoreProfileMethods().declineFollowRequest(
          targetUserId,
          currentUserId,
        );
        if (mounted) {
          setState(() {
            hasPendingRequest = false;
          });
        }
      } else {
        // Send new follow request or follow publicly
        await FireStoreProfileMethods().followUser(
          currentUserId,
          targetUserId,
        );
        // Immediately update UI state for private accounts
        if (isPrivate) {
          setState(() {
            hasPendingRequest = true;
          });
        } else {
          setState(() {
            isFollowing = true;
          });
        }
      }

      // State updates handled through real-time listener
    } catch (e) {
      showSnackBar(context, "Error: ${e.toString()}");
    }
  }

  void _otherNavigateToMessaging() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get();
    if (mounted) {
      // Added mounted check

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MessagingScreen(
            recipientUid: widget.uid,
            recipientUsername: userDoc['username'],
            recipientPhotoUrl: userDoc['photoUrl'],
          ),
        ),
      );
    }
  }

  void _showProfileReportDialog() {
    String? selectedReason;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Report Profile'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thank you for helping keep our community safe.\n\nPlease let us know the reason for reporting this content. Your report is anonymous, and our moderators will review it as soon as possible. \n\n If you prefer not to see this user posts or content, you can choose to block them.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select a reason:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...profileReportReasons.map((reason) {
                      return RadioListTile<String>(
                        title: Text(reason),
                        value: reason,
                        groupValue: selectedReason,
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
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: selectedReason != null
                      ? () => _submitProfileReport(selectedReason!)
                      : null,
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitProfileReport(String reason) async {
    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'userId': widget.uid,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'profile', // Differentiate from post reports
      });

      if (mounted) {
        Navigator.pop(context);
        showSnackBar(context, 'Report submitted. Thank you!');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to submit report: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          iconTheme: const IconThemeData(color: Color(0xFFd9d9d9)),
          backgroundColor: const Color(0xFF121212),
          elevation: 0,
          title: Text(
            userData['username'] ?? 'Loading...',
            style: const TextStyle(
                color: Color(0xFFd9d9d9), fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          leading: const BackButton(color: Color(0xFFd9d9d9)),
          actions: [
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: Color(0xFFd9d9d9)),
              onSelected: (value) async {
                if (value == 'block') {
                  try {
                    setState(() => isLoading = true);
                    final currentUserId =
                        FirebaseAuth.instance.currentUser!.uid;

                    await FirestoreBlockMethods().blockUser(
                      currentUserId: currentUserId,
                      targetUserId: widget.uid,
                    );

                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BlockedProfileScreen(
                            uid: widget.uid,
                            isBlocker: true,
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      showSnackBar(context, "Block failed: ${e.toString()}");
                    }
                  } finally {
                    if (mounted) setState(() => isLoading = false);
                  }
                } else if (value == 'remove_follower') {
                  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
                  try {
                    await FireStoreProfileMethods()
                        .removeFollower(currentUserId, widget.uid);
                    if (mounted) {
                      setState(() {
                        _isViewerFollower = false;
                        followers = followers - 1;
                      });

                      showSnackBar(context, "Follower removed successfully");
                    }
                  } catch (e) {
                    showSnackBar(
                        context, "Error removing follower: ${e.toString()}");
                  }
                } else if (value == 'report') {
                  _showProfileReportDialog();
                }
              },
              itemBuilder: (context) => [
                if (_isViewerFollower)
                  const PopupMenuItem(
                    value: 'remove_follower',
                    child: Text('Remove Follower'),
                  ),
                if (FirebaseAuth.instance.currentUser?.uid != widget.uid)
                  const PopupMenuItem(
                    value: 'report',
                    child: Text('Report Profile'),
                  ),
                const PopupMenuItem(
                  value: 'block',
                  child: Text('Block User'),
                ),
              ],
            )
          ]),
      backgroundColor: const Color(0xFF121212),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFd9d9d9)))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildOtherProfileHeader(),
                    const SizedBox(height: 20),
                    _buildOtherBioSection(),
                    const Divider(color: Color(0xFF333333)),
                    _buildOtherPostsGrid()
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOtherProfileHeader() {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFF333333),
          radius: 45,
          backgroundImage: (userData['photoUrl'] != null &&
                  userData['photoUrl'].isNotEmpty &&
                  userData['photoUrl'] != "default")
              ? NetworkImage(userData['photoUrl'])
              : null,
          child: (userData['photoUrl'] == null ||
                  userData['photoUrl'].isEmpty ||
                  userData['photoUrl'] == "default")
              ? const Icon(
                  Icons.account_circle,
                  size: 90,
                  color: Color(0xFFd9d9d9),
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildOtherMetric(postLen, "Posts"),
                        _buildOtherInteractiveMetric(
                            followers, "Followers", _followersList),
                        _buildOtherMetric(following, "Following"),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildOtherInteractionButtons(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtherInteractiveMetric(
      int value, String label, List<dynamic> userList) {
    List<dynamic> validEntries = userList.where((entry) {
      return entry['userId'] != null && entry['userId'].toString().isNotEmpty;
    }).toList();

    return GestureDetector(
      onTap: validEntries.isEmpty
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserListScreen(
                    title: label,
                    userEntries: validEntries,
                  ),
                ),
              ),
      child: _buildOtherMetric(validEntries.length, label),
    );
  }

  Widget _buildOtherInteractionButtons() {
    final bool isCurrentUser =
        FirebaseAuth.instance.currentUser?.uid == widget.uid;
    final bool isPrivateAccount = userData['isPrivate'] ?? false;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isCurrentUser) _buildFollowButton(isPrivateAccount),
            const SizedBox(width: 5),
            if (!isCurrentUser)
              ElevatedButton(
                onPressed: _otherNavigateToMessaging,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF333333),
                  foregroundColor: const Color(0xFFd9d9d9),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  minimumSize: const Size(100, 40),
                ),
                child: const Text("Message"),
              ),
          ],
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  Widget _buildFollowButton(bool isPrivateAccount) {
    final isPending = hasPendingRequest && isPrivateAccount;

    return ElevatedButton(
      onPressed: _otherHandleFollow,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF333333),
        foregroundColor: const Color(0xFFd9d9d9),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        side: const BorderSide(
          color: Color(0xFF333333),
        ),
        minimumSize: const Size(100, 40),
      ),
      child: Text(
        isFollowing
            ? 'Unfollow'
            : isPending
                ? 'Requested'
                : 'Follow',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildOtherMetric(int value, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 13.6,
            fontWeight: FontWeight.bold,
            color: Color(0xFFd9d9d9),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Color(0xFFd9d9d9),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherBioSection() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            userData['username'] ?? '',
            style: const TextStyle(
                color: Color(0xFFd9d9d9),
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(userData['bio'] ?? '',
              style: const TextStyle(color: Color(0xFFd9d9d9))),
        ],
      ),
    );
  }

  // Add this widget in the _OtherUserProfileScreenState class
  Widget _buildPrivateAccountMessage() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock, size: 60, color: Colors.grey),
        SizedBox(height: 20),
        Text('This Account is Private',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Text('Follow to see their posts', style: TextStyle(fontSize: 14)),
      ],
    );
  }

// Update the _buildOtherPostsGrid method
  Widget _buildOtherPostsGrid() {
    final bool isCurrentUser =
        FirebaseAuth.instance.currentUser?.uid == widget.uid;
    final bool isPrivate = userData['isPrivate'] ?? false;
    final bool shouldHidePosts = isPrivate && !isFollowing && !isCurrentUser;
    final bool isMutuallyBlocked = _isBlockedByMe || _isBlockedByThem;

    if (isMutuallyBlocked) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 50, color: Colors.red),
            SizedBox(height: 10),
            Text('Posts unavailable due to blocking',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (shouldHidePosts) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.3,
        child: _buildPrivateAccountMessage(),
      );
    }

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: widget.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Failed to load posts'));
        }
        final posts = snapshot.data!.docs;

        // Add empty state message
        if (posts.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text(
                'This user has no posts.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 5,
            mainAxisSpacing: 1.5,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildOtherPostItem(post);
          },
        );
      },
    );
  }

  Widget _buildOtherPostItem(DocumentSnapshot post) {
    return FutureBuilder<bool>(
      future: FirestoreBlockMethods().isMutuallyBlocked(
        FirebaseAuth.instance.currentUser!.uid,
        post['uid'],
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!) {
          return const BlockedContentMessage(
            message: 'Post unavailable due to blocking',
          );
        }

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageViewScreen(
                imageUrl: post['postUrl'],
                postId: post['postId'],
                description: post['description'],
                userId: post['uid'],
                username: userData['username'] ?? '',
                profImage: userData['photoUrl'] ?? '',
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(post['postUrl']),
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }
}
