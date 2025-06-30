import 'package:flutter/material.dart';
import 'package:Ratedly/resources/posts_firestore_methods.dart';
import 'package:Ratedly/utils/utils.dart';
import 'package:Ratedly/widgets/flutter_rating_bar.dart';

class RatingSection extends StatefulWidget {
  final String postId;
  final String userId;
  final List<dynamic> ratings;
  final Function(double)? onRatingEnd;

  const RatingSection({
    Key? key,
    required this.postId,
    required this.userId,
    required this.ratings,
    this.onRatingEnd,
  }) : super(key: key);

  @override
  State<RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends State<RatingSection> {
  double _currentRating = 1;

  @override
  Widget build(BuildContext context) {
    double? userRating;
    for (var rating in widget.ratings) {
      if ((rating['userId'] as String) == widget.userId) {
        // Correctly handle int/double types from Firestore
        userRating = (rating['rating'] as num).toDouble();
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 1.5),
        RatingBar(
          initialRating: userRating ?? 5.0,
          hasRated: userRating != null,
          userRating: userRating ?? 5.0,
          onRatingEnd: (rating) async {
            setState(() => _currentRating = rating);
            String response = await FireStorePostsMethods().ratePost(
              widget.postId,
              widget.userId,
              rating,
            );
            if (response != 'success') {
              showSnackBar(context, response);
            } else {
              widget.onRatingEnd?.call(rating);
            }
          },
        ),
      ],
    );
  }
}
