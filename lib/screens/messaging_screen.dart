import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:Ratedly/resources/block_firestore_methods.dart';
import 'package:Ratedly/resources/messages_firestore_methods.dart';
import 'package:Ratedly/screens/post_view_screen.dart';
import 'package:Ratedly/screens/Profile_page/profile_page.dart';

class MessagingScreen extends StatefulWidget {
  final String recipientUid;
  final String recipientUsername;
  final String recipientPhotoUrl;

  const MessagingScreen({
    Key? key,
    required this.recipientUid,
    required this.recipientUsername,
    required this.recipientPhotoUrl,
  }) : super(key: key);

  @override
  _MessagingScreenState createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _controller = TextEditingController();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final FirestoreBlockMethods _blockMethods = FirestoreBlockMethods();
  bool _isLoading = false;
  String? chatId;
  bool _isMutuallyBlocked = false;
  bool _hasInitialScroll = false;
  final ScrollController _scrollController = ScrollController();

  final Color _textColor = const Color(0xFFd9d9d9);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF333333);
  final Color _iconColor = const Color(0xFFd9d9d9);

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() async {
    try {
      // First check mutual block status
      _isMutuallyBlocked = await _blockMethods.isMutuallyBlocked(
        currentUserId,
        widget.recipientUid,
      );

      if (_isMutuallyBlocked) {
        if (mounted) setState(() {});
        return;
      }

      final id = await FireStoreMessagesMethods().getOrCreateChat(
        currentUserId,
        widget.recipientUid,
      );

      if (mounted) {
        setState(() => chatId = id);
        FireStoreMessagesMethods().markMessagesAsRead(id, currentUserId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing chat: $e')),
        );
      }
    }
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty || _isLoading || _isMutuallyBlocked) return;

    setState(() => _isLoading = true);

    try {
      final chatId = await FireStoreMessagesMethods().getOrCreateChat(
        currentUserId,
        widget.recipientUid,
      );

      final res = await FireStoreMessagesMethods().sendMessage(
        chatId,
        currentUserId,
        widget.recipientUid,
        _controller.text,
      );

      if (res == 'success') {
        _controller.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && mounted) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildBlockedUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, size: 60, color: _iconColor),
          const SizedBox(height: 20),
          Text(
            'Messages with ${widget.recipientUsername} are unavailable',
            style: TextStyle(color: _textColor, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cardColor,
              foregroundColor: _textColor,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Messages'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        iconTheme: IconThemeData(color: _textColor),
        backgroundColor: _backgroundColor,
        title: _buildAppBarTitle(),
        elevation: 0,
      ),
      body: _isMutuallyBlocked ? _buildBlockedUI() : _buildChatBody(),
    );
  }

  Widget _buildAppBarTitle() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(uid: widget.recipientUid),
        ),
      ),
      child: Row(
        children: [
          _buildUserAvatar(widget.recipientPhotoUrl),
          const SizedBox(width: 10),
          Text(
            widget.recipientUsername,
            style: TextStyle(color: _textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String photoUrl) {
    return CircleAvatar(
      radius: 21,
      backgroundColor: _cardColor,
      backgroundImage: (widget.recipientPhotoUrl.isNotEmpty &&
              widget.recipientPhotoUrl != "default")
          ? NetworkImage(widget.recipientPhotoUrl)
          : null,
      child: (widget.recipientPhotoUrl.isEmpty ||
              widget.recipientPhotoUrl == "default")
          ? Icon(
              Icons.account_circle,
              size: 42,
              color: _iconColor,
            )
          : null,
    );
  }

  Widget _buildChatBody() {
    return Column(
      children: [
        Expanded(child: _buildMessageList()),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageList() {
    if (chatId == null)
      return Center(child: CircularProgressIndicator(color: _textColor));

    return StreamBuilder<QuerySnapshot>(
      stream: FireStoreMessagesMethods().getMessages(chatId!),
      builder: (context, snapshot) {
        if (snapshot.hasData && !_hasInitialScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              // Wait for layout to complete
              Future.delayed(const Duration(milliseconds: 50), () {
                if (mounted &&
                    _scrollController.position.maxScrollExtent > 0 &&
                    !_hasInitialScroll) {
                  _scrollController.jumpTo(
                    _scrollController.position.maxScrollExtent,
                  );
                  setState(() => _hasInitialScroll = true);
                }
              });
            }
          });
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No messages yet.'));
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: false,
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final message = snapshot.data!.docs[index];
            return _buildMessageBubble(message);
          },
        );
      },
    );
  }

  @override
  void didUpdateWidget(MessagingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipientUid != widget.recipientUid) {
      _hasInitialScroll = false;
    }
  }

  Widget _buildMessageBubble(DocumentSnapshot message) {
    final data = message.data() as Map<String, dynamic>?;
    if (data == null) return const SizedBox();

    final isMe = data['senderId'] == currentUserId;
    final isPost = data['type'] == 'post';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? _cardColor : const Color(0xFF404040),
          borderRadius: BorderRadius.circular(12),
        ),
        child: isPost ? _buildPostMessage(data) : _buildTextMessage(data),
      ),
    );
  }

  Widget _buildTextMessage(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(data['message'], style: TextStyle(color: _textColor)),
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(data['timestamp']),
            style: TextStyle(color: _textColor.withOpacity(0.6), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildPostMessage(Map<String, dynamic> data) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('posts')
          .doc(data['postId'])
          .get(),
      builder: (context, postSnapshot) {
        if (!postSnapshot.hasData || !postSnapshot.data!.exists) {
          return const BlockedContentMessage(message: 'Post unavailable');
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(data['postOwnerId'])
              .get(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const BlockedContentMessage(message: 'User not found');
            }

            return FutureBuilder<bool>(
              future: _blockMethods.isMutuallyBlocked(
                currentUserId,
                data['postOwnerId'] ?? '',
              ),
              builder: (context, blockSnapshot) {
                if (blockSnapshot.data ?? false) {
                  return const BlockedContentMessage();
                }

                return GestureDetector(
                  onTap: () => _navigateToPost(data),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: _cardColor,
                              backgroundImage: (data['postOwnerPhotoUrl'] !=
                                          null &&
                                      data['postOwnerPhotoUrl'].isNotEmpty &&
                                      data['postOwnerPhotoUrl'] != "default" &&
                                      data['postOwnerPhotoUrl']
                                          .startsWith('http'))
                                  ? NetworkImage(data['postOwnerPhotoUrl']!)
                                  : null,
                              child: (data['postOwnerPhotoUrl'] == null ||
                                      data['postOwnerPhotoUrl'].isEmpty ||
                                      data['postOwnerPhotoUrl'] == "default" ||
                                      !data['postOwnerPhotoUrl']
                                          .startsWith('http'))
                                  ? Icon(
                                      Icons.account_circle,
                                      size: 32,
                                      color: _iconColor,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              data['postOwnerUsername'] ?? 'Unknown User',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _textColor),
                            ),
                          ],
                        ),
                      ),
                      Image.network(
                        data['postImageUrl'],
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 150,
                          color: Colors.grey,
                          child: const Center(child: Icon(Icons.error)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['postCaption'],
                                style: TextStyle(color: _textColor)),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(data['timestamp']),
                              style: TextStyle(
                                  color: _textColor.withOpacity(0.6),
                                  fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _navigateToPost(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewScreen(
          imageUrl: data['postImageUrl'],
          postId: data['postId'],
          description: data['postCaption'],
          userId: data['postOwnerId'],
          username: data['postOwnerUsername'] ?? 'Unknown',
          profImage: data['postOwnerPhotoUrl'] ?? '',
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isMutuallyBlocked,
              style: TextStyle(color: _textColor),
              decoration: InputDecoration(
                hintText: _isMutuallyBlocked
                    ? 'Messaging is blocked'
                    : 'Type a message...',
                hintStyle: TextStyle(color: _textColor.withOpacity(0.6)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: _cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),
          IconButton(
            icon: _isLoading
                ? CircularProgressIndicator(color: _textColor)
                : Icon(Icons.send, color: _iconColor),
            onPressed: _isMutuallyBlocked ? null : _sendMessage,
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Sending...';
    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class BlockedContentMessage extends StatelessWidget {
  final String message;

  const BlockedContentMessage(
      {super.key,
      this.message = 'This content is unavailable due to blocking'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.block, color: Colors.red[400], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: const Color(0xFFd9d9d9).withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
