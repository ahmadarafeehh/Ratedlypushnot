import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:Ratedly/resources/storage_methods.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _bioController = TextEditingController();
  Uint8List? _image;
  bool _isLoading = false;
  String? _initialPhotoUrl;
  String? _currentPhotoUrl;
  final Color _textColor = const Color(0xFFd9d9d9);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      DocumentSnapshot userSnap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      setState(() {
        _bioController.text = userSnap['bio'] ?? '';
        _initialPhotoUrl = userSnap['photoUrl'];
        _currentPhotoUrl = _initialPhotoUrl ?? 'default';
      });
    } catch (e) {
      if (mounted) {
        // Add mounted check
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user data: $e')),
        );
      }
    }
    if (mounted) {
      // Add mounted check
      setState(() => _isLoading = false);
    }
  }

  void _showEditOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor, // Match card color
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentPhotoUrl != 'default' || _image != null)
                ListTile(
                  leading: Icon(Icons.delete, color: _textColor),
                  title: Text('Remove Picture',
                      style: TextStyle(color: _textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    _removePhoto();
                  },
                ),
              ListTile(
                leading: Icon(Icons.photo_library, color: _textColor),
                title: Text('Choose from Gallery',
                    style: TextStyle(color: _textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      Uint8List imageData = await pickedFile.readAsBytes();
      setState(() {
        _image = imageData;
        _currentPhotoUrl = null; // New image selected, override removal
      });
    }
  }

  void _removePhoto() {
    setState(() {
      _image = null;
      _currentPhotoUrl = 'default'; // Mark for removal on save
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      Map<String, dynamic> updatedData = {'bio': _bioController.text};

      if (_image != null) {
        // Upload new image and delete old one if exists
        String photoUrl = await StorageMethods().uploadImageToStorage(
          'profilePics',
          _image!,
          false,
        );
        updatedData['photoUrl'] = photoUrl;

        // Delete old image after successful upload
        if (_initialPhotoUrl != null && _initialPhotoUrl != 'default') {
          await StorageMethods().deleteImage(_initialPhotoUrl!);
        }
      } else if (_currentPhotoUrl == 'default') {
        // Handle profile picture removal: Set Firestore to "default"
        if (_initialPhotoUrl != null && _initialPhotoUrl != 'default') {
          await StorageMethods().deleteImage(_initialPhotoUrl!);
        }
        updatedData['photoUrl'] = 'default'; // Set to "default" string
      }

      // Clear bio if empty
      if (_bioController.text.isEmpty) {
        updatedData['bio'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updatedData);

      // Update local state to reflect changes
      setState(() {
        _initialPhotoUrl =
            updatedData['photoUrl'] ?? 'default'; // Ensure fallback
        _currentPhotoUrl = _initialPhotoUrl;
        _image = null;
      });

      if (mounted) {
        // Return updated data to previous screen
        Navigator.pop(context, {
          'bio': _bioController.text,
          'photoUrl': updatedData['photoUrl'] ?? _initialPhotoUrl
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        iconTheme: IconThemeData(color: _textColor),
        title: Text(
          'Edit Profile',
          style: TextStyle(color: _textColor),
        ),
        centerTitle: true,
        backgroundColor: _backgroundColor,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _textColor))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _showEditOptions,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: _cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _textColor,
                          width: 2.0,
                        ),
                      ),
                      child: Stack(
                        children: [
                          ClipOval(
                            child: _image != null
                                ? Image.memory(
                                    _image!,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  )
                                : (_currentPhotoUrl != null &&
                                        _currentPhotoUrl != 'default')
                                    ? Image.network(
                                        _currentPhotoUrl!,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Center(
                                          child: Icon(
                                            Icons.account_circle,
                                            size: 120,
                                            color: _textColor,
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Icon(
                                          Icons.account_circle,
                                          size: 60,
                                          color: _textColor,
                                        ),
                                      ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _backgroundColor,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.edit,
                                size: 14,
                                color: _textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _bioController,
                    decoration: InputDecoration(
                      labelText: 'Bio',
                      labelStyle: TextStyle(color: _textColor),
                      hintText: 'Write something about yourself...',
                      hintStyle: TextStyle(color: _textColor.withOpacity(0.7)),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: _textColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _textColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _textColor),
                      ),
                      filled: true,
                      fillColor: _cardColor,
                    ),
                    style: TextStyle(color: _textColor),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cardColor,
                      foregroundColor: _textColor,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
    );
  }
}
