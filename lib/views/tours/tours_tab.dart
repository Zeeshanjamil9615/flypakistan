import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../utility/app_constants.dart';
import '../../utility/colors.dart';
import 'tours_controller.dart';
import 'tours_screen.dart';
import 'widgets/tour_card.dart';
import 'widgets/tours_message_view.dart';

/// Content of the "Tours" tab in the home booking card: a swipeable preview of
/// the tours and a button to the full list.
///
/// Tours are (re)fetched every time the tab is opened; cached tours stay on
/// screen while the refresh runs.
class ToursTab extends StatefulWidget {
  const ToursTab({super.key});

  @override
  State<ToursTab> createState() => _ToursTabState();
}

class _ToursTabState extends State<ToursTab> {
  static const int _previewCount = 8;
  static const double _carouselHeight = 280;

  final ToursController controller = ToursController.instance;

  @override
  void initState() {
    super.initState();
    controller.fetchTours();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        _buildHeader()
            .animate()
            .fadeIn(duration: const Duration(milliseconds: 400))
            .slideY(begin: 0.1, end: 0),
        const SizedBox(height: 16),
        Obx(() {
          if (controller.tours.isEmpty) {
            if (controller.isLoading.value) return _buildLoading();
            return ToursMessageView(
              icon: controller.errorMessage.value.isNotEmpty
                  ? Icons.cloud_off
                  : Icons.landscape_outlined,
              message: controller.errorMessage.value.isNotEmpty
                  ? controller.errorMessage.value
                  : 'No tours available right now.',
              actionLabel: 'Try Again',
              onAction: controller.fetchTours,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCarousel().animate().fadeIn(
                    duration: const Duration(milliseconds: 400),
                  ),
              const SizedBox(height: 16),
              _buildViewAllButton(),
            ],
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: TColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: TColors.primary.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.landscape, color: TColors.iconclr, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Explore Pakistan Tours',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TColors.text,
                  ),
                ),
                Obx(
                  () => Text(
                    controller.tours.isEmpty
                        ? 'Book with confidence: No hidden charges'
                        : '${controller.tours.length} tours found  •  No hidden charges',
                    style: const TextStyle(fontSize: 12, color: TColors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel() {
    final tours = controller.tours.take(_previewCount).toList();
    return SizedBox(
      height: _carouselHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        itemCount: tours.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: 230,
          child: TourCard(tour: tours[index], compact: true),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    Widget box(double height, double width) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: TColors.background3,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return SizedBox(
      height: _carouselHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        itemCount: 2,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => Container(
          width: 230,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TColors.background3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                decoration: const BoxDecoration(
                  color: TColors.background3,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    box(14, 170),
                    const SizedBox(height: 8),
                    box(14, 110),
                    const SizedBox(height: 18),
                    box(38, double.infinity),
                  ],
                ),
              ),
            ],
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(begin: 0.5, end: 1, duration: const Duration(milliseconds: 700)),
      ),
    );
  }

  Widget _buildViewAllButton() {
    return SizedBox(
      height: AppConstants.buttonHeight + 8,
      child: ElevatedButton.icon(
        onPressed: () => Get.to(() => const ToursScreen()),
        style: ElevatedButton.styleFrom(
          backgroundColor: TColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
          ),
        ),
        icon: const Icon(Icons.explore),
        label: Text(
          'VIEW ALL TOURS (${controller.tours.length})',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
