import 'package:flutter/material.dart';

import '../../../utility/colors.dart';
import '../../tours/widgets/tour_card.dart';
import '../car_details_screen.dart';
import '../car_model.dart';
import '../cars_controller.dart';
import 'car_card.dart';

/// Card of the details page's "Other cars" tab, like the website: photo,
/// within-city price, Color / Capacity / Year / Transmission chips and
/// Call now / View more. Tapping it opens that car's details.
class OtherCarCard extends StatelessWidget {
  final CarModel car;

  const OtherCarCard({super.key, required this.car});

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = [
      if (car.color.isNotEmpty) _buildChip('Color', car.color),
      if (car.capacity > 0) _buildChip('Capacity', '${car.capacity}'),
      if (car.year.isNotEmpty) _buildChip('Year', car.year),
      if (car.transmission.isNotEmpty)
        _buildChip('Transmission', car.transmission),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openCarDetails(car),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: TourImage(
                        url: car.image,
                        height: 90,
                        fit: BoxFit.contain,
                        placeholderIcon: Icons.directions_car,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            car.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: TColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Price within city: ',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                TextSpan(
                                  text: car.rateLabel(car.rate),
                                  style: TextStyle(
                                    color: car.hasRate
                                        ? TColors.primary
                                        : TColors.red,
                                  ),
                                ),
                              ],
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (car.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              car.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: chips),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          onPressed: CarsController.instance.callNow,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: TColors.red,
                            side: const BorderSide(color: TColors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.call, size: 18),
                          label: const Text(
                            'Call now',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: CarViewMoreButton(car: car)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Color: Grey" chip, label grey and value green like the website.
  Widget _buildChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TColors.background2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TColors.primary.withOpacity(0.15)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: TColors.grey),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: TColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}
