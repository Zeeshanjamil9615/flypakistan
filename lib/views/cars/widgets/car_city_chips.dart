import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../utility/colors.dart';
import '../cars_controller.dart';

/// "All cities" plus one chip per city; sets [CarsController.selectedCity].
class CarCityChips extends StatelessWidget {
  final EdgeInsets padding;

  const CarCityChips({super.key, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final controller = CarsController.instance;
    return Obx(() {
      if (controller.cities.isEmpty) return const SizedBox.shrink();
      final List<String> options = ['', ...controller.cities];
      final String selected = controller.selectedCity.value;

      return SizedBox(
        height: 34 + padding.vertical,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: padding,
          itemCount: options.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final String city = options[index];
            final bool isSelected = city == selected;
            return GestureDetector(
              onTap: () => controller.selectedCity.value = city,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected ? TColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: isSelected ? TColors.primary : TColors.lightGrey,
                  ),
                ),
                child: Text(
                  city.isEmpty ? 'All cities' : city,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : TColors.text,
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
