import 'package:flutter/material.dart';

class RatingBar extends StatefulWidget {
  final double initialRating;
  final ValueChanged<double>? onRatingUpdate;
  final ValueChanged<double> onRatingEnd;
  final bool hasRated;
  final double userRating;

  const RatingBar({
    Key? key,
    this.initialRating = 5.0,
    this.onRatingUpdate,
    required this.onRatingEnd,
    required this.hasRated,
    required this.userRating,
  }) : super(key: key);

  @override
  State<RatingBar> createState() => _RatingBarState();
}

class _RatingBarState extends State<RatingBar>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> scale;
  double _currentRating = 1;
  bool _showSlider = false;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    scale = Tween<double>(begin: 1, end: 1.1).animate(controller);
    _showSlider = !widget.hasRated;
  }

  void _onRatingChanged(double newRating) {
    setState(() => _currentRating = newRating);
    widget.onRatingUpdate?.call(newRating);
    controller.forward().then((_) => controller.reverse());
  }

  void _onRatingEnd(double rating) {
    setState(() => _showSlider = false);
    widget.onRatingEnd(rating);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_showSlider && widget.hasRated)
          Center(
            child: ElevatedButton(
              onPressed: () => setState(() => _showSlider = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF333333),
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                minimumSize: const Size(100, 40),
                fixedSize: const Size(200, 50),
              ),
              child: Text(
                'You rated: ${widget.userRating.toStringAsFixed(1)}, change it?',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFd9d9d9), // Fixed color declaration
                ),
              ),
            ),
          ),
        if (_showSlider)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Slider(
              value: _currentRating,
              min: 1,
              max: 10,
              divisions: 100,
              label: _currentRating.toStringAsFixed(1),
              activeColor: const Color(0xFFd9d9d9),
              inactiveColor: const Color(0xFF333333),
              onChanged: _onRatingChanged,
              onChangeEnd: _onRatingEnd,
            ),
          ),
      ],
    );
  }
}
