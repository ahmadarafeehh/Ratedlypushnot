import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: const Color(0xFF121212),
      ),
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'Privacy Notice for Ratedly Inc',
              content:
                  'This privacy notice for Ratedly Inc ("Company," "we," "us," or "our") describes how and why we process your information when you use our Services, such as when you download and use our mobile application, Ratedly. If you do not agree with our policies, please do not use our Services. For questions or concerns, please contact us at ratedly9@gmail.com.',
            ),
            _buildSection(
              title: 'TABLE OF CONTENTS',
              content: '1. WHAT INFORMATION DO WE COLLECT?\n'
                  '2. HOW DO WE PROCESS YOUR INFORMATION?\n'
                  '3. WHAT LEGAL BASES DO WE RELY ON TO PROCESS YOUR PERSONAL INFORMATION?\n'
                  '4. WHEN AND WITH WHOM DO WE SHARE YOUR PERSONAL INFORMATION?\n'
                  '5. HOW DO WE HANDLE YOUR SOCIAL LOGINS?\n'
                  '6. HOW LONG DO WE KEEP YOUR INFORMATION?\n'
                  '7. HOW DO WE KEEP YOUR INFORMATION SAFE?\n'
                  '8. WHAT ARE YOUR PRIVACY RIGHTS?\n'
                  '9. DO WE MAKE UPDATES TO THIS NOTICE?\n'
                  '10. HOW CAN YOU CONTACT US ABOUT THIS NOTICE?\n'
                  '11. HOW CAN YOU REVIEW, UPDATE, OR DELETE THE DATA WE COLLECT FROM YOU?',
            ),
            _buildSection(
              number: '1',
              title: 'WHAT INFORMATION DO WE COLLECT?',
              content: 'Personal Information Provided by You:\n'
                  '• User Account Data: Email, user ID (UID), username, profile photo, and bio.\n'
                  '• Personal Details: Region, age, and gender.\n\n'
                  'Social Data:\n'
                  '• Followers, following, follow requests, ratings, and messages.\n\n'
                  'Content Data:\n'
                  '• Information related to posts, including description, post ID, media URLs, publication date, region, age, gender, and ratings.\n\n'
                  'Note: Users can change their account settings to private and may delete their account at any time.',
            ),
            _buildSection(
              number: '2',
              title: 'HOW DO WE PROCESS YOUR INFORMATION?',
              content:
                  'We process your information to create and manage your account, personalize your experience, facilitate social interactions (such as following, messaging, and rating posts), and improve our Services. All processing is performed securely using a secure Cloud solution.',
            ),
            _buildSection(
              number: '3',
              title:
                  'WHAT LEGAL BASES DO WE RELY ON TO PROCESS YOUR PERSONAL INFORMATION?',
              content: 'We process your personal information based on:\n'
                  '• Consent: You provide your information during registration and through your interactions with our app.\n'
                  '• Legitimate Interests: To offer and improve our Services.\n'
                  '• Legal Obligations: To comply with applicable laws.',
            ),
            _buildSection(
              number: '4',
              title:
                  'WHEN AND WITH WHOM DO WE SHARE YOUR PERSONAL INFORMATION?',
              content:
                  'Currently we do not share your personal information with any third parties. Your data remains within our systems and is used solely for providing and improving our Services.',
            ),
            _buildSection(
              number: '5',
              title: 'HOW DO WE HANDLE YOUR SOCIAL LOGINS?',
              content:
                  'Currently Ratedly uses only email and password for account creation and login. We do not support or integrate with third-party social login providers.',
            ),
            _buildSection(
              number: '6',
              title: 'HOW LONG DO WE KEEP YOUR INFORMATION?',
              content:
                  'We retain your personal information only as long as necessary to fulfill the purposes outlined in this notice. Once your account is deleted or no longer active, all of your data will be securely removed, except where retention is required by law.',
            ),
            _buildSection(
              number: '7',
              title: 'HOW DO WE KEEP YOUR INFORMATION SAFE?',
              content:
                  'We implement appropriate technical and organizational security measures to protect your personal information from unauthorized access, alteration, or disclosure. While no method is 100% secure, we strive to maintain the confidentiality and integrity of your data.',
            ),
            _buildSection(
              number: '8',
              title: 'WHAT ARE YOUR PRIVACY RIGHTS?',
              content:
                  'Depending on your location, you may have rights to access, correct, or delete your personal information. You can manage your account settings at any time and may contact us to exercise your rights.',
            ),
            _buildSection(
              number: '9',
              title: 'DO WE MAKE UPDATES TO THIS NOTICE?',
              content:
                  'We may update this privacy notice periodically. Any changes will be effective immediately upon posting. We encourage you to review this notice regularly to stay informed about how we protect your information.',
            ),
            _buildSection(
              number: '10',
              title: 'HOW CAN YOU CONTACT US ABOUT THIS NOTICE?',
              content:
                  'If you have any questions or concerns about this privacy notice, please email us at ',
              extraContent: RichText(
                text: TextSpan(
                  text: 'ratedly9@gmail.com',
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      // Launch email client
                    },
                ),
              ),
            ),
            _buildSection(
              number: '11',
              title:
                  'HOW CAN YOU REVIEW, UPDATE, OR DELETE THE DATA WE COLLECT FROM YOU?',
              content:
                  'You may request access to, correction of, or deletion of your personal data by contacting our email address at ',
              extraContent: RichText(
                text: TextSpan(
                  text: 'ratedly9@gmail.com',
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      // Launch email client
                    },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    String? number,
    required String title,
    required String content,
    Widget? extraContent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (number != null) const SizedBox(height: 20),
        Text(
          number != null ? '$number. $title' : title,
          style: TextStyle(
            // Remove const here
            color: Colors.white,
            fontSize: number != null ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        if (extraContent != null) extraContent,
        const SizedBox(height: 20),
        const Divider(color: Colors.grey),
      ],
    );
  }
}
