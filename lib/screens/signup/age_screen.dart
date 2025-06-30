import 'package:flutter/material.dart';
import 'package:Ratedly/screens/signup/profile_setup_screen.dart';

class AgeVerificationScreen extends StatefulWidget {
  const AgeVerificationScreen({super.key});

  @override
  State<AgeVerificationScreen> createState() => _AgeVerificationScreenState();
}

class _AgeVerificationScreenState extends State<AgeVerificationScreen> {
  final ScrollController _scrollController = ScrollController();
  int _selectedAge = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(20 * 40.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/logo/22.png',
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 20),
              const Text(
                'Please tell us your age',
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
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: 45,
                    itemBuilder: (context, index) {
                      final age = index + 16;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAge = age),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: age == _selectedAge
                                ? const Color(0xFF444444)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              age.toString(),
                              style: TextStyle(
                                fontSize: 24,
                                color: const Color(0xFFd9d9d9),
                                fontWeight: age == _selectedAge
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF333333),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileSetupScreen(age: _selectedAge),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
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
    );
  }
}
