import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Ratedly/utils/colors.dart';
import 'package:Ratedly/utils/global_variable.dart';
import 'package:Ratedly/screens/feed/post_card.dart';
import 'package:Ratedly/widgets/feedmessages.dart';
import 'package:Ratedly/widgets/guidelines_popup.dart';
import 'package:Ratedly/resources/messages_firestore_methods.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  int _selectedTab = 0;
  late ScrollController _followingScrollController;
  late ScrollController _forYouScrollController;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _followingPosts = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _forYouPosts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastFollowingDocument;
  DocumentSnapshot? _lastForYouDocument;
  bool _hasMoreFollowing = true;
  bool _hasMoreForYou = true;
  Timer? _guidelinesTimer;
  bool _isPopupShown = false;

  @override
  void initState() {
    super.initState();
    _followingScrollController = ScrollController()..addListener(_onScroll);
    _forYouScrollController = ScrollController()..addListener(_onScroll);
    _loadInitialData();
    _startGuidelinesTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowGuidelines();
    });
  }

  void _startGuidelinesTimer() {
    _guidelinesTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isPopupShown) {
        _checkAndShowGuidelines();
      }
    });
  }

  void _checkAndShowGuidelines() async {
    final prefs = await SharedPreferences.getInstance();
    final bool agreed =
        prefs.getBool('agreed_to_guidelines_$currentUserId') ?? false;
    final bool dontShow =
        prefs.getBool('dont_show_again_$currentUserId') ?? false;

    // Show popup ONLY if both conditions aren't met together
    if (!(agreed && dontShow)) {
      _showGuidelinesPopup();
    } else {
      _guidelinesTimer?.cancel(); // Stop timer if both are pressed
    }
  }

  void _showGuidelinesPopup() {
    if (!mounted) {
      return;
    }

    setState(() => _isPopupShown = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GuidelinesPopup(
        userId: currentUserId, // Pass user ID to popup
        onAgreed: () {},
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isPopupShown = false);
      }
    });
  }

  void _onScroll() {
    final currentController = _selectedTab == 0
        ? _followingScrollController
        : _forYouScrollController;

    if (currentController.position.pixels >=
            currentController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        ((_selectedTab == 0 && _hasMoreFollowing) ||
            (_selectedTab == 1 && _hasMoreForYou))) {
      _loadData(loadMore: true);
    }
  }

  Future<void> _loadInitialData() async {
    await _loadData();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData({bool loadMore = false}) async {
    if ((_selectedTab == 0 && !_hasMoreFollowing && loadMore) ||
        (_selectedTab == 1 && !_hasMoreForYou && loadMore) ||
        _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      final userData = userSnapshot.data()!;
      final blockedUsers = List<String>.from(userData['blockedUsers'] ?? []);
      final following = List<dynamic>.from(userData['following'] ?? []);

      List<QueryDocumentSnapshot<Map<String, dynamic>>> newPosts = [];
      QuerySnapshot<Map<String, dynamic>>? snapshot;

      if (_selectedTab == 0) {
        final followingIds = following
            .whereType<Map<String, dynamic>>()
            .map((entry) => entry['userId'] as String)
            .toList();

        if (followingIds.isEmpty) {
          if (mounted) {
            setState(() {
              _hasMoreFollowing = false;
              _isLoadingMore = false;
            });
          }
          return;
        }

        Query<Map<String, dynamic>> query = FirebaseFirestore.instance
            .collection('posts')
            .where('uid', whereIn: followingIds)
            .orderBy(FieldPath.documentId)
            .limit(5);

        if (loadMore && _lastFollowingDocument != null) {
          query = query.startAfterDocument(_lastFollowingDocument!);
        }

        snapshot = await query.get();
        _lastFollowingDocument =
            snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMoreFollowing = snapshot.docs.length == 5;
        newPosts = snapshot.docs;
      } else {
        Query<Map<String, dynamic>> query = FirebaseFirestore.instance
            .collection('posts')
            .orderBy(FieldPath.documentId)
            .limit(5);

        if (loadMore && _lastForYouDocument != null) {
          query = query.startAfterDocument(_lastForYouDocument!);
        }

        snapshot = await query.get();
        _lastForYouDocument =
            snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMoreForYou = snapshot.docs.length == 5;

        newPosts = snapshot.docs
            .where((post) =>
                post['uid'] != currentUserId &&
                !following.any((entry) =>
                    entry is Map<String, dynamic> &&
                    entry['userId'] == post['uid']))
            .toList();
      }

      Set<String> postUserIds =
          newPosts.map((post) => post.data()['uid'] as String).toSet();

      if (postUserIds.isNotEmpty) {
        final usersQuery = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: postUserIds.toList())
            .get();

        final Map<String, bool> userPrivacyMap = {};
        for (final userDoc in usersQuery.docs) {
          userPrivacyMap[userDoc.id] = userDoc['isPrivate'] ?? false;
        }

        newPosts = newPosts.where((post) {
          final postUserId = post.data()['uid'] as String;
          return !(userPrivacyMap[postUserId] ?? false);
        }).toList();
      }

      // Filter blocked users
      newPosts = newPosts
          .where((post) => !blockedUsers.contains(post.data()['uid']))
          .toList();

      // Calculate scores and sort only for "For You" feed
      if (_selectedTab == 1) {
        newPosts.sort((a, b) {
          final double scoreA = _calculateAdjustedScore(a);
          final double scoreB = _calculateAdjustedScore(b);
          return scoreB.compareTo(scoreA);
        });
      }

      if (mounted) {
        setState(() {
          if (_selectedTab == 0) {
            _followingPosts =
                loadMore ? [..._followingPosts, ...newPosts] : newPosts;
          } else {
            _forYouPosts = loadMore ? [..._forYouPosts, ...newPosts] : newPosts;
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  double _calculateAdjustedScore(
      QueryDocumentSnapshot<Map<String, dynamic>> post) {
    final List<dynamic> ratings = post.data()['rate'] ?? [];
    final int numVoters = ratings.length;
    final double avgRating = _calculateAverageRating(ratings);
    return avgRating + (numVoters * 0.1);
  }

  double _calculateAverageRating(List<dynamic> ratings) {
    if (ratings.isEmpty) return 0.0;
    return ratings.fold<double>(0.0, (sum, r) {
          final rating = (r is Map<String, dynamic>)
              ? (r['rating'] as num).toDouble() // Convert to double
              : 0.0;
          return sum + rating;
        }) /
        ratings.length;
  }

  @override
  void dispose() {
    _followingScrollController.dispose();
    _forYouScrollController.dispose();
    _guidelinesTimer?.cancel(); // Cancel timer when screen is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // In FeedScreen's build method
    return Scaffold(
      backgroundColor: mobileBackgroundColor, // Always use dark background
      appBar: _buildAppBar(width),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildFeedBody(width),
    );
  }

  Widget _buildTab(String text, int index) {
    return GestureDetector(
      onTap: () {
        final isSameTab = _selectedTab == index;

        if (isSameTab) {
          // Clear data and reset pagination for current tab
          if (index == 0) {
            _followingPosts.clear();
            _lastFollowingDocument = null;
            _hasMoreFollowing = true;
          } else {
            _forYouPosts.clear();
            _lastForYouDocument = null;
            _hasMoreForYou = true;
          }
        }

        setState(() {
          _selectedTab = index;
          _isLoading = true;
        });

        _loadData().then((_) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _selectedTab == index ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  AppBar? _buildAppBar(double width) {
    return width > webScreenSize
        ? null
        : AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            backgroundColor: mobileBackgroundColor,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTab('Following', 0),
                const SizedBox(width: 20),
                _buildTab('For You', 1),
              ],
            ),
            centerTitle: true,
            actions: [_buildMessageButton()],
          );
  }

  Widget _buildMessageButton() {
    return StreamBuilder<int>(
      stream: FireStoreMessagesMethods().getTotalUnreadCount(currentUserId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              onPressed: () => _navigateToMessages(),
              icon: const Icon(Icons.message),
            ),
            if (count > 0) _buildUnreadCountBadge(count),
          ],
        );
      },
    );
  }

  void _navigateToMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeedMessages(currentUserId: currentUserId),
      ),
    );
  }

  Widget _buildUnreadCountBadge(int count) {
    return Positioned(
      right: 8,
      top: 8,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFeedBody(double width) {
    return Column(
      children: [
        Expanded(
          child: _selectedTab == 0
              ? _buildFollowingFeed(width)
              : _buildForYouFeed(width),
        ),
      ],
    );
  }

  Widget _buildFollowingFeed(double width) {
    return _followingPosts.isEmpty && !_isLoading
        ? _buildEmptyFollowingMessage(width)
        : _buildPostsListView(
            _followingPosts, width, _followingScrollController, 0);
  }

  Widget _buildForYouFeed(double width) {
    return _buildPostsListView(_forYouPosts, width, _forYouScrollController, 1);
  }

  Widget _buildEmptyFollowingMessage(double width) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_add, size: 64, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 20),
            Text(
              'Your Following Feed is Empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Follow interesting users to see their posts here!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsListView(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> posts,
    double width,
    ScrollController controller,
    int tabIndex,
  ) {
    return ListView.builder(
      controller: controller,
      key: PageStorageKey('feedListView$tabIndex'),
      itemCount: posts.length +
          ((_isLoadingMore ||
                  (tabIndex == 0 && _hasMoreFollowing) ||
                  (tabIndex == 1 && _hasMoreForYou))
              ? 1
              : 0),
      itemBuilder: (ctx, index) {
        if (index >= posts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        // In _buildPostsListView method
        return Container(
          color: mobileBackgroundColor, // Always use dark background
          margin: EdgeInsets.symmetric(
            horizontal: width > webScreenSize ? width * 0.3 : 0,
            vertical: width > webScreenSize ? 15 : 0,
          ),
          child: PostCard(
            snap: posts[index].data(),
          ),
        );
      },
    );
  }
}
