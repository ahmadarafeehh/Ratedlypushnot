import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Ratedly/utils/colors.dart';
import 'package:Ratedly/utils/global_variable.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Ratedly/providers/user_provider.dart';
import 'package:Ratedly/resources/notification_read.dart';

class MobileScreenLayout extends StatefulWidget {
  const MobileScreenLayout({Key? key}) : super(key: key);

  @override
  State<MobileScreenLayout> createState() => _MobileScreenLayoutState();
}

class _MobileScreenLayoutState extends State<MobileScreenLayout> {
  int _page = 0;
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void onPageChanged(int page) {
    setState(() {
      _page = page;
    });
  }

  void navigationTapped(int page) async {
    if (page == 2) {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user != null) {
        await NotificationService.markNotificationsAsRead(user.uid);
      }
    }
    pageController.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    if (user?.uid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentUserId = user!.uid;

    return Scaffold(
      body: PageView(
        controller: pageController,
        onPageChanged: onPageChanged,
        children: homeScreenItems,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom > 0 ? 12 : 0),
        child: Container(
          height: 60,
          color: mobileBackgroundColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCustomNavItem(Icons.home, 0),
              _buildCustomNavItem(Icons.search, 1),
              _buildCustomNotificationNavItem(currentUserId, 2),
              _buildCustomNavItem(Icons.person, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomNavItem(IconData icon, int index) {
    return InkWell(
      onTap: () => navigationTapped(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
          ),
          if (_page == index)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 12,
              color: Colors.white,
            ),
        ],
      ),
    );
  }

  Widget _buildCustomNotificationNavItem(String userId, int index) {
    return InkWell(
      onTap: () => navigationTapped(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          NotificationBadgeIcon(
            currentUserId: userId,
            currentPage: _page,
            pageIndex: index,
          ),
          if (_page == index)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 12,
              color: Colors.white,
            ),
        ],
      ),
    );
  }
}

class NotificationBadgeIcon extends StatelessWidget {
  final String currentUserId;
  final int currentPage;
  final int pageIndex;

  const NotificationBadgeIcon({
    Key? key,
    required this.currentUserId,
    required this.currentPage,
    required this.pageIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('targetUserId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.favorite,
              color: Colors.white,
            ),
            if (count > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
