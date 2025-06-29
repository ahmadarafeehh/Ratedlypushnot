import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Ratedly/screens/post_view_screen.dart';
import 'package:Ratedly/utils/colors.dart';
import 'package:Ratedly/widgets/user_list_screen.dart';

class ProfileCommon {
  static List<dynamic> convertToList(dynamic value) {
    if (value is List) return value;
    if (value is Map) return value.keys.map((k) => value[k]).toList();
    return [];
  }

  static Widget buildMetric(int value, String label, Color textColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: textColor,
          ),
        ),
      ],
    );
  }

  static Widget buildInteractiveMetric(
    BuildContext context,
    int value,
    String label,
    List<dynamic> userList,
  ) {
    final validEntries = userList.where((entry) {
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
      child: buildMetric(validEntries.length, label, Colors.black),
    );
  }

  static Widget buildBioSection(Map<String, dynamic> userData) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            userData['username'] ?? '',
            style: const TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userData['bio'] ?? '',
            style: const TextStyle(color: primaryColor),
          ),
        ],
      ),
    );
  }

  static Widget buildPostsGrid(
      BuildContext context, String uid, bool showAddButton) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: uid)
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
          itemCount: showAddButton ? posts.length + 1 : posts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 5,
            mainAxisSpacing: 1.5,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            if (showAddButton && index == 0) {
              return _buildAddPostButton(context);
            }
            final postIndex = showAddButton ? index - 1 : index;
            if (postIndex < 0 || postIndex >= posts.length) return Container();
            return _buildPostItem(posts[postIndex], context);
          },
        );
      },
    );
  }

  static Widget _buildAddPostButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/add-post'),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        child:
            const Icon(Icons.add_circle_outline, size: 40, color: Colors.black),
      ),
    );
  }

  static Widget _buildPostItem(DocumentSnapshot post, BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewScreen(
            imageUrl: post['postUrl'],
            postId: post['postId'],
            description: post['description'],
            userId: post['uid'],
            username: post['username'] ?? '',
            profImage: post['photoUrl'] ?? '',
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
