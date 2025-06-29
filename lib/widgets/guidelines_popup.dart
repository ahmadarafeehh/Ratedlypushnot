import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuidelinesPopup extends StatefulWidget {
  final String userId; // Add user ID parameter
  final VoidCallback? onAgreed;
  const GuidelinesPopup({super.key, required this.userId, this.onAgreed});

  @override
  State<GuidelinesPopup> createState() => _GuidelinesPopupState();
}

class _GuidelinesPopupState extends State<GuidelinesPopup> {
  bool agreedAndDontShow = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF333333),
      title: Row(
        children: [
          const Icon(Icons.push_pin, color: Color(0xFFd9d9d9)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ratedly Rules',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFd9d9d9),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to Ratedly!\n'
              'Before you continue, please take a moment to read and agree to our community rules. '
              'These help keep Ratedly safe, respectful, and fun for everyone.\n',
              style: TextStyle(color: Color(0xFFd9d9d9)),
            ),
            const Text(
              '✅ What’s OK:',
              style: TextStyle(
                color: Color(0xFFd9d9d9),
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildBullet(
                'Rate photos based on style, creativity, and visual appeal — not the person in the photo.'),
            _buildBullet(
                'Leave comments that are helpful, kind, or constructive.'),
            _buildBullet(
                'Use Ratedly to share your artistic side, get feedback, and discover great visual content.'),
            const SizedBox(height: 16),
            const Text(
              '🚫 What’s Not OK:',
              style: TextStyle(
                color: Color(0xFFd9d9d9),
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildBullet('Don\'t post mean, offensive, or personal comments.',
                isNegative: true),
            _buildBullet(
                'Don\'t use the app to judge or rate people — we only rate images, not individuals.',
                isNegative: true),
            _buildBullet(
                'Harassment, bullying, or inappropriate content is not allowed and may result in removal.',
                isNegative: true),
            const SizedBox(height: 20),
            // Single combined checkbox
            Row(
              children: [
                Checkbox(
                  value: agreedAndDontShow,
                  onChanged: (value) =>
                      setState(() => agreedAndDontShow = value ?? false),
                  checkColor: const Color(0xFFd9d9d9),
                  fillColor: MaterialStateProperty.resolveWith<Color>(
                    (Set<MaterialState> states) {
                      if (states.contains(MaterialState.selected)) {
                        return const Color(0xFF4CAF50); // Green when checked
                      }
                      return const Color(0xFF555555);
                    },
                  ),
                ),
                const Expanded(
                  child: Text('I agree and don\'t show again',
                      style: TextStyle(color: Color(0xFFd9d9d9))),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: agreedAndDontShow
              ? () async {
                  final prefs = await SharedPreferences.getInstance();

                  // Save both preferences with user ID
                  await prefs.setBool(
                      'agreed_to_guidelines_${widget.userId}', true);
                  await prefs.setBool('dont_show_again_${widget.userId}', true);

                  if (context.mounted) Navigator.of(context).pop();
                  widget.onAgreed?.call();
                }
              : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

Widget _buildBullet(String text, {bool isNegative = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isNegative ? '❌ ' : '✔️ ',
            style: const TextStyle(color: Color(0xFFd9d9d9))),
        Expanded(
          child: Text(text, style: const TextStyle(color: Color(0xFFd9d9d9))),
        ),
      ],
    ),
  );
}
