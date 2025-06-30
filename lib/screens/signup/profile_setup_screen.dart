import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:Ratedly/resources/auth_methods.dart';
import 'package:Ratedly/responsive/mobile_screen_layout.dart';
import 'package:Ratedly/responsive/responsive_layout.dart';
import 'package:Ratedly/utils/utils.dart';
import 'package:Ratedly/widgets/text_filed_input.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileSetupScreen extends StatefulWidget {
  final int age;

  const ProfileSetupScreen({super.key, required this.age});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  Uint8List? _image;
  bool _isLoading = false;
  bool _isPrivate = false;
  String? _selectedCountry;
  String? _selectedGender;
  String? _usernameError;
  int _usernameLength = 0;
  bool _showCountryList = false;

  // Country data with emoji flags
  final List<Map<String, String>> _countries = [
    {'name': 'Afghanistan', 'code': 'AF', 'flag': '🇦🇫'},
    {'name': 'Albania', 'code': 'AL', 'flag': '🇦🇱'},
    {'name': 'Algeria', 'code': 'DZ', 'flag': '🇩🇿'},
    {'name': 'Andorra', 'code': 'AD', 'flag': '🇦🇩'},
    {'name': 'Angola', 'code': 'AO', 'flag': '🇦🇴'},
    {'name': 'Antigua and Barbuda', 'code': 'AG', 'flag': '🇦🇬'},
    {'name': 'Argentina', 'code': 'AR', 'flag': '🇦🇷'},
    {'name': 'Armenia', 'code': 'AM', 'flag': '🇦🇲'},
    {'name': 'Australia', 'code': 'AU', 'flag': '🇦🇺'},
    {'name': 'Austria', 'code': 'AT', 'flag': '🇦🇹'},
    {'name': 'Azerbaijan', 'code': 'AZ', 'flag': '🇦🇿'},
    {'name': 'Bahamas', 'code': 'BS', 'flag': '🇧🇸'},
    {'name': 'Bahrain', 'code': 'BH', 'flag': '🇧🇭'},
    {'name': 'Bangladesh', 'code': 'BD', 'flag': '🇧🇩'},
    {'name': 'Barbados', 'code': 'BB', 'flag': '🇧🇧'},
    {'name': 'Belarus', 'code': 'BY', 'flag': '🇧🇾'},
    {'name': 'Belgium', 'code': 'BE', 'flag': '🇧🇪'},
    {'name': 'Belize', 'code': 'BZ', 'flag': '🇧🇿'},
    {'name': 'Benin', 'code': 'BJ', 'flag': '🇧🇯'},
    {'name': 'Bhutan', 'code': 'BT', 'flag': '🇧🇹'},
    {'name': 'Bolivia', 'code': 'BO', 'flag': '🇧🇴'},
    {'name': 'Bosnia and Herzegovina', 'code': 'BA', 'flag': '🇧🇦'},
    {'name': 'Botswana', 'code': 'BW', 'flag': '🇧🇼'},
    {'name': 'Brazil', 'code': 'BR', 'flag': '🇧🇷'},
    {'name': 'Brunei', 'code': 'BN', 'flag': '🇧🇳'},
    {'name': 'Bulgaria', 'code': 'BG', 'flag': '🇧🇬'},
    {'name': 'Burkina Faso', 'code': 'BF', 'flag': '🇧🇫'},
    {'name': 'Burundi', 'code': 'BI', 'flag': '🇧🇮'},
    {'name': 'Cabo Verde', 'code': 'CV', 'flag': '🇨🇻'},
    {'name': 'Cambodia', 'code': 'KH', 'flag': '🇰🇭'},
    {'name': 'Cameroon', 'code': 'CM', 'flag': '🇨🇲'},
    {'name': 'Canada', 'code': 'CA', 'flag': '🇨🇦'},
    {'name': 'Central African Republic', 'code': 'CF', 'flag': '🇨🇫'},
    {'name': 'Chad', 'code': 'TD', 'flag': '🇹🇩'},
    {'name': 'Chile', 'code': 'CL', 'flag': '🇨🇱'},
    {'name': 'China', 'code': 'CN', 'flag': '🇨🇳'},
    {'name': 'Colombia', 'code': 'CO', 'flag': '🇨🇴'},
    {'name': 'Comoros', 'code': 'KM', 'flag': '🇰🇲'},
    {'name': 'Congo (Congo-Brazzaville)', 'code': 'CG', 'flag': '🇨🇬'},
    {'name': 'Costa Rica', 'code': 'CR', 'flag': '🇨🇷'},
    {'name': 'Croatia', 'code': 'HR', 'flag': '🇭🇷'},
    {'name': 'Cuba', 'code': 'CU', 'flag': '🇨🇺'},
    {'name': 'Cyprus', 'code': 'CY', 'flag': '🇨🇾'},
    {'name': 'Czechia (Czech Republic)', 'code': 'CZ', 'flag': '🇨🇿'},
    {'name': 'Denmark', 'code': 'DK', 'flag': '🇩🇰'},
    {'name': 'Djibouti', 'code': 'DJ', 'flag': '🇩🇯'},
    {'name': 'Dominica', 'code': 'DM', 'flag': '🇩🇲'},
    {'name': 'Dominican Republic', 'code': 'DO', 'flag': '🇩🇴'},
    {'name': 'Ecuador', 'code': 'EC', 'flag': '🇪🇨'},
    {'name': 'Egypt', 'code': 'EG', 'flag': '🇪🇬'},
    {'name': 'El Salvador', 'code': 'SV', 'flag': '🇸🇻'},
    {'name': 'Equatorial Guinea', 'code': 'GQ', 'flag': '🇬🇶'},
    {'name': 'Eritrea', 'code': 'ER', 'flag': '🇪🇷'},
    {'name': 'Estonia', 'code': 'EE', 'flag': '🇪🇪'},
    {'name': 'Eswatini (fmr. "Swaziland")', 'code': 'SZ', 'flag': '🇸🇿'},
    {'name': 'Ethiopia', 'code': 'ET', 'flag': '🇪🇹'},
    {'name': 'Fiji', 'code': 'FJ', 'flag': '🇫🇯'},
    {'name': 'Finland', 'code': 'FI', 'flag': '🇫🇮'},
    {'name': 'France', 'code': 'FR', 'flag': '🇫🇷'},
    {'name': 'Gabon', 'code': 'GA', 'flag': '🇬🇦'},
    {'name': 'Gambia', 'code': 'GM', 'flag': '🇬🇲'},
    {'name': 'Georgia', 'code': 'GE', 'flag': '🇬🇪'},
    {'name': 'Germany', 'code': 'DE', 'flag': '🇩🇪'},
    {'name': 'Ghana', 'code': 'GH', 'flag': '🇬🇭'},
    {'name': 'Greece', 'code': 'GR', 'flag': '🇬🇷'},
    {'name': 'Grenada', 'code': 'GD', 'flag': '🇬🇩'},
    {'name': 'Guatemala', 'code': 'GT', 'flag': '🇬🇹'},
    {'name': 'Guinea', 'code': 'GN', 'flag': '🇬🇳'},
    {'name': 'Guinea-Bissau', 'code': 'GW', 'flag': '🇬🇼'},
    {'name': 'Guyana', 'code': 'GY', 'flag': '🇬🇾'},
    {'name': 'Haiti', 'code': 'HT', 'flag': '🇭🇹'},
    {'name': 'Honduras', 'code': 'HN', 'flag': '🇭🇳'},
    {'name': 'Hungary', 'code': 'HU', 'flag': '🇭🇺'},
    {'name': 'Iceland', 'code': 'IS', 'flag': '🇮🇸'},
    {'name': 'India', 'code': 'IN', 'flag': '🇮🇳'},
    {'name': 'Indonesia', 'code': 'ID', 'flag': '🇮🇩'},
    {'name': 'Iran', 'code': 'IR', 'flag': '🇮🇷'},
    {'name': 'Iraq', 'code': 'IQ', 'flag': '🇮🇶'},
    {'name': 'Ireland', 'code': 'IE', 'flag': '🇮🇪'},
    {'name': 'Italy', 'code': 'IT', 'flag': '🇮🇹'},
    {'name': 'Jamaica', 'code': 'JM', 'flag': '🇯🇲'},
    {'name': 'Japan', 'code': 'JP', 'flag': '🇯🇵'},
    {'name': 'Jordan', 'code': 'JO', 'flag': '🇯🇴'},
    {'name': 'Kazakhstan', 'code': 'KZ', 'flag': '🇰🇿'},
    {'name': 'Kenya', 'code': 'KE', 'flag': '🇰🇪'},
    {'name': 'Kiribati', 'code': 'KI', 'flag': '🇰🇮'},
    {'name': 'Kuwait', 'code': 'KW', 'flag': '🇰🇼'},
    {'name': 'Kyrgyzstan', 'code': 'KG', 'flag': '🇰🇬'},
    {'name': 'Laos', 'code': 'LA', 'flag': '🇱🇦'},
    {'name': 'Latvia', 'code': 'LV', 'flag': '🇱🇻'},
    {'name': 'Lebanon', 'code': 'LB', 'flag': '🇱🇧'},
    {'name': 'Lesotho', 'code': 'LS', 'flag': '🇱🇸'},
    {'name': 'Liberia', 'code': 'LR', 'flag': '🇱🇷'},
    {'name': 'Libya', 'code': 'LY', 'flag': '🇱🇾'},
    {'name': 'Liechtenstein', 'code': 'LI', 'flag': '🇱🇮'},
    {'name': 'Lithuania', 'code': 'LT', 'flag': '🇱🇹'},
    {'name': 'Luxembourg', 'code': 'LU', 'flag': '🇱🇺'},
    {'name': 'Madagascar', 'code': 'MG', 'flag': '🇲🇬'},
    {'name': 'Malawi', 'code': 'MW', 'flag': '🇲🇼'},
    {'name': 'Malaysia', 'code': 'MY', 'flag': '🇲🇾'},
    {'name': 'Maldives', 'code': 'MV', 'flag': '🇲🇻'},
    {'name': 'Mali', 'code': 'ML', 'flag': '🇲🇱'},
    {'name': 'Malta', 'code': 'MT', 'flag': '🇲🇹'},
    {'name': 'Marshall Islands', 'code': 'MH', 'flag': '🇲🇭'},
    {'name': 'Mauritania', 'code': 'MR', 'flag': '🇲🇷'},
    {'name': 'Mauritius', 'code': 'MU', 'flag': '🇲🇺'},
    {'name': 'Mexico', 'code': 'MX', 'flag': '🇲🇽'},
    {'name': 'Micronesia', 'code': 'FM', 'flag': '🇫🇲'},
    {'name': 'Moldova', 'code': 'MD', 'flag': '🇲🇩'},
    {'name': 'Monaco', 'code': 'MC', 'flag': '🇲🇨'},
    {'name': 'Mongolia', 'code': 'MN', 'flag': '🇲🇳'},
    {'name': 'Montenegro', 'code': 'ME', 'flag': '🇲🇪'},
    {'name': 'Morocco', 'code': 'MA', 'flag': '🇲🇦'},
    {'name': 'Mozambique', 'code': 'MZ', 'flag': '🇲🇿'},
    {'name': 'Myanmar (formerly Burma)', 'code': 'MM', 'flag': '🇲🇲'},
    {'name': 'Namibia', 'code': 'NA', 'flag': '🇳🇦'},
    {'name': 'Nauru', 'code': 'NR', 'flag': '🇳🇷'},
    {'name': 'Nepal', 'code': 'NP', 'flag': '🇳🇵'},
    {'name': 'Netherlands', 'code': 'NL', 'flag': '🇳🇱'},
    {'name': 'New Zealand', 'code': 'NZ', 'flag': '🇳🇿'},
    {'name': 'Nicaragua', 'code': 'NI', 'flag': '🇳🇮'},
    {'name': 'Niger', 'code': 'NE', 'flag': '🇳🇪'},
    {'name': 'Nigeria', 'code': 'NG', 'flag': '🇳🇬'},
    {'name': 'North Korea', 'code': 'KP', 'flag': '🇰🇵'},
    {'name': 'North Macedonia', 'code': 'MK', 'flag': '🇲🇰'},
    {'name': 'Norway', 'code': 'NO', 'flag': '🇳🇴'},
    {'name': 'Oman', 'code': 'OM', 'flag': '🇴🇲'},
    {'name': 'Pakistan', 'code': 'PK', 'flag': '🇵🇰'},
    {'name': 'Palau', 'code': 'PW', 'flag': '🇵🇼'},
    {'name': 'Palestine State', 'code': 'PS', 'flag': '🇵🇸'},
    {'name': 'Panama', 'code': 'PA', 'flag': '🇵🇦'},
    {'name': 'Papua New Guinea', 'code': 'PG', 'flag': '🇵🇬'},
    {'name': 'Paraguay', 'code': 'PY', 'flag': '🇵🇾'},
    {'name': 'Peru', 'code': 'PE', 'flag': '🇵🇪'},
    {'name': 'Philippines', 'code': 'PH', 'flag': '🇵🇭'},
    {'name': 'Poland', 'code': 'PL', 'flag': '🇵🇱'},
    {'name': 'Portugal', 'code': 'PT', 'flag': '🇵🇹'},
    {'name': 'Qatar', 'code': 'QA', 'flag': '🇶🇦'},
    {'name': 'Romania', 'code': 'RO', 'flag': '🇷🇴'},
    {'name': 'Russia', 'code': 'RU', 'flag': '🇷🇺'},
    {'name': 'Rwanda', 'code': 'RW', 'flag': '🇷🇼'},
    {'name': 'Saint Kitts and Nevis', 'code': 'KN', 'flag': '🇰🇳'},
    {'name': 'Saint Lucia', 'code': 'LC', 'flag': '🇱🇨'},
    {'name': 'Saint Vincent and the Grenadines', 'code': 'VC', 'flag': '🇻🇨'},
    {'name': 'Samoa', 'code': 'WS', 'flag': '🇼🇸'},
    {'name': 'San Marino', 'code': 'SM', 'flag': '🇸🇲'},
    {'name': 'Sao Tome and Principe', 'code': 'ST', 'flag': '🇸🇹'},
    {'name': 'Saudi Arabia', 'code': 'SA', 'flag': '🇸🇦'},
    {'name': 'Senegal', 'code': 'SN', 'flag': '🇸🇳'},
    {'name': 'Serbia', 'code': 'RS', 'flag': '🇷🇸'},
    {'name': 'Seychelles', 'code': 'SC', 'flag': '🇸🇨'},
    {'name': 'Sierra Leone', 'code': 'SL', 'flag': '🇸🇱'},
    {'name': 'Singapore', 'code': 'SG', 'flag': '🇸🇬'},
    {'name': 'Slovakia', 'code': 'SK', 'flag': '🇸🇰'},
    {'name': 'Slovenia', 'code': 'SI', 'flag': '🇸🇮'},
    {'name': 'Solomon Islands', 'code': 'SB', 'flag': '🇸🇧'},
    {'name': 'Somalia', 'code': 'SO', 'flag': '🇸🇴'},
    {'name': 'South Africa', 'code': 'ZA', 'flag': '🇿🇦'},
    {'name': 'South Korea', 'code': 'KR', 'flag': '🇰🇷'},
    {'name': 'South Sudan', 'code': 'SS', 'flag': '🇸🇸'},
    {'name': 'Spain', 'code': 'ES', 'flag': '🇪🇸'},
    {'name': 'Sri Lanka', 'code': 'LK', 'flag': '🇱🇰'},
    {'name': 'Sudan', 'code': 'SD', 'flag': '🇸🇩'},
    {'name': 'Suriname', 'code': 'SR', 'flag': '🇸🇷'},
    {'name': 'Sweden', 'code': 'SE', 'flag': '🇸🇪'},
    {'name': 'Switzerland', 'code': 'CH', 'flag': '🇨🇭'},
    {'name': 'Syria', 'code': 'SY', 'flag': '🇸🇾'},
    {'name': 'Tajikistan', 'code': 'TJ', 'flag': '🇹🇯'},
    {'name': 'Tanzania', 'code': 'TZ', 'flag': '🇹🇿'},
    {'name': 'Thailand', 'code': 'TH', 'flag': '🇹🇭'},
    {'name': 'Timor-Leste', 'code': 'TL', 'flag': '🇹🇱'},
    {'name': 'Togo', 'code': 'TG', 'flag': '🇹🇬'},
    {'name': 'Tonga', 'code': 'TO', 'flag': '🇹🇴'},
    {'name': 'Trinidad and Tobago', 'code': 'TT', 'flag': '🇹🇹'},
    {'name': 'Tunisia', 'code': 'TN', 'flag': '🇹🇳'},
    {'name': 'Turkey', 'code': 'TR', 'flag': '🇹🇷'},
    {'name': 'Turkmenistan', 'code': 'TM', 'flag': '🇹🇲'},
    {'name': 'Tuvalu', 'code': 'TV', 'flag': '🇹🇻'},
    {'name': 'Uganda', 'code': 'UG', 'flag': '🇺🇬'},
    {'name': 'Ukraine', 'code': 'UA', 'flag': '🇺🇦'},
    {'name': 'United Arab Emirates', 'code': 'AE', 'flag': '🇦🇪'},
    {'name': 'United Kingdom', 'code': 'GB', 'flag': '🇬🇧'},
    {'name': 'United States', 'code': 'US', 'flag': '🇺🇸'},
    {'name': 'Uruguay', 'code': 'UY', 'flag': '🇺🇾'},
    {'name': 'Uzbekistan', 'code': 'UZ', 'flag': '🇺🇿'},
    {'name': 'Vanuatu', 'code': 'VU', 'flag': '🇻🇺'},
    {'name': 'Vatican City', 'code': 'VA', 'flag': '🇻🇦'},
    {'name': 'Venezuela', 'code': 'VE', 'flag': '🇻🇪'},
    {'name': 'Vietnam', 'code': 'VN', 'flag': '🇻🇳'},
    {'name': 'Yemen', 'code': 'YE', 'flag': '🇾🇪'},
    {'name': 'Zambia', 'code': 'ZM', 'flag': '🇿🇲'},
    {'name': 'Zimbabwe', 'code': 'ZW', 'flag': '🇿🇼'},
  ];

  final List<String> _genders = ['Male', 'Female'];

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_validateUsername);
  }

  // Helper function to validate username
  String? _validateUsernameText(String username) {
    if (username.isEmpty) return null;

    if (username.length > 20) {
      return "Username must be 20 characters or fewer";
    }

    if (!RegExp(r'^[a-z0-9_.]*$').hasMatch(username)) {
      return "Only lowercase letters, numbers, . and _ allowed";
    }

    if (username.startsWith('.') ||
        username.startsWith('_') ||
        username.endsWith('.') ||
        username.endsWith('_')) {
      return "Cannot start or end with . or _";
    }

    if (username.contains('..') ||
        username.contains('__') ||
        username.contains('._') ||
        username.contains('_.')) {
      return "Cannot have consecutive . or _ characters";
    }

    return null;
  }

  void _validateUsername() {
    final username = _usernameController.text;
    setState(() {
      _usernameLength = username.length;
      _usernameError = _validateUsernameText(username);
    });
  }

  void selectImage() async {
    Uint8List? im = await pickImage(ImageSource.gallery);
    setState(() => _image = im);
  }

  void completeProfile() async {
    // Validate username again before submission
    final usernameError = _validateUsernameText(_usernameController.text);
    if (usernameError != null) {
      setState(() => _usernameError = usernameError);
      showSnackBar(context, usernameError);
      return;
    }

    if (_selectedCountry == null || _selectedGender == null) {
      showSnackBar(context, 'Please fill all required fields');
      return;
    }

    setState(() => _isLoading = true);

    String res = await AuthMethods().completeProfile(
      username: _usernameController.text.trim(),
      bio: _bioController.text,
      file: _image,
      isPrivate: _isPrivate,
      region: _selectedCountry!,
      age: widget.age,
      gender: _selectedGender!,
    );

    if (res == "success") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ResponsiveLayout(
            mobileScreenLayout: MobileScreenLayout(),
          ),
        ),
      );
    } else {
      showSnackBar(context, res);
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _usernameController.removeListener(_validateUsername);
    _deleteUnverifiedUserIfIncomplete();
    super.dispose();
  }

  Future<void> _deleteUnverifiedUserIfIncomplete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      await user.delete();
    }
  }

  // Check if form is valid for submit button
  bool get _isFormValid {
    return _validateUsernameText(_usernameController.text) == null &&
        _selectedCountry != null &&
        _selectedGender != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Profile Setup',
                  style: TextStyle(
                    color: Color(0xFFd9d9d9),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Stack(
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF333333),
                      ),
                      child: _image != null
                          ? ClipOval(
                              child: Image.memory(
                                _image!,
                                fit: BoxFit.cover,
                                width: 150,
                                height: 150,
                              ),
                            )
                          : const Icon(
                              Icons.account_circle,
                              size: 150,
                              color: Color(0xFF444444),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF333333),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          onPressed: selectImage,
                          icon: const Icon(Icons.add_a_photo,
                              color: Color(0xFFd9d9d9)),
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 40),
                TextFieldInput(
                  hintText: 'Username',
                  textInputType: TextInputType.text,
                  textEditingController: _usernameController,
                  fillColor: const Color(0xFF333333),
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontFamily: 'Inter',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_usernameError != null)
                        Expanded(
                          child: Text(
                            _usernameError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Text(
                        '$_usernameLength/30',
                        style: TextStyle(
                          color:
                              _usernameLength > 30 ? Colors.red : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFieldInput(
                  hintText: 'Bio (optional)',
                  textInputType: TextInputType.text,
                  textEditingController: _bioController,
                  fillColor: const Color(0xFF333333),
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 24),
                // Country Picker
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          _selectedCountry ?? 'Select Country',
                          style: const TextStyle(
                            color: Color(0xFFd9d9d9),
                            fontFamily: 'Inter',
                          ),
                        ),
                        trailing: Icon(
                          _showCountryList
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: const Color(0xFFd9d9d9),
                        ),
                        onTap: () {
                          setState(() {
                            _showCountryList = !_showCountryList;
                          });
                        },
                      ),
                      if (_showCountryList)
                        Container(
                          height: 200,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ListView.builder(
                            itemCount: _countries.length,
                            itemBuilder: (context, index) {
                              final country = _countries[index];
                              return ListTile(
                                leading: Text(
                                  country['flag']!,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                title: Text(
                                  country['name']!,
                                  style: const TextStyle(
                                    color: Color(0xFFd9d9d9),
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedCountry = country['name'];
                                    _showCountryList = false;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF333333),
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        labelStyle: TextStyle(color: Color(0xFFd9d9d9)),
                        border: InputBorder.none,
                      ),
                      items: _genders.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: Color(0xFFd9d9d9),
                              fontFamily: 'Inter',
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedGender = value),
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Color(0xFFd9d9d9)),
                      style: const TextStyle(
                        color: Color(0xFFd9d9d9),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'Private Account',
                      style: TextStyle(
                        color: Color(0xFFd9d9d9),
                        fontFamily: 'Inter',
                      ),
                    ),
                    value: _isPrivate,
                    activeColor: const Color(0xFFd9d9d9),
                    onChanged: (value) => setState(() => _isPrivate = value),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFormValid
                        ? const Color(0xFF333333)
                        : const Color(0xFF222222),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed:
                      _isFormValid && !_isLoading ? completeProfile : null,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : Text(
                          'Complete Profile',
                          style: TextStyle(
                            color:
                                _isFormValid ? Colors.white : Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Inter',
                          ),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
