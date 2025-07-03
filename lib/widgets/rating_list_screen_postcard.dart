import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:Ratedly/screens/Profile_page/profile_page.dart';
import 'package:Ratedly/resources/block_firestore_methods.dart';
import 'package:Ratedly/providers/user_provider.dart';

class RatingListScreen extends StatelessWidget {
  final String postId;
  final List<dynamic> initialRatings;
  final Color _textColor = const Color(0xFFd9d9d9);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF333333);
  final Color _iconColor = const Color(0xFFd9d9d9);

  const RatingListScreen({
    super.key,
    required this.postId,
    required this.initialRatings,
  });

  Widget _buildRatingItem(dynamic rating, BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;
    final userId = rating['userId'] as String;
    final userRating = (rating['rating'] as num?)?.toDouble() ?? 0.0;

    // Handle different timestamp types
    final dynamic tsValue = rating['timestamp'];
    String timeText;

    if (tsValue == null) {
      timeText = 'Just now';
    } else if (tsValue is Timestamp) {
      timeText = timeago.format(tsValue.toDate());
    } else if (tsValue is FieldValue) {
      timeText = 'Just now'; // Placeholder for unresolved server timestamp
    } else {
      timeText = 'Unknown time';
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          // Show placeholder with rating and default avatar while user loads
          return Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _cardColor,
                radius: 21,
                child: Icon(
                  Icons.account_circle,
                  size: 42,
                  color: _textColor.withOpacity(0.8),
                ),
              ),
              title: Text('Loading...', style: TextStyle(color: _textColor)),
              subtitle: Text(timeText,
                  style: TextStyle(color: _textColor.withOpacity(0.6))),
              trailing: Chip(
                label: Text(
                  userRating.toStringAsFixed(1),
                  style: TextStyle(color: _textColor),
                ),
                backgroundColor: _cardColor,
              ),
            ),
          );
        }

        final Map<String, dynamic>? userData =
            userSnapshot.data!.data() as Map<String, dynamic>?;

        return FutureBuilder<bool>(
          future: FirestoreBlockMethods().isMutuallyBlocked(
            currentUser!.uid,
            userId,
          ),
          builder: (context, blockSnapshot) {
            final isBlocked = blockSnapshot.data ?? false;

            final photoUrl = userData?['photoUrl'] as String? ?? '';
            final username = userData?['username'] as String? ?? 'Unknown user';

            return Container(
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _cardColor,
                  radius: 21,
                  backgroundImage: isBlocked
                      ? null
                      : (photoUrl.isNotEmpty && photoUrl != 'default')
                          ? NetworkImage(photoUrl)
                          : null,
                  child:
                      (isBlocked || photoUrl.isEmpty || photoUrl == 'default')
                          ? Icon(
                              Icons.account_circle,
                              size: 42,
                              color: _iconColor,
                            )
                          : null,
                ),
                title: Text(
                  isBlocked ? 'UserNotFound' : username,
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: _textColor),
                ),
                subtitle: Text(
                  timeText,
                  style: TextStyle(color: _textColor.withOpacity(0.6)),
                ),
                trailing: Chip(
                  label: Text(
                    userRating.toStringAsFixed(1),
                    style: TextStyle(color: _textColor),
                  ),
                  backgroundColor: _cardColor,
                ),
                onTap: isBlocked
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(uid: userId),
                          ),
                        ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: _textColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Ratings', style: TextStyle(color: _textColor)),
        backgroundColor: _backgroundColor,
        iconTheme: IconThemeData(color: _textColor),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: initialRatings.length,
              itemBuilder: (context, index) =>
                  _buildRatingItem(initialRatings[index], context),
            );
          }

          final Map<String, dynamic>? postData =
              snapshot.data!.data() as Map<String, dynamic>?;
          final ratings = postData?['rate'] as List<dynamic>? ?? [];

          if (ratings.isEmpty) {
            return Center(
              child:
                  Text('No ratings yet', style: TextStyle(color: _textColor)),
            );
          }

          ratings.sort((a, b) {
            final ta = a['timestamp'] as Timestamp?;
            final tb = b['timestamp'] as Timestamp?;
            return tb?.compareTo(ta ?? Timestamp(0, 0)) ?? 0;
          });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ratings.length,
            separatorBuilder: (context, index) => Divider(color: _cardColor),
            itemBuilder: (context, index) =>
                _buildRatingItem(ratings[index], context),
          );
        },
      ),
    );
  }
}
