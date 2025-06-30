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
  late double _currentRating;
  late bool _showSlider;

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

  @override
  void didUpdateWidget(covariant RatingBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update state when parent widget changes the rating status
    if (widget.hasRated != oldWidget.hasRated) {
      setState(() {
        _showSlider = !widget.hasRated;
      });
    }

    // Keep current rating in sync with parent's userRating
    if (widget.hasRated && widget.userRating != _currentRating) {
      _currentRating = widget.userRating;
    }
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
              onPressed: () {
                setState(() {
                  // Start with user's existing rating when changing
                  _currentRating = widget.userRating;
                  _showSlider = true;
                });
              },
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
                  color: Color(0xFFd9d9d9),
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
