import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utility/colors.dart';
import '../tours/widgets/tours_message_view.dart';
import 'cars_controller.dart';
import 'widgets/car_card.dart';
import 'widgets/car_city_chips.dart';

/// All rental cars with city filter, search and price sorting, like the
/// website's "Rent a Car in Pakistan" page. Opens on the city picked in the
/// home tab.
class CarsScreen extends StatefulWidget {
  const CarsScreen({super.key});

  @override
  State<CarsScreen> createState() => _CarsScreenState();
}

class _CarsScreenState extends State<CarsScreen> {
  final CarsController controller = CarsController.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.searchQuery.value = '';
    controller.sort.value = CarSort.recommended;
    if (controller.cars.isEmpty) controller.fetchCars();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    controller.searchQuery.value = '';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: TColors.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: TColors.primary,
          foregroundColor: Colors.white,
          title: const Text(
            'Rent a Car',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
        ),
        body: Column(
          children: [
            _buildFilters(),
            Expanded(
              child: Obx(() {
                if (controller.cars.isEmpty) {
                  if (controller.isLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator(color: TColors.primary),
                    );
                  }
                  return Center(
                    child: ToursMessageView(
                      icon: Icons.cloud_off,
                      message: controller.errorMessage.value.isNotEmpty
                          ? controller.errorMessage.value
                          : 'No cars available right now.',
                      actionLabel: 'Try Again',
                      onAction: controller.fetchCars,
                    ),
                  );
                }
                return _buildList();
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildSearchField()),
                const SizedBox(width: 10),
                _buildSortMenu(),
              ],
            ),
          ),
          const CarCityChips(padding: EdgeInsets.fromLTRB(16, 10, 16, 0)),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          controller.searchQuery.value = value;
          setState(() {}); // toggles the clear button
        },
        decoration: InputDecoration(
          hintText: 'Search cars or cities',
          hintStyle: const TextStyle(color: TColors.placeholder, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: TColors.iconclr),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: TColors.grey,
                  onPressed: () {
                    _clearSearch();
                    setState(() {});
                  },
                ),
          filled: true,
          fillColor: TColors.inputFieldBackground,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: TColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildSortMenu() {
    return Obx(
      () => PopupMenuButton<CarSort>(
        tooltip: 'Sort cars',
        initialValue: controller.sort.value,
        onSelected: (value) => controller.sort.value = value,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        itemBuilder: (context) => CarSort.values
            .map(
              (option) => PopupMenuItem(
                value: option,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: option == controller.sort.value
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: option == controller.sort.value
                              ? TColors.primary
                              : TColors.text,
                        ),
                      ),
                    ),
                    if (option == controller.sort.value)
                      const Icon(Icons.check, size: 18, color: TColors.primary),
                  ],
                ),
              ),
            )
            .toList(),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: controller.sort.value == CarSort.recommended
                  ? TColors.lightGrey
                  : TColors.primary,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sort,
                size: 20,
                color: controller.sort.value == CarSort.recommended
                    ? TColors.grey
                    : TColors.primary,
              ),
              const SizedBox(width: 4),
              const Text(
                'Sort',
                style: TextStyle(fontSize: 13, color: TColors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final cars = controller.visibleCars;
    final String query = controller.searchQuery.value.trim();
    return RefreshIndicator(
      color: TColors.primary,
      onRefresh: controller.fetchCars,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        // +1 for the results header.
        itemCount: cars.isEmpty ? 2 : cars.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index == 0) return _buildResultsHeader(cars.length);
          if (cars.isEmpty) {
            return query.isNotEmpty
                ? ToursMessageView(
                    icon: Icons.search_off,
                    message: 'No cars match "$query".',
                    actionLabel: 'Clear Search',
                    onAction: () {
                      _clearSearch();
                      setState(() {});
                    },
                  )
                : ToursMessageView(
                    icon: Icons.directions_car_outlined,
                    message: 'No cars available in this city right now.',
                    actionLabel: 'Show All Cities',
                    onAction: () => controller.selectedCity.value = '',
                  );
          }
          return CarCard(car: cars[index - 1]);
        },
      ),
    );
  }

  Widget _buildResultsHeader(int count) {
    final String city = controller.selectedCity.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count ${count == 1 ? 'Car' : 'Cars'} found'
          '${city.isEmpty ? '' : ' in $city'}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: TColors.text,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(Icons.verified_outlined, size: 14, color: TColors.iconclr),
            const SizedBox(width: 4),
            Text(
              'Book with confidence: No hidden charges',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }
}
