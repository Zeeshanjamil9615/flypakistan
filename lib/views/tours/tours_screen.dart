import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utility/colors.dart';
import 'tours_controller.dart';
import 'widgets/tour_card.dart';
import 'widgets/tours_message_view.dart';

/// All tours with search and price sorting, like the website's tours page.
class ToursScreen extends StatefulWidget {
  const ToursScreen({super.key});

  @override
  State<ToursScreen> createState() => _ToursScreenState();
}

class _ToursScreenState extends State<ToursScreen> {
  final ToursController controller = ToursController.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.searchQuery.value = '';
    controller.sort.value = TourSort.recommended;
    if (controller.tours.isEmpty) controller.fetchTours();
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
            'Explore Tours',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: Obx(() {
                if (controller.tours.isEmpty) {
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
                          : 'No tours available right now.',
                      actionLabel: 'Try Again',
                      onAction: controller.fetchTours,
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

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  controller.searchQuery.value = value;
                  setState(() {}); // toggles the clear button
                },
                decoration: InputDecoration(
                  hintText: 'Search tours or cities',
                  hintStyle: const TextStyle(
                    color: TColors.placeholder,
                    fontSize: 14,
                  ),
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
            ),
          ),
          const SizedBox(width: 10),
          _buildSortMenu(),
        ],
      ),
    );
  }

  Widget _buildSortMenu() {
    return Obx(
      () => PopupMenuButton<TourSort>(
        tooltip: 'Sort tours',
        initialValue: controller.sort.value,
        onSelected: (value) => controller.sort.value = value,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        itemBuilder: (context) => TourSort.values
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
              color: controller.sort.value == TourSort.recommended
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
                color: controller.sort.value == TourSort.recommended
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
    final tours = controller.visibleTours;
    return RefreshIndicator(
      color: TColors.primary,
      onRefresh: controller.fetchTours,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        // +1 for the results header.
        itemCount: tours.isEmpty ? 2 : tours.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index == 0) return _buildResultsHeader(tours.length);
          if (tours.isEmpty) {
            return ToursMessageView(
              icon: Icons.search_off,
              message:
                  'No tours match "${controller.searchQuery.value.trim()}".',
              actionLabel: 'Clear Search',
              onAction: () {
                _clearSearch();
                setState(() {});
              },
            );
          }
          return TourCard(tour: tours[index - 1]);
        },
      ),
    );
  }

  Widget _buildResultsHeader(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count ${count == 1 ? 'Tour' : 'Tours'} found',
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
