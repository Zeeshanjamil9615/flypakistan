import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../utility/app_constants.dart';
import '../../utility/colors.dart';
import '../tours/widgets/tours_message_view.dart';
import 'cars_controller.dart';
import 'cars_screen.dart';
import 'widgets/car_card.dart';
import 'widgets/car_city_chips.dart';

/// Content of the "Cars" tab in the home booking card: city filter, a
/// swipeable preview of the cars and a button to the full list.
///
/// Cars are (re)fetched every time the tab is opened; cached cars stay on
/// screen while the refresh runs.
class CarsTab extends StatefulWidget {
  const CarsTab({super.key});

  @override
  State<CarsTab> createState() => _CarsTabState();
}

class _CarsTabState extends State<CarsTab> {
  static const int _previewCount = 8;
  static const double _carouselHeight = 295;

  final CarsController controller = CarsController.instance;

  @override
  void initState() {
    super.initState();
    controller.fetchCars();
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
          if (controller.cars.isEmpty) {
            if (controller.isLoading.value) return _buildLoading();
            return ToursMessageView(
              icon: controller.errorMessage.value.isNotEmpty
                  ? Icons.cloud_off
                  : Icons.directions_car_outlined,
              message: controller.errorMessage.value.isNotEmpty
                  ? controller.errorMessage.value
                  : 'No cars available right now.',
              actionLabel: 'Try Again',
              onAction: controller.fetchCars,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CarCityChips(),
              const SizedBox(height: 10),
              // Keyed by city so switching city scrolls back to the start
              // and fades the new cars in.
              _buildCarousel()
                  .animate(key: ValueKey(controller.selectedCity.value))
                  .fadeIn(duration: const Duration(milliseconds: 400)),
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
          const Icon(Icons.directions_car, color: TColors.iconclr, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rent a Car in Pakistan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TColors.text,
                  ),
                ),
                Obx(
                  () => Text(
                    controller.cars.isEmpty
                        ? 'Book with confidence: No hidden charges'
                        : '${controller.cars.length} cars in '
                            '${controller.cities.length} cities  •  No hidden charges',
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
    final cars = controller.carsInCity.take(_previewCount).toList();
    return SizedBox(
      height: _carouselHeight,
      child: ListView.separated(
        key: ValueKey(controller.selectedCity.value),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        itemCount: cars.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: 230,
          child: CarCard(car: cars[index], compact: true),
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TColors.background3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              box(100, double.infinity),
              const SizedBox(height: 12),
              box(14, 150),
              const SizedBox(height: 8),
              box(12, 110),
              const SizedBox(height: 12),
              box(44, double.infinity),
              const Spacer(),
              box(38, double.infinity),
            ],
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(begin: 0.5, end: 1, duration: const Duration(milliseconds: 700)),
      ),
    );
  }

  Widget _buildViewAllButton() {
    final String city = controller.selectedCity.value;
    final int count = controller.carsInCity.length;
    return SizedBox(
      height: AppConstants.buttonHeight + 8,
      child: ElevatedButton.icon(
        onPressed: () => Get.to(() => const CarsScreen()),
        style: ElevatedButton.styleFrom(
          backgroundColor: TColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
          ),
        ),
        icon: const Icon(Icons.car_rental),
        label: Text(
          city.isEmpty
              ? 'VIEW ALL CARS ($count)'
              : 'VIEW ALL IN ${city.toUpperCase()} ($count)',
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
