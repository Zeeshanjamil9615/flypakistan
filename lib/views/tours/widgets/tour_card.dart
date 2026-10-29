import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../utility/colors.dart';
import '../tour_model.dart';
import '../tours_controller.dart';
import 'tour_details_sheet.dart';

const Color kWhatsAppGreen = Color(0xFF25D366);

/// Tour (or car) photo with a loading spinner while it downloads and a neutral
/// placeholder when it is missing or broken.
class TourImage extends StatelessWidget {
  final String url;
  final double height;
  final double? width;
  final BoxFit fit;
  final IconData placeholderIcon;

  const TourImage({
    super.key,
    required this.url,
    required this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.landscape,
  });

  @override
  Widget build(BuildContext context) {
    if (!url.startsWith('http')) return _buildFallback();

    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: width ?? double.infinity,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 300),
      progressIndicatorBuilder: (context, _, download) => Container(
        height: height,
        width: width ?? double.infinity,
        color: TColors.background3,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              // Null (spinning) until the download size is known.
              value: download.progress,
              strokeWidth: 2.5,
              color: TColors.primary,
              backgroundColor: TColors.primary.withOpacity(0.15),
            ),
          ),
        ),
      ),
      errorWidget: (context, _, __) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Container(
      height: height,
      width: width ?? double.infinity,
      color: TColors.background3,
      child: Center(
        child: Icon(placeholderIcon, color: TColors.iconclr, size: 36),
      ),
    );
  }
}

/// "Price On Call" in red like the website, or the amount in brand green.
class TourPriceTag extends StatelessWidget {
  final TourModel tour;
  final double fontSize;

  const TourPriceTag({super.key, required this.tour, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    return Text(
      tour.priceLabel,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: tour.hasPrice ? TColors.primary : TColors.red,
      ),
    );
  }
}

class TourWhatsAppButton extends StatelessWidget {
  final TourModel tour;
  final double height;

  const TourWhatsAppButton({super.key, required this.tour, this.height = 40});

  @override
  Widget build(BuildContext context) {
    final controller = ToursController.instance;
    return Obx(
      () => WhatsAppBookButton(
        isSending: controller.sharingTourId.value == tour.id,
        onPressed: controller.sharingTourId.value.isEmpty
            ? () => controller.bookViaWhatsApp(tour)
            : null,
        height: height,
      ),
    );
  }
}

/// Green "Book via WhatsApp" button with a spinner while the enquiry is being
/// prepared. A null [onPressed] disables it.
class WhatsAppBookButton extends StatelessWidget {
  final bool isSending;
  final VoidCallback? onPressed;
  final double height;
  final String label;

  const WhatsAppBookButton({
    super.key,
    required this.isSending,
    required this.onPressed,
    this.height = 40,
    this.label = 'Book via WhatsApp',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kWhatsAppGreen,
          disabledBackgroundColor: kWhatsAppGreen.withOpacity(0.6),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: isSending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(MdiIcons.whatsapp, size: 20),
        label: Text(
          isSending ? 'Opening WhatsApp...' : label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Tour card: photo with country badge, name, price and WhatsApp button.
/// Tapping the card opens the full details sheet.
///
/// [compact] is the narrow card of the home carousel: no description, and it
/// fills the carousel height with the button pinned to the bottom so all cards
/// line up. The full card sizes to its content.
class TourCard extends StatelessWidget {
  final TourModel tour;
  final bool compact;

  const TourCard({super.key, required this.tour, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final Widget details = Padding(
      padding: EdgeInsets.all(compact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tour.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: TColors.text,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Price',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                TourPriceTag(tour: tour, fontSize: compact ? 12 : 13),
              ],
            ),
          ),
          if (!compact && tour.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              tour.description,
              maxLines: 3,
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
          TourWhatsAppButton(tour: tour, height: compact ? 38 : 42),
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
          onTap: () => showTourDetailsSheet(context, tour),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  TourImage(url: tour.image, height: compact ? 120 : 180),
                  if (tour.country.isNotEmpty)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              tour.country,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
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
