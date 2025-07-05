import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:Ratedly/providers/user_provider.dart';
import 'package:Ratedly/screens/Profile_page/profile_page.dart';
import 'package:Ratedly/screens/post_view_screen.dart';
import 'package:Ratedly/utils/global_variable.dart';
import 'package:Ratedly/resources/profile_firestore_methods.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final userProvider = Provider.of<UserProvider>(context);

    if (userProvider.user == null) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFd9d9d9))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: width > webScreenSize
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF121212),
              toolbarHeight: 100,
              automaticallyImplyLeading: false,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              title: Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  'assets/logo/23.png',
                  width: 160,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
              iconTheme: const IconThemeData(color: Color(0xFFd9d9d9)),
            ),
      body: _NotificationList(currentUserId: userProvider.user!.uid),
    );
  }
}

class _NotificationList extends StatelessWidget {
  final String currentUserId;

  const _NotificationList({required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('targetUserId', isEqualTo: currentUserId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFd9d9d9)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                'No notifications yet. Follow, rate posts, and comment.',
                style: TextStyle(color: Color(0xFFd9d9d9), fontSize: 16),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final notification =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return _NotificationItem(
              notification: notification,
              currentUserId: currentUserId,
            );
          },
        );
      },
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final Map<String, dynamic> notification;
  final String currentUserId;

  const _NotificationItem({
    required this.notification,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    switch (notification['type']) {
      case 'comment':
        return _CommentNotification(notification: notification);
      case 'post_rating':
        return _PostRatingNotification(notification: notification);
      case 'follow_request':
        return _FollowRequestNotification(
          notification: notification,
          currentUserId: currentUserId,
        );
      case 'follow_request_accepted':
        return _FollowAcceptedNotification(notification: notification);
      case 'comment_like':
        return _CommentLikeNotification(notification: notification);
      case 'follow':
        return _FollowNotification(notification: notification);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _FollowNotification extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _FollowNotification({required this.notification});

  @override
  Widget build(BuildContext context) {
    // Uses followerUsername which is the requester's username
    return _NotificationTemplate(
      userId: notification['followerId'],
      title: '${notification['followerUsername']} started following you',
      timestamp: notification['timestamp'],
      onTap: () => _navigateToProfile(context, notification['followerId']),
    );
  }
}

class _CommentNotification extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _CommentNotification({required this.notification});

  @override
  Widget build(BuildContext context) {
    return _NotificationTemplate(
      userId: notification['commenterUid'],
      title: '${notification['commenterName']} commented on your post',
      subtitle: notification['commentText'],
      timestamp: notification['timestamp'],
      onTap: () => _navigateToPost(context, notification['postId']),
    );
  }
}

class _PostRatingNotification extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _PostRatingNotification({required this.notification});

  @override
  Widget build(BuildContext context) {
    final raterUserId = notification['raterUid'] as String? ?? '';
    final raterUsername = notification['raterUsername'] as String? ?? 'Someone';
    final rating = (notification['rating'] as num?)?.toDouble() ?? 0.0;
    final postId = notification['postId'] as String? ?? ''; // Add this line

    return _NotificationTemplate(
      userId: raterUserId,
      title: '$raterUsername rated your post',
      subtitle: 'Rating: ${rating.toStringAsFixed(1)}',
      timestamp: notification['timestamp'],
      // FIX: Navigate to post instead of profile
      onTap: () => _navigateToPost(context, postId),
    );
  }
}

// Replace the _FollowRequestNotification class with this
class _FollowRequestNotification extends StatelessWidget {
  final Map<String, dynamic> notification;
  final String currentUserId;

  const _FollowRequestNotification({
    required this.notification,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final provider =
        Provider.of<FireStoreProfileMethods>(context, listen: false);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(notification['requesterId'])
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final user = snapshot.data!.data() as Map<String, dynamic>;
        return _NotificationTemplate(
          userId: notification['requesterId'],
          title: '${user['username']} wants to follow you',
          timestamp: notification['timestamp'],
          actions: [
            TextButton(
              onPressed: () => provider.acceptFollowRequest(
                  currentUserId, notification['requesterId']),
              child: const Text('Accept',
                  style: TextStyle(color: Color(0xFFd9d9d9))),
            ),
            TextButton(
              onPressed: () => provider.declineFollowRequest(
                  currentUserId, notification['requesterId']),
              child: const Text('Decline',
                  style: TextStyle(color: Color(0xFFd9d9d9))),
            ),
          ],
        );
      },
    );
  }
}

class _FollowAcceptedNotification extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _FollowAcceptedNotification({required this.notification});

  @override
  Widget build(BuildContext context) {
    // Uses senderUsername which is the approver's username
    return _NotificationTemplate(
      userId: notification['senderId'],
      title:
          '${notification['senderUsername']} approved your follow request',
      timestamp: notification['timestamp'],
      onTap: () => _navigateToProfile(context, notification['senderId']),
    );
  }
}

class _CommentLikeNotification extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _CommentLikeNotification({required this.notification});

  @override
  Widget build(BuildContext context) {
    return _NotificationTemplate(
      userId: notification['likerUid'],
      title: '${notification['likerUsername']} liked your comment',
      subtitle: notification['commentText'],
      timestamp: notification['timestamp'],
      onTap: () => _navigateToPost(context, notification['postId']),
    );
  }
}

class _NotificationTemplate extends StatelessWidget {
  final String userId;
  final String title;
  final String? subtitle;
  final dynamic timestamp;
  final VoidCallback? onTap;
  final List<Widget>? actions;

  const _NotificationTemplate({
    required this.userId,
    required this.title,
    this.subtitle,
    required this.timestamp,
    this.onTap,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        // FIX: Make avatar tap navigate to profile
        leading: GestureDetector(
          onTap: () => _navigateToProfile(context, userId),
          child: _UserAvatar(userId: userId),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFFd9d9d9))),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle != null)
              Text(subtitle!, style: const TextStyle(color: Color(0xFF999999))),
            Text(_formatTimestamp(timestamp),
                style: const TextStyle(color: Color(0xFF999999))),
            if (actions != null) Row(children: actions!),
          ],
        ),
        onTap: onTap, // Maintain existing tap behavior for entire tile
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      return timeago.format((timestamp as Timestamp).toDate());
    } catch (e) {
      return 'Loading';
    }
  }
}

class _UserAvatar extends StatelessWidget {
  final String userId;

  const _UserAvatar({
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final user = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final profilePic = user['photoUrl']?.toString() ?? '';

        return CircleAvatar(
          radius: 21,
          backgroundColor: Colors.transparent,
          backgroundImage: (profilePic.isNotEmpty && profilePic != "default")
              ? NetworkImage(profilePic)
              : null,
          child: (profilePic.isEmpty || profilePic == "default")
              ? const Icon(
                  Icons.account_circle,
                  size: 42,
                  color: Color(0xFFd9d9d9),
                )
              : null,
        );
      },
    );
  }
}

void _navigateToProfile(BuildContext context, String uid) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => ProfileScreen(uid: uid)),
  );
}

void _navigateToPost(BuildContext context, String postId) async {
  final postSnapshot =
      await FirebaseFirestore.instance.collection('posts').doc(postId).get();

  if (postSnapshot.exists) {
    final postData = postSnapshot.data() as Map<String, dynamic>;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewScreen(
          imageUrl: postData['postUrl'],
          postId: postId,
          description: postData['description'],
          userId: postData['uid'],
          username: postData['username'],
          profImage: postData['profImage'],
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Post not found')));
  }
}
