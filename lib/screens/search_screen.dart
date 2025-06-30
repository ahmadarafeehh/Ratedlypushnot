import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:helloworld/screens/Profile_page/profile_page.dart';
import 'package:helloworld/screens/post_view_screen.dart';
import 'package:helloworld/resources/block_firestore_methods.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();
  bool isShowUsers = false;
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final FirestoreBlockMethods _blockMethods = FirestoreBlockMethods();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Form(
          child: TextFormField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Search for a user...',
              labelStyle: TextStyle(color: Color(0xFFd9d9d9)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF333333)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFd9d9d9), width: 2.0),
              ),
            ),
            style: const TextStyle(color: Color(0xFFd9d9d9)),
            onFieldSubmitted: (String _) {
              setState(() {
                isShowUsers = true;
              });
            },
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFd9d9d9)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFd9d9d9)));
          }

          final blockedUsers = List<String>.from(
              userSnapshot.data?.data()?['blockedUsers'] ?? []);

          return isShowUsers
              ? FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .where('username',
                          isGreaterThanOrEqualTo: searchController.text)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFd9d9d9)));
                    }

                    if (snapshot.hasError) {
                      return Center(
                          child: Text('Error: ${snapshot.error}',
                              style:
                                  const TextStyle(color: Color(0xFFd9d9d9))));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                          child: Text('No users found.',
                              style: TextStyle(color: Color(0xFFd9d9d9))));
                    }

                    return FutureBuilder<List<QueryDocumentSnapshot>>(
                      future: _filterUsers(snapshot.data!.docs, blockedUsers),
                      builder: (context, filteredSnapshot) {
                        if (filteredSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFFd9d9d9)));
                        }

                        final users = filteredSnapshot.data ?? [];

                        return ListView.builder(
                          padding: const EdgeInsets.only(top: 8),
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user =
                                users[index].data() as Map<String, dynamic>? ??
                                    {};

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProfileScreen(
                                        uid: user['uid']?.toString() ?? ''),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(
                                    bottom: 8, left: 8, right: 8),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF333333),
                                    backgroundImage:
                                        ((user['photoUrl'] as String?) !=
                                                    null &&
                                                (user['photoUrl'] as String)
                                                    .isNotEmpty &&
                                                (user['photoUrl'] as String) !=
                                                    "default")
                                            ? NetworkImage(user['photoUrl']!)
                                            : null,
                                    radius: 20,
                                    child: (user['photoUrl'] == null ||
                                            (user['photoUrl'] as String)
                                                .isEmpty ||
                                            (user['photoUrl'] as String) ==
                                                "default")
                                        ? const Icon(
                                            Icons.account_circle,
                                            size: 40,
                                            color: Color(0xFFd9d9d9),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    user['username']?.toString() ?? 'Unknown',
                                    style: const TextStyle(
                                      color: Color(0xFFd9d9d9),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                )
              : FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance.collection('posts').get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFd9d9d9)));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                          child: Text('No posts found.',
                              style: TextStyle(color: Color(0xFFd9d9d9))));
                    }

                    return FutureBuilder<List<QueryDocumentSnapshot>>(
                      future: _filterPosts(snapshot.data!.docs, blockedUsers),
                      builder: (context, filteredSnapshot) {
                        if (filteredSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFFd9d9d9)));
                        }

                        final filteredPosts = filteredSnapshot.data ?? [];

                        if (filteredPosts.isEmpty) {
                          return const Center(
                              child: Text('No posts found.',
                                  style: TextStyle(color: Color(0xFFd9d9d9))));
                        }

                        filteredPosts.sort((a, b) {
                          final postA = a.data() as Map<String, dynamic>? ?? {};
                          final postB = b.data() as Map<String, dynamic>? ?? {};

                          final ratingsA =
                              postA['rate'] as List<dynamic>? ?? [];
                          final ratingsB =
                              postB['rate'] as List<dynamic>? ?? [];

                          double avgA = ratingsA.isNotEmpty
                              ? ratingsA.fold(
                                      0.0,
                                      (acc, r) =>
                                          acc +
                                          ((r as Map)['rating'] as num)
                                              .toDouble()) /
                                  ratingsA.length
                              : 0.0;
                          double avgB = ratingsB.isNotEmpty
                              ? ratingsB.fold(
                                      0.0,
                                      (acc, r) =>
                                          acc +
                                          ((r as Map)['rating'] as num)
                                              .toDouble()) /
                                  ratingsB.length
                              : 0.0;

                          int result = avgB.compareTo(avgA);
                          if (result == 0) {
                            result = ratingsB.length.compareTo(ratingsA.length);
                          }
                          return result;
                        });

                        return GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1,
                            crossAxisSpacing: 8.0,
                            mainAxisSpacing: 8.0,
                          ),
                          itemCount: filteredPosts.length,
                          itemBuilder: (context, index) {
                            final post = filteredPosts[index].data()
                                    as Map<String, dynamic>? ??
                                {};
                            final postUrl = post['postUrl']?.toString();

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ImageViewScreen(
                                      imageUrl: postUrl ?? '',
                                      postId: filteredPosts[index].id,
                                      description:
                                          post['description']?.toString() ?? '',
                                      userId: post['uid']?.toString() ?? '',
                                      username:
                                          post['username']?.toString() ?? '',
                                      profImage:
                                          post['profImage']?.toString() ??
                                              post['photoUrl']?.toString() ??
                                              '',
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF333333),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: postUrl != null && postUrl.isNotEmpty
                                    ? Image.network(
                                        postUrl,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                              color: const Color(0xFFd9d9d9),
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: const Color(0xFF333333),
                                            child: const Icon(Icons.error,
                                                color: Colors.red),
                                          );
                                        },
                                      )
                                    : const Icon(Icons.broken_image,
                                        color: Color(0xFFd9d9d9)),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
        },
      ),
    );
  }

  Future<List<QueryDocumentSnapshot>> _filterUsers(
      List<QueryDocumentSnapshot> users, List<String> blockedUsers) async {
    final List<QueryDocumentSnapshot> filtered = [];

    for (final userDoc in users) {
      final userId = userDoc.id;
      final isBlockedByThem = await _blockMethods.isUserBlocked(
        currentUserId: currentUserId,
        targetUserId: userId,
      );

      if (!blockedUsers.contains(userId) && !isBlockedByThem) {
        filtered.add(userDoc);
      }
    }

    return filtered;
  }

  Future<List<QueryDocumentSnapshot>> _filterPosts(
      List<QueryDocumentSnapshot> posts, List<String> blockedUsers) async {
    final List<QueryDocumentSnapshot> filtered = [];

    Set<String> postUserIds = {};
    for (final postDoc in posts) {
      final postData = postDoc.data() as Map<String, dynamic>? ?? {};
      final postUserId = postData['uid']?.toString() ?? '';
      if (postUserId.isNotEmpty) {
        postUserIds.add(postUserId);
      }
    }

    if (postUserIds.isNotEmpty) {
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: postUserIds.toList())
          .get();

      final Map<String, bool> userPrivacyMap = {};
      for (final userDoc in usersQuery.docs) {
        userPrivacyMap[userDoc.id] = userDoc['isPrivate'] ?? false;
      }

      for (final postDoc in posts) {
        final postData = postDoc.data() as Map<String, dynamic>? ?? {};
        final postUserId = postData['uid']?.toString() ?? '';

        if (userPrivacyMap[postUserId] ?? false) {
          continue;
        }

        final isBlockedByThem = await _blockMethods.isUserBlocked(
          currentUserId: currentUserId,
          targetUserId: postUserId,
        );

        if (!blockedUsers.contains(postUserId) &&
            !isBlockedByThem &&
            postUserId != currentUserId) {
          filtered.add(postDoc);
        }
      }
    }

    return filtered;
  }
}
