import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Ratedly/utils/utils.dart';
import 'package:Ratedly/widgets/edit_profile_screen.dart';
import 'package:Ratedly/screens/post_view_screen.dart';
import 'package:Ratedly/screens/Profile_page/add_post_screen.dart';
import 'package:Ratedly/widgets/settings_screen.dart';
import 'package:Ratedly/widgets/user_list_screen.dart';

class CurrentUserProfileScreen extends StatefulWidget {
  final String uid;
  const CurrentUserProfileScreen({Key? key, required this.uid})
      : super(key: key);

  @override
  State<CurrentUserProfileScreen> createState() =>
      _CurrentUserProfileScreenState();
}

class _CurrentUserProfileScreenState extends State<CurrentUserProfileScreen> {
  var userData = {};
  int followers = 0;
  int following = 0;
  List<dynamic> _followersList = [];
  List<dynamic> _followingList = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    getData();
  }

  Future<void> getData() async {
    setState(() => isLoading = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;

        final followersConverted = _convertToList(data['followers'])
            .where((f) => f['userId'] != null)
            .toList();

        final followingConverted = _convertToList(data['following'])
            .where((f) => f['userId'] != null)
            .toList();

        setState(() {
          userData = data;
          followers = followersConverted.length;
          following = followingConverted.length;
          _followersList = followersConverted;
          _followingList = followingConverted;
        });
      }
    } catch (e) {
      showSnackBar(context, "Error loading profile: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<dynamic> _convertToList(dynamic value) {
    if (value is List) return value;
    if (value is Map) return value.keys.map((k) => value[k]).toList();
    return [];
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFFd9d9d9)),
            onPressed: _navigateToSettings,
          )
        ],
      ),
      backgroundColor: const Color(0xFF121212),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFd9d9d9)))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 20),
                    Column(
                      children: [
                        _buildBioSection(),
                        const Divider(color: Color(0xFF333333)),
                        _buildPostsGrid(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        SizedBox(
          height: 80,
          child: Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF333333),
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
                      size: 80,
                      color: Color(0xFFd9d9d9),
                    )
                  : null,
            ),
          ),
        ),
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInteractiveMetric(
                      followers, "Followers", _followersList),
                  _buildInteractiveMetric(
                      following, "Following", _followingList),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Center(
              child: _buildEditProfileButton(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInteractiveMetric(
      int value, String label, List<dynamic> userList) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserListScreen(
            title: label,
            userEntries: userList,
          ),
        ),
      ),
      child: _buildMetric(value, label,
          const Color(0xFFd9d9d9) // Ensure text color matches dark theme
          ),
    );
  }

  // Change the existing _buildEditProfileButton() to:
  Widget _buildEditProfileButton() {
    return ElevatedButton(
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
        );

        if (result != null && mounted) {
          // Update local state with new data
          setState(() {
            userData['bio'] = result['bio'] ?? userData['bio'];
            userData['photoUrl'] = result['photoUrl'] ?? userData['photoUrl'];
          });

          // Force refresh Firestore data
          await getData();
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF444444),
        foregroundColor: const Color(0xFFd9d9d9),
      ),
      child: const Text("Edit Profile"),
    );
  }

  Future<void> _forceRefresh() async {
    await getData();
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildMetric(int value, String label, Color textColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor // Now using theme color
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: textColor // Now using theme color
              ),
        ),
      ],
    );
  }

  Widget _buildBioSection() {
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
          Text(
            userData['bio'] ?? '',
            style: const TextStyle(color: Color(0xFFd9d9d9)),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsGrid() {
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
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 5,
              mainAxisSpacing: 1.5,
              childAspectRatio: 1),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildAddPostButton();
            }
            final postIndex = index - 1;
            if (postIndex < 0 || postIndex >= posts.length) return Container();
            final post = posts[postIndex];
            return _buildPostItem(post);
          },
        );
      },
    );
  }

  Widget _buildAddPostButton() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddPostScreen(
            onPostUploaded: _forceRefresh, // Pass the callback
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF333333),
        ),
        child: const Icon(
          Icons.add_circle_outline,
          size: 40,
          color: Color(0xFFd9d9d9),
        ),
      ),
    );
  }

  Widget _buildPostItem(DocumentSnapshot post) {
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
            onPostDeleted: _forceRefresh, // Pass the refresh callback
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
  }
}
