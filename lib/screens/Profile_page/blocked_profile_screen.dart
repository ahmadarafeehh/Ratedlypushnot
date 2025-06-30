import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:helloworld/utils/utils.dart';
import 'package:helloworld/resources/block_firestore_methods.dart';
import 'package:helloworld/screens/Profile_page/profile_page.dart';

class BlockedProfileScreen extends StatefulWidget {
  final String uid;
  final bool isBlocker;

  const BlockedProfileScreen({
    Key? key,
    required this.uid,
    required this.isBlocker,
  }) : super(key: key);

  @override
  State<BlockedProfileScreen> createState() => _BlockedProfileScreenState();
}

class _BlockedProfileScreenState extends State<BlockedProfileScreen> {
  final FirestoreBlockMethods _blockMethods = FirestoreBlockMethods();
  bool _isLoading = true;
  Map<String, dynamic> userData = {};
  bool _isBlocker = false;
  bool _isBlockedByThem = false;
  int postLen = 0;
  int followers = 0;
  int following = 0;

  @override
  void initState() {
    super.initState();
    _isBlocker = widget.isBlocker;
    _loadBlockedProfileData();
  }

  Future<void> _loadBlockedProfileData() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    try {
      final isBlocker = await FirestoreBlockMethods().isBlockInitiator(
        currentUserId: currentUserId,
        targetUserId: widget.uid,
      );

      final isBlockedByThem = await FirestoreBlockMethods().isUserBlocked(
        currentUserId: currentUserId,
        targetUserId: widget.uid,
      );

      setState(() {
        _isBlocker = isBlocker;
        _isBlockedByThem = isBlockedByThem;
      });

      if (!_isBlockedByThem) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .get();

        if (userDoc.exists) {
          QuerySnapshot postsSnap = await FirebaseFirestore.instance
              .collection('posts')
              .where('uid', isEqualTo: widget.uid)
              .get();

          setState(() {
            userData = userDoc.data() as Map<String, dynamic>;
            postLen = postsSnap.docs.length;
            followers = (userData['followers'] ?? []).length;
            following = (userData['following'] ?? []).length;
          });
        }
      }
    } catch (e) {
      showSnackBar(context, "Error loading profile: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _unblockUser() async {
    try {
      await _blockMethods.unblockUser(
        currentUserId: FirebaseAuth.instance.currentUser!.uid,
        targetUserId: widget.uid,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(uid: widget.uid),
        ),
      );
      showSnackBar(context, "User unblocked");
    } catch (e) {
      showSnackBar(context, "Unblock error: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFd9d9d9))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Profile',
            style: TextStyle(color: Color(0xFFd9d9d9))),
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Color(0xFFd9d9d9)),
      ),
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 20),
              _buildBlockedContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Stack(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: const Color(0xFF333333),
              backgroundImage: !_isBlockedByThem &&
                      userData['photoUrl'] != null &&
                      userData['photoUrl'].isNotEmpty &&
                      userData['photoUrl'] != "default"
                  ? NetworkImage(userData['photoUrl'])
                  : null,
              child: _isBlockedByThem
                  ? Icon(
                      Icons.block,
                      size: 42,
                      color: Colors.red[400],
                    )
                  : (userData['photoUrl'] == null ||
                          userData['photoUrl'].isEmpty ||
                          userData['photoUrl'] == "default"
                      ? const Icon(
                          Icons.account_circle,
                          size: 42,
                          color: Color(0xFFd9d9d9),
                        )
                      : null),
            ),
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMetric(_isBlockedByThem ? 0 : postLen, "Rate",
                          const Color(0xFFd9d9d9)),
                      _buildMetric(_isBlockedByThem ? 0 : followers, "Voters",
                          const Color(0xFFd9d9d9)),
                      _buildMetric(_isBlockedByThem ? 0 : following,
                          "Followers", const Color(0xFFd9d9d9)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBlockedContent() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.block, size: 60, color: Color(0xFFd9d9d9)),
          const SizedBox(height: 16),
          Text(
            _isBlocker
                ? "You've blocked this account"
                : "This account has blocked you",
            style: const TextStyle(fontSize: 18, color: Color(0xFFd9d9d9)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_isBlocker)
            ElevatedButton(
              onPressed: _unblockUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF444444),
                foregroundColor: const Color(0xFFd9d9d9),
              ),
              child: const Text("Unblock Account"),
            ),
        ],
      ),
    );
  }

  Widget _buildMetric(int value, String label, Color textColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
