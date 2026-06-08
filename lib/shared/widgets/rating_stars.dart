import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../core/constants/app_colors.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final bool showValue;
  final int? reviewCount;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 18,
    this.showValue = true,
    this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RatingBarIndicator(
          rating: rating,
          itemBuilder: (_, __) => const Icon(Icons.star, color: AppColors.star),
          itemCount: 5,
          itemSize: size,
        ),
        if (showValue) ...[
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.75,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (reviewCount != null) ...[
            const SizedBox(width: 2),
            Text(
              '($reviewCount)',
              style: TextStyle(
                fontSize: size * 0.7,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class InteractiveRating extends StatelessWidget {
  final double initialRating;
  final void Function(double) onRatingUpdate;
  final double size;

  const InteractiveRating({
    super.key,
    required this.initialRating,
    required this.onRatingUpdate,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: initialRating,
      minRating: 1,
      direction: Axis.horizontal,
      allowHalfRating: true,
      itemCount: 5,
      itemSize: size,
      itemBuilder: (_, __) => const Icon(Icons.star, color: AppColors.star),
      onRatingUpdate: onRatingUpdate,
    );
  }
}
