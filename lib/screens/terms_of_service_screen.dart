import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:Ratedly/screens/privacy_policy_screen.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        backgroundColor: const Color(0xFF121212),
      ),
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'Terms of Service',
              content: 'Last Updated: [Date]\n\n'
                  'Welcome to Ratedly (“we,” “us,” or “our”). These Terms of Service (“Terms”) govern your access to and use of our social media rating application (the “App”), which allows users to rate posts and profiles on a scale of 1 to 10. By accessing or using the App, you agree to be bound by these Terms. If you do not agree to these Terms, please do not use the App.',
            ),
            _buildSection(
              number: '1',
              title: 'Definitions',
              content: 'For the purposes of these Terms:\n'
                  '• “App” refers to the social media rating application provided by Ratedly.\n'
                  '• “User” means any individual or entity that accesses or uses the App.\n'
                  '• “Content” includes any text, images, ratings, reviews, or other materials you post or otherwise transmit via the App.\n'
                  '• “User Generated Content” is content created and uploaded by Users.\n'
                  '• “Account” means your registered profile used to access the App.\n'
                  '• “Payment Details” refers to any information provided by Users for any paid features or subscriptions.',
            ),
            _buildSection(
              number: '2',
              title: 'License to Use',
              content:
                  'Subject to your compliance with these Terms, Ratedly grants you a limited, non-exclusive, non-transferable, revocable license to access and use the App solely for your personal, non-commercial purposes. This license does not include any resale or commercial use of the App or its contents.',
            ),
            _buildSection(
              number: '3',
              title: 'Prohibited Conduct',
              content: 'You agree not to engage in any conduct that:\n'
                  '• Violates any applicable law or regulation.\n'
                  '• Infringes on the rights of others, including intellectual property rights.\n'
                  '• Involves abusive, harassing, or fraudulent behavior.\n'
                  '• Attempts to interfere with or disrupt the functionality or security of the App.\n'
                  '• Uses automated systems (bots) or any other means to manipulate the rating system.\n'
                  '• Engages in any activity that is unlawful, misleading, or fraudulent or for an illegal or unauthorized purpose.\n'
                  '• Any other behavior deemed unacceptable by Ratedly in our sole discretion.',
            ),
            _buildSection(
              number: '4',
              title: 'Right to Terminate Accounts',
              content:
                  'Ratedly reserves the right, at its sole discretion, to suspend or terminate your Account at any time, with or without notice, if you breach these Terms, engage in prohibited conduct, or otherwise negatively impact other Users or the App. This includes, but is not limited to, engaging in fraudulent or abusive activities.',
            ),
            _buildSection(
              number: '5',
              title: 'How a User Can Cancel/Terminate an Account',
              content:
                  'You may cancel or terminate your Account at any time by following the instructions provided within the App settings or by contacting our support team at ratedly9@gmail.com. Upon termination, your access to the App will immediately cease, although any Content you have submitted may remain in our systems as permitted by these Terms and our Privacy Policy.',
            ),
            _buildSection(
              number: '6',
              title: 'Ownership of Your Content',
              content:
                  'You retain ownership of all intellectual property rights in the Content you create and submit via the App. However, by submitting Content, you grant Ratedly a worldwide, non-exclusive, royalty-free, transferable license to use, reproduce, distribute, display, and create derivative works of your Content solely for the purpose of operating and promoting the App.',
            ),
            _buildSection(
              number: '7',
              title: 'User Generated Content',
              content:
                  'Users are solely responsible for the Content they create, upload, or otherwise contribute to the App. You represent and warrant that your Content does not violate any third-party rights or any applicable laws. Ratedly reserves the right to remove or modify any User Generated Content that violates these Terms or is deemed harmful or inappropriate.',
            ),
            _buildSection(
              number: '8',
              title: 'Right to Update or Modify Terms',
              content:
                  'Ratedly reserves the right to update or modify these Terms at any time without prior notice. Changes will be effective immediately upon posting on the App. Your continued use of the App after any changes constitutes your acceptance of the new Terms. It is your responsibility to review these Terms periodically for updates.',
            ),
            _buildSection(
              number: '9',
              title: 'Disclaimer of Warranty',
              content:
                  'The App is provided on an “as is” and “as available” basis without any warranties of any kind, whether express or implied. Ratedly does not warrant that the App will be uninterrupted, error-free, secure, or free of harmful components. Use of the App is at your sole risk.',
            ),
            _buildSection(
              number: '10',
              title: 'Disclaimer of Liability',
              content:
                  'In no event shall Ratedly, its affiliates, or licensors be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, arising out of or in connection with your use of the App, even if Ratedly has been advised of the possibility of such damages. Ratedly’s total liability to you for any claim under these Terms shall not exceed the amount paid by you, if any, for accessing the App.',
            ),
            _buildSection(
              number: '11',
              title: 'Who Is Responsible if Something Happens',
              content:
                  'Our Service is provided “as is,” and while Ratedly strives to maintain a secure and reliable platform, we cannot guarantee that the App will be safe, secure, or function perfectly at all times. Ratedly does not control what Users or third parties do or say—whether online or offline—and is not responsible for their actions, conduct, or the content they provide (including any unlawful or objectionable material). Additionally, Ratedly is not responsible for services and features offered by other people or companies, even if you access them through the App.',
            ),
            _buildSection(
              number: '12',
              title: 'Content Removal and Additional Rights We Retain',
              content:
                  '• Username and Identifier Policy: If you select a username or similar identifier for your Account, Ratedly reserves the right to change it if we believe such a change is appropriate or necessary (for example, if it infringes on someone’s intellectual property or impersonates another User).\n'
                  '• Accuracy of Information: You must provide accurate and up-to-date information during registration and throughout your use of the App. Although you are not required to disclose your true identity on Ratedly, the information you do provide must be correct.\n'
                  '• Impersonation and Fraud: You may not impersonate any person or entity or provide inaccurate information. Creating an account on behalf of someone else is not permitted unless you have their express permission.\n'
                  '• Prohibited Activities: Ratedly prohibits any unlawful, misleading, or fraudulent activity or any use of the App for any illegal or unauthorized purpose.\n\n'
                  'Ratedly reserves the right to remove any Content or disable/terminate your Account at its discretion if you violate these policies or if we deem it necessary to protect the integrity of the App or other Users.',
            ),
            _buildSection(
              number: '13',
              title: 'Governing Law',
              content:
                  'These Terms shall be governed by and construed in accordance with the laws of Delaware (USA) without regard to its conflict of law principles. Any disputes arising under or in connection with these Terms shall be resolved exclusively in the courts located in Delaware (USA).',
            ),
            _buildSection(
              number: '14',
              title: 'User Eligibility',
              content:
                  'By using the App, you confirm that you are at least 15 years old. If you are under 18, you must have permission from a parent or legal guardian to use the App. Ratedly reserves the right to request proof of age and suspend accounts that do not comply with this requirement.',
            ),
            _buildSection(
              number: '15',
              title: 'Privacy Policy',
              content:
                  'Your use of the App is also governed by our Privacy Policy...',
              extraContent: RichText(
                text: TextSpan(
                  text: '[Link to Privacy Policy]',
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                ),
              ),
            ),
            _buildSection(
              number: '16',
              title: 'User Safety and Apple Compliance',
              content:
                  'Ratedly is committed to providing a safe and respectful environment for all users. To comply with platform rules and ensure user safety:\n\n'
                  '• We use automatic and manual moderation tools to filter out objectionable content, including hate speech, harassment, and inappropriate imagery.\n'
                  '• Users can report content or other users by using the "Report" feature available on posts and profiles.\n'
                  '• Users can also block or mute others to avoid unwanted interactions.\n'
                  '• We may remove any content that violates our policies, and suspend or terminate accounts that engage in abusive, harmful, or illegal behavior.\n\n'
                  'These measures are in place to comply with Apple’s App Store Guidelines and to help maintain a positive experience for all users on the platform.',
            ),
            _buildSection(
              number: '17',
              title: 'Contact Information',
              content:
                  'If you have any questions, concerns, or feedback regarding these Terms, please contact us at:\n',
              extraContent: RichText(
                text: TextSpan(
                  text: 'Email: ratedly9@gmail.com',
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
        if (number != null)
          Text(
            '$number. $title',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (number == null)
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
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
