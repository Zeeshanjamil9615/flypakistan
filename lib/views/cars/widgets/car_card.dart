import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../utility/colors.dart';
import '../../tours/widgets/tour_card.dart';
import '../car_model.dart';
import '../cars_controller.dart';
import 'car_details_sheet.dart';

/// Car photo shown whole on white, like the website — the photos are
/// cut-outs, so cropping them (as tour photos are) would cut the car off.
class CarImage extends StatelessWidget {
  final String url;
  final double height;

  const CarImage({super.key, required this.url, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: Colors.white,
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: TourImage(
          url: url,
          height: height - 16,
          fit: BoxFit.contain,
          placeholderIcon: Icons.directions_car,
        ),
      ),
    );
  }
}

class CarYearBadge extends StatelessWidget {
  final String year;

  const CarYearBadge({super.key, required this.year});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Model $year',
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// "Rent a Car in Lahore" with a pin, as on the website.
class CarLocation extends StatelessWidget {
  final String city;
  final double fontSize;

  const CarLocation({super.key, required this.city, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, size: fontSize + 2, color: TColors.iconclr),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            'Rent a Car in $city',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: fontSize, color: TColors.grey),
          ),
        ),
      ],
    );
  }
}

/// Within-city and out-of-city rent side by side.
class CarRates extends StatelessWidget {
  final CarModel car;
  final bool compact;

  const CarRates({super.key, required this.car, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 7 : 10),
      decoration: BoxDecoration(
        color: TColors.background2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TColors.primary.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildRate('Within city', car.rate)),
          Container(
            width: 1,
            height: compact ? 28 : 34,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: TColors.primary.withOpacity(0.15),
          ),
          Expanded(child: _buildRate('Out of city', car.outRate)),
        ],
      ),
    );
  }

  Widget _buildRate(String label, double? amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            car.rateLabel(amount),
            style: TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.bold,
              color: (amount ?? 0) > 0 ? TColors.primary : TColors.red,
            ),
          ),
        ),
      ],
    );
  }
}

class CarWhatsAppButton extends StatelessWidget {
  final CarModel car;
  final double height;

  const CarWhatsAppButton({super.key, required this.car, this.height = 40});

  @override
  Widget build(BuildContext context) {
    final controller = CarsController.instance;
    return Obx(
      () => WhatsAppBookButton(
        isSending: controller.sharingCarId.value == car.id,
        onPressed: controller.sharingCarId.value.isEmpty
            ? () => controller.bookViaWhatsApp(car)
            : null,
        height: height,
      ),
    );
  }
}

/// Car card: photo with model-year badge, name, city, both rates and the
/// WhatsApp button. Tapping the card opens the details sheet.
///
/// [compact] is the narrow card of the home carousel: no description, and it
/// fills the carousel height with the button pinned to the bottom so all cards
/// line up. The full card sizes to its content.
class CarCard extends StatelessWidget {
  final CarModel car;
  final bool compact;

  const CarCard({super.key, required this.car, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final double padding = compact ? 10 : 14;
    final Widget details = Padding(
      // The photo already leaves 8px of white below it.
      padding: EdgeInsets.fromLTRB(padding, 4, padding, padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            car.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: TColors.text,
              height: 1.3,
            ),
          ),
          if (car.city.isNotEmpty) ...[
            const SizedBox(height: 4),
            CarLocation(city: car.city),
          ],
          SizedBox(height: compact ? 8 : 10),
          CarRates(car: car, compact: compact),
          if (!compact && car.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              car.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
          if (compact) const Spacer() else const SizedBox(height: 12),
          if (compact) const SizedBox(height: 10),
          CarWhatsAppButton(car: car, height: compact ? 38 : 42),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
          onTap: () => showCarDetailsSheet(context, car),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CarImage(url: car.image, height: compact ? 115 : 175),
                  if (car.year.isNotEmpty)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: CarYearBadge(year: car.year),
                    ),
                ],
              ),
              if (compact) Expanded(child: details) else details,
            ],
          ),
        ),
      ),
    );
  }
}
