import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../utility/colors.dart';
import '../car_model.dart';
import 'car_card.dart';

Future<void> showCarDetailsSheet(BuildContext context, CarModel car) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CarDetailsSheet(car: car),
  );
}

/// Car photo, rates and description with the WhatsApp button pinned at the
/// bottom.
class CarDetailsSheet extends StatelessWidget {
  final CarModel car;

  const CarDetailsSheet({super.key, required this.car});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: CarImage(url: car.image, height: 220),
                        ),
                        Positioned(
                          top: 10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Material(
                            color: Colors.grey.shade100,
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: TColors.text),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            car.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: TColors.text,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (car.year.isNotEmpty)
                                CarYearBadge(year: car.year),
                              if (car.city.isNotEmpty)
                                CarLocation(city: car.city, fontSize: 13),
                            ],
                          ),
                          const SizedBox(height: 16),
                          CarRates(car: car),
                          const SizedBox(height: 8),
                          Text(
                            'Message us on WhatsApp to confirm availability for your dates.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'About this car',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: TColors.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            car.description.isEmpty
                                ? 'Contact us on WhatsApp for full details about this car.'
                                : car.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                              height: 1.55,
                            ),
                          ),
                          if (car.detailsUrl.startsWith('http')) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _openWebsite,
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('View on website'),
                              style: TextButton.styleFrom(
                                foregroundColor: TColors.primary,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.verified_outlined,
                                size: 16,
                                color: TColors.iconclr,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Book with confidence: No hidden charges',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  12 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: CarWhatsAppButton(car: car, height: 48),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openWebsite() async {
    try {
      await launchUrl(
        Uri.parse(car.detailsUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      print('CarDetailsSheet open website error: $e');
    }
  }
}
