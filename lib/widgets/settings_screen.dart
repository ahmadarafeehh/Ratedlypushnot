import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:helloworld/resources/auth_methods.dart';
import 'package:helloworld/resources/profile_firestore_methods.dart';
import 'package:helloworld/screens/login.dart';
import 'package:helloworld/screens/Profile_page/blocked_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  bool _isPrivate = false;
  final Color _textColor = const Color(0xFFd9d9d9);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF333333);
  final Color _iconColor = const Color(0xFFd9d9d9);

  @override
  void initState() {
    super.initState();
    _loadPrivacyStatus();
  }

  Future<void> _loadPrivacyStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();
    if (mounted) {
      setState(() => _isPrivate = doc['isPrivate'] ?? false);
    }
  }

  Future<void> _togglePrivacy(bool value) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({'isPrivate': value});

      if (!value) {
        await FireStoreProfileMethods().approveAllFollowRequests(currentUserId);
      }

      if (mounted) {
        setState(() => _isPrivate = value);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating privacy: $e')),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    TextEditingController currentPasswordController = TextEditingController();
    TextEditingController newPasswordController = TextEditingController();
    TextEditingController confirmPasswordController = TextEditingController();

    bool? confirmed = await showDialog(
      context: context,
      builder: (context) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: _cardColor,
              title: Text(
                'Change Password',
                style: TextStyle(color: _textColor, fontFamily: 'Inter'),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red[400], fontSize: 12),
                    ),
                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    style: TextStyle(color: _textColor),
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: TextStyle(color: _textColor.withOpacity(0.7)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: _textColor.withOpacity(0.5)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: _textColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    style: TextStyle(color: _textColor),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: TextStyle(color: _textColor.withOpacity(0.7)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: _textColor.withOpacity(0.5)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: _textColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    style: TextStyle(color: _textColor),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      labelStyle: TextStyle(color: _textColor.withOpacity(0.7)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: _textColor.withOpacity(0.5)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: _textColor),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel', style: TextStyle(color: _textColor)),
                ),
                TextButton(
                  onPressed: () {
                    if (newPasswordController.text !=
                        confirmPasswordController.text) {
                      setState(
                          () => errorMessage = 'New passwords do not match');
                      return;
                    }
                    if (newPasswordController.text.isEmpty) {
                      setState(
                          () => errorMessage = 'New password cannot be empty');
                      return;
                    }
                    if (currentPasswordController.text.isEmpty) {
                      setState(
                          () => errorMessage = 'Current password is required');
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: _backgroundColor,
                  ),
                  child: Text('Change Password',
                      style: TextStyle(color: _textColor)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPasswordController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      await user.updatePassword(newPasswordController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error changing password: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    await AuthMethods().signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _deleteAccount() async {
    bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          'Delete Account',
          style: TextStyle(color: _textColor, fontFamily: 'Inter'),
        ),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: TextStyle(color: _textColor.withOpacity(0.9)),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: _backgroundColor,
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: _textColor)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red[900],
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red[100])),
          ),
        ],
      ),
    );

    if (!confirmed || !mounted) return;

    TextEditingController passwordController = TextEditingController();
    bool? confirmedPassword = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          'Confirm Password',
          style: TextStyle(color: _textColor, fontFamily: 'Inter'),
        ),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          style: TextStyle(color: _textColor),
          decoration: InputDecoration(
            labelText: 'Enter your password to confirm deletion',
            labelStyle: TextStyle(color: _textColor.withOpacity(0.7)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _textColor.withOpacity(0.5)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _textColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: _backgroundColor,
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: _textColor)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red[900],
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Confirm', style: TextStyle(color: Colors.red[100])),
          ),
        ],
      ),
    );

    if (confirmedPassword != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String uid = user!.uid;
      String email = user.email!;

      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: passwordController.text.trim(),
      );

      String res = await FireStoreProfileMethods()
          .deleteEntireUserAccount(uid, credential);

      if (res == "success" && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $res')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: $e')),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildOptionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? _iconColor),
        title: Text(title, style: TextStyle(color: _textColor)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: _textColor)),
        centerTitle: true,
        backgroundColor: _backgroundColor,
        elevation: 1,
        iconTheme: IconThemeData(color: _textColor),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _textColor))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildOptionTile(
                    title: 'Private Account',
                    icon: Icons.lock,
                    onTap: () {},
                    trailing: Switch(
                      value: _isPrivate,
                      onChanged: _togglePrivacy,
                      activeColor: _textColor,
                    ),
                  ),
                  _buildOptionTile(
                    title: 'Blocked Users',
                    icon: Icons.block,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BlockedUsersList(
                          uid: FirebaseAuth.instance.currentUser!.uid,
                        ),
                      ),
                    ),
                  ),
                  _buildOptionTile(
                    title: 'Change Password',
                    icon: Icons.lock,
                    onTap: _changePassword,
                  ),
                  _buildOptionTile(
                    title: 'Sign Out',
                    icon: Icons.logout,
                    onTap: _signOut,
                  ),
                  _buildOptionTile(
                    title: 'Delete Account',
                    icon: Icons.delete,
                    iconColor: Colors.red[400],
                    onTap: _deleteAccount,
                  ),
                ],
              ),
            ),
    );
  }
}

class BlockedUsersList extends StatefulWidget {
  final String uid;
  const BlockedUsersList({Key? key, required this.uid}) : super(key: key);

  @override
  State<BlockedUsersList> createState() => _BlockedUsersListState();
}

class _BlockedUsersListState extends State<BlockedUsersList> {
  final Color _textColor = const Color(0xFFd9d9d9);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Blocked Users', style: TextStyle(color: _textColor)),
        backgroundColor: _backgroundColor,
        iconTheme: IconThemeData(color: _textColor),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _textColor));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child:
                  Text('No blocked users', style: TextStyle(color: _textColor)),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final blockedUsers = List<String>.from(data['blockedUsers'] ?? []);

          if (blockedUsers.isEmpty) {
            return Center(
              child:
                  Text('No blocked users', style: TextStyle(color: _textColor)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: blockedUsers.length,
            separatorBuilder: (context, index) =>
                Divider(color: _cardColor, height: 20),
            itemBuilder: (context, index) {
              final blockedUserId = blockedUsers[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(blockedUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;
                  final username = userData?['username'] ?? 'Unknown User';
                  final photoUrl = userData?['photoUrl'] ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _cardColor,
                      backgroundImage: (userData?['photoUrl'] != null &&
                              userData?['photoUrl'].isNotEmpty &&
                              userData?['photoUrl'] != "default")
                          ? NetworkImage(userData!['photoUrl'])
                          : null,
                      radius: 22,
                      child: (userData?['photoUrl'] == null ||
                              userData?['photoUrl'].isEmpty ||
                              userData?['photoUrl'] == "default")
                          ? Icon(
                              Icons.person,
                              color: _textColor,
                              size: 36,
                            )
                          : null,
                    ),
                    title: Text(
                      username,
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(Icons.lock_outline, color: _textColor),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BlockedProfileScreen(
                            uid: blockedUserId,
                            isBlocker: true,
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
