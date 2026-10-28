import 'package:flutter/material.dart';

import '../../../utility/colors.dart';
import '../tour_model.dart';
import 'tour_card.dart';

Future<void> showTourDetailsSheet(BuildContext context, TourModel tour) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TourDetailsSheet(tour: tour),
  );
}

/// Full tour description with the WhatsApp button pinned at the bottom.
class TourDetailsSheet extends StatelessWidget {
  final TourModel tour;

  const TourDetailsSheet({super.key, required this.tour});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
                        TourImage(url: tour.image, height: 230),
                        Positioned(
                          top: 10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Material(
                            color: Colors.black.withOpacity(0.45),
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tour.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: TColors.text,
                              height: 1.3,
                            ),
                          ),
                          if (tour.country.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: TColors.iconclr,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tour.country,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: TColors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildPriceBox(),
                          const SizedBox(height: 20),
                          const Text(
                            'About this tour',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: TColors.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tour.description.isEmpty
                                ? 'Contact us on WhatsApp for the full itinerary and details.'
                                : tour.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 16),
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
                child: TourWhatsAppButton(tour: tour, height: 48),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceBox() {
    final List<MapEntry<String, String>> rates = [
      if ((tour.adultRate ?? 0) > 0)
        MapEntry('Adult', tour.formatAmount(tour.adultRate!)),
      if ((tour.childRate ?? 0) > 0)
        MapEntry('Child', tour.formatAmount(tour.childRate!)),
      if (tour.paxNo > 0) MapEntry('Group size', '${tour.paxNo} pax'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TColors.background2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TColors.primary.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Price',
                style: TextStyle(fontSize: 14, color: TColors.grey),
              ),
              const Spacer(),
              TourPriceTag(tour: tour, fontSize: 16),
            ],
          ),
          if (!tour.hasPrice) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Message us on WhatsApp to get the latest price for your dates.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ],
          for (final rate in rates) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  rate.key,
                  style: const TextStyle(fontSize: 13, color: TColors.grey),
                ),
                const Spacer(),
                Text(
                  rate.value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TColors.text,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
