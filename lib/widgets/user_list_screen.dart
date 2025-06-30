import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Ratedly/screens/Profile_page/profile_page.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import 'package:Ratedly/providers/user_provider.dart';
import 'package:Ratedly/resources/block_firestore_methods.dart';

class UserListScreen extends StatelessWidget {
  final String title;
  final List<dynamic> userEntries;
  final Color _textColor = const Color(0xFFd9d9d9);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF333333);
  final Color _iconColor = const Color(0xFFd9d9d9);

  const UserListScreen({
    Key? key,
    required this.title,
    required this.userEntries,
  }) : super(key: key);

  List<Map<String, dynamic>> _getValidEntries() {
    return userEntries
        .map((entry) {
          final userId = entry['userId'] ?? entry['raterUserId'];
          if (userId == null) return null;
          return {
            'userId': userId.toString(),
            'timestamp': entry['timestamp'] ?? Timestamp.now(),
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;
    final entries = _getValidEntries();

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(child: CircularProgressIndicator(color: _textColor)),
      );
    }
    if (entries.isEmpty) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: Text(title, style: TextStyle(color: _textColor)),
          backgroundColor: _backgroundColor,
          iconTheme: IconThemeData(color: _textColor),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_alt_outlined,
                  size: 40, color: _textColor.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                'No data available',
                style: TextStyle(
                  color: _textColor.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: _textColor)),
        backgroundColor: _backgroundColor,
        iconTheme: IconThemeData(color: _textColor),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId,
                whereIn: entries.map((e) => e['userId']).toList())
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: _textColor));
          }

          final users = snapshot.data!.docs;
          if (users.isEmpty) {
            return Center(
              child:
                  Text('No users found', style: TextStyle(color: _textColor)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (context, index) => Divider(color: _cardColor),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userId = users[index].id;
              final entry = entries.firstWhere(
                (e) => e['userId'] == userId,
                orElse: () => {'timestamp': Timestamp.now()},
              );

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: _cardColor),
                      title: Text('Loading...',
                          style: TextStyle(color: _textColor)),
                    );
                  }

                  return FutureBuilder<bool>(
                    future: FirestoreBlockMethods().isMutuallyBlocked(
                      currentUser.uid,
                      userId,
                    ),
                    builder: (context, blockSnapshot) {
                      final isBlocked = blockSnapshot.data ?? false;
                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>;
                      final timestamp =
                          (entry['timestamp'] as Timestamp).toDate();

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _cardColor,
                            radius: 21,
                            backgroundImage: isBlocked
                                ? null
                                : (userData['photoUrl'] != null &&
                                        userData['photoUrl'].isNotEmpty &&
                                        userData['photoUrl'] != "default")
                                    ? NetworkImage(userData['photoUrl'])
                                    : null,
                            child: (isBlocked ||
                                    userData['photoUrl'] == null ||
                                    userData['photoUrl'].isEmpty ||
                                    userData['photoUrl'] == "default")
                                ? Icon(
                                    Icons.account_circle,
                                    size: 42,
                                    color: _iconColor,
                                  )
                                : null,
                          ),
                          title: Text(
                            isBlocked
                                ? 'UserNotFound'
                                : userData['username'] ?? 'Anonymous',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                          subtitle: Text(
                            timeago.format(timestamp),
                            style:
                                TextStyle(color: _textColor.withOpacity(0.6)),
                          ),
                          onTap: isBlocked
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ProfileScreen(uid: userId),
                                    ),
                                  ),
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
}
