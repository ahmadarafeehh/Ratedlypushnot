import 'dart:math';
import 'package:flutter/material.dart';
import 'falling_number_painter.dart';
import 'number_particle.dart';
import 'package:Ratedly/screens/login.dart';
import 'package:Ratedly/screens/signup/signup_screen.dart';

class GetStartedPage extends StatefulWidget {
  const GetStartedPage({super.key});

  @override
  State<GetStartedPage> createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<NumberParticle> _particles = [];
  final Random _random = Random();
  late double _screenHeight;

  @override
  void initState() {
    super.initState();
    _initializeParticles(25);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenHeight = MediaQuery.of(context).size.height;
  }

  void _initializeParticles(int count) {
    _particles.addAll(List.generate(
        count,
        (_) => NumberParticle(
              x: _random.nextDouble(),
              y: -_random.nextDouble() * 0.5,
              speed: 0.5 + _random.nextDouble() * 0.5,
              rotation: _random.nextDouble() * 2 * pi,
              rotationSpeed: _random.nextDouble() * 0.005,
              opacity: 0.5 + _random.nextDouble() * 0.4, // Higher opacity
              number: _random.nextInt(10) + 1,
              fontSize: 20 + _random.nextDouble() * 15, // Larger font size
              sway: 0.0,
              swaySpeed: _random.nextDouble() * 0.005,
            )));
  }

  void _updateParticles() {
    for (final particle in _particles) {
      particle.y += particle.speed * 0.015;
      particle.rotation += particle.rotationSpeed;
      particle.sway += particle.swaySpeed;

      if (particle.y * _screenHeight > _screenHeight * 1.2) {
        particle.y = -_random.nextDouble() * 0.5;
        particle.x = _random.nextDouble();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Updated to primary background
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          _updateParticles();
          return Stack(
            children: [
              CustomPaint(
                painter: FallingNumbersPainter(
                  particles: _particles,
                  repaint: _controller,
                ),
                size: Size.infinite,
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Replace text with logo image
                      Image.asset(
                        'assets/logo/22.png',
                        width: 100, // Adjust size as needed
                        height: 100,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Discover Your Rating',
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
                      ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SignupScreen()),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF333333),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF333333),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
