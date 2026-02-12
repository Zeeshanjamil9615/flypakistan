import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:ready_flights/utility/colors.dart';
import 'package:ready_flights/views/hotel/hotel/hotel_date_controller.dart';
import 'package:ready_flights/views/hotel/search_hotels/hotel_info/hotel_info.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';

import '../../../services/api_service_hotel.dart';
import 'search_hotel_controller.dart';
import 'select_room/selectroom.dart';

class HotelScreen extends StatefulWidget {
  const HotelScreen({super.key});

  @override
  State<HotelScreen> createState() => _HotelScreenState();
}

class _HotelScreenState extends State<HotelScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize the filter data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final SearchHotelController controller =
          Get.find<SearchHotelController>();
      controller.filterhotler();
    });
  }

  @override
  Widget build(BuildContext context) {
    final SearchHotelController controller = Get.find<SearchHotelController>();

    Widget buildRatingBar(double rating) {
      return RatingBarIndicator(
        rating: rating,
        itemBuilder:
            (context, index) => const Icon(Icons.star, color: Colors.orange),
        itemCount: 5,
        itemSize: 20.0,
        direction: Axis.horizontal,
      );
    }

    void showFilterSheet(BuildContext context) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return Obx(
            () => Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter by Rating',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: List.generate(6, (index) {
                        if (index == 5) {
                          return Row(
                            children: [
                              Checkbox(
                                value:
                                    !controller.selectedRatings.contains(true),
                                onChanged: (value) {
                                  if (value == true) {
                                    controller.resetFilters();
                                  }
                                },
                                activeColor: TColors.primary,
                              ),
                              const Text('All Hotels'),
                            ],
                          );
                        }
                        int starRating = 5 - index;
                        return Row(
                          children: [
                            Checkbox(
                              value: controller.selectedRatings[index],
                              onChanged: (value) {
                                controller.selectedRatings[index] = value!;
                              },
                              activeColor: TColors.primary,
                            ),
                            buildRatingBar(starRating.toDouble()),
                            const SizedBox(width: 8),
                            Text(
                              '(${controller.getHotelCountByRating(starRating)})',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            controller.resetFilters();
                            Get.back();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Reset'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            controller.filterByRating();
                            Get.back();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: TColors.background,
      appBar: AppBar(
        surfaceTintColor: TColors.background,
        backgroundColor: TColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Hotels',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header Section with Search Text Field and Buttons - Only show when not loading
          Obx(() {
            if (controller.isLoading.value) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Text Field
                  SizedBox(
                    height: 50,
                    child: TextField(
                      style: const TextStyle(color: Colors.black87),
                      onChanged: (value) {
                        controller.searchHotelsByName(value);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search for hotels...',
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        prefixIcon: Icon(Icons.search, color: TColors.primary),
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: TColors.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Buttons: Filter, Sort, Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildButton(context, Icons.filter_list, 'Filter', () {
                        showFilterSheet(context);
                      }),
                      _buildButton(context, Icons.sort, 'Sort', () {
                        _showSortOptionsBottomSheet(context, controller);
                      }),
                      _buildButton(context, Icons.attach_money, 'Price', () {
                        _showPriceRangeBottomSheet(context, controller);
                      }),
                    ],
                  ),
                ],
              ),
            );
          }),
          // Hotel List Section
          Expanded(
            child: Obx(() {
              // Show skeleton loader when loading
              if (controller.isLoading.value) {
                return _buildInitialLoadingState(context);
              }
              
              var hotels = controller.hotels;
              if (hotels.isEmpty) {
                return const Center(
                  child: Text(
                    'No hotels found.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }
              return ListView.builder(
                itemCount: hotels.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  return HotelCard(hotel: hotels[index]);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: Colors.grey.shade600),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.normal,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey.shade600,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  void _showSortOptionsBottomSheet(
    BuildContext context,
    SearchHotelController controller,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        String selectedOption = 'Recommended';

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sort Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'Price (low to high)',
                    groupValue: selectedOption,
                    onChanged: (value) {
                      setState(() {
                        selectedOption = value!;
                      });
                    },
                    title: const Text('Price (low to high)'),
                    activeColor: TColors.primary,
                  ),
                  RadioListTile<String>(
                    value: 'Price (high to low)',
                    groupValue: selectedOption,
                    onChanged: (value) {
                      setState(() {
                        selectedOption = value!;
                      });
                    },
                    title: const Text('Price (high to low)'),
                    activeColor: TColors.primary,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          controller.resetFilters();
                          Get.back();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Reset'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          controller.sortHotels(selectedOption);
                          Get.back();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TColors.primary,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPriceRangeBottomSheet(
    BuildContext context,
    SearchHotelController controller,
  ) {
    // Calculate min and max prices dynamically from the original hotels list
    final prices =
        controller.originalHotels
            .map(
              (hotel) =>
                  double.tryParse(
                    hotel['price'].toString().replaceAll(',', '').trim(),
                  ) ??
                  0.0,
            )
            .toList();

    double minPrice =
        prices.isNotEmpty ? prices.reduce((a, b) => a < b ? a : b) : 0.0;
    double maxPrice =
        prices.isNotEmpty ? prices.reduce((a, b) => a > b ? a : b) : 0.0;

    double lowerValue = minPrice;
    double upperValue = maxPrice;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Price Range',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  RangeSlider(
                    values: RangeValues(lowerValue, upperValue),
                    min: minPrice,
                    max: maxPrice,
                    divisions: 10,
                    labels: RangeLabels(
                      '\$${lowerValue.round()}',
                      '\$${upperValue.round()}',
                    ),
                    onChanged: (values) {
                      setState(() {
                        lowerValue = values.start;
                        upperValue = values.end;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            lowerValue = minPrice;
                            upperValue = maxPrice;
                          });
                          controller.resetFilters();
                          Get.back();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Reset'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          controller.filterByPriceRange(lowerValue, upperValue);
                          Get.back();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TColors.primary,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInitialLoadingState(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSkeletonBar(widthFactor: 0.6),
            const SizedBox(height: 12),
            _buildSkeletonBar(widthFactor: 0.45),
            const SizedBox(height: 24),
            _buildLoadingInfoCard(context),
            const SizedBox(height: 24),
            ...List.generate(3, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildSkeletonCard(),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingInfoCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/hotel-search.svg',
            height: 160,
          ),
          const SizedBox(height: 24),
          const Text(
            'Please wait while we are searching best hotel deals for you',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: TColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Our payment plans are flexible—you can pay cash, bank transfer, or choose to pay by credit card.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: TColors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonBar({required double widthFactor}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade200,
              Colors.grey.shade100,
              Colors.grey.shade200,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonLine(widthFactor: 0.5),
          const SizedBox(height: 12),
          _buildSkeletonLine(widthFactor: 0.8),
          const SizedBox(height: 12),
          _buildSkeletonLine(widthFactor: 0.65),
        ],
      ),
    );
  }

  Widget _buildSkeletonLine({required double widthFactor}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade200,
        ),
      ),
    );
  }
}

class HotelCard extends StatelessWidget {
  final Map<String, dynamic> hotel;

  HotelCard({super.key, required this.hotel});

  final SearchHotelController controller = Get.find<SearchHotelController>();
  final HotelDateController dateController = Get.find<HotelDateController>();

  // Extract the select room functionality into a separate method
  void _selectRoom() async {
    controller.ratingstar.value = (hotel['rating'] as double).toInt();
    controller.hotelCode.value = hotel['hotelCode'];
    controller.hotelCity.value = hotel['hotelCity'];
    controller.lat.value = hotel['latitude'];
    controller.lon.value = hotel['longitude'];
    controller.hotelAddress.value = hotel['address'] ?? "";
    // controller.hotelid.value=(hotel['code'] as double).toInt()??0;

    controller.roomsdata.clear();
          
          // Show loading indicator
          Get.dialog(
            const Center(
              child: CircularProgressIndicator(color: TColors.primary),
            ),
            barrierDismissible: false,
          );
          
          await ApiServiceHotel().fetchRoomDetails(
          hotel['hotelCode'] ?? '',
            controller.sessionId.value,
          );
          
          // Close loading dialog
          Get.back();
          
          // Check if rooms are available
          if (controller.roomsdata.isEmpty) {
            Get.dialog(
              AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(Icons.info_outline, color: TColors.third, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'No Rooms Available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: TColors.text,
                      ),
                    ),
                  ],
                ),
                content: Text(
                  'Sorry, there are no rooms available for this hotel at the moment. Please try another hotel or different dates.',
                  style: TextStyle(
                    fontSize: 14,
                    color: TColors.text,
                    height: 1.5,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      try {
                        Get.back();
                      } catch (e) {
                        // Dialog already closed
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: TColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      'OK',
                      style: TextStyle(
                        color: TColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              barrierDismissible: false,
            );
          } else {
            controller.filterhotler();
            Get.to(() => const SelectRoomScreen());
          }

    // ApiServiceHotel().fetchHotelDetails(hotel['hotelCode']);
    // controller.filterhotler();
    
  
    // Get.to(
    //   () => HotelInfoScreen(
    //     hotelId: hotel['hotelCode'],
    //     hotelData: hotel as Map<String, dynamic>,
    //   ),
      
    // );
  }

  @override
  Widget build(BuildContext context) {
    // When card is shown (e.g. on scroll), fetch hotel image by hotel_id if not yet loaded
    final hotelCode = hotel['hotelCode']?.toString() ?? '';
    if (hotelCode.isNotEmpty) {
      controller.ensureHotelImage(hotelCode);
    }
    return InkWell(
      onTap: _selectRoom,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Hotel Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildHotelImage(),
            ),
            const SizedBox(height: 16),
            // Hotel Name and Location
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hotel['name'] ?? 'Unknown Hotel',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hotel['address'] ?? 'Address not available',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Map icon button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Get.to(
                        () => MapScreen(
                          latitude:
                              double.tryParse(
                                hotel['latitude']?.toString() ?? '',
                              ) ??
                              0.0,
                          longitude:
                              double.tryParse(
                                hotel['longitude']?.toString() ?? '',
                              ) ??
                              0.0,
                          hotelName: hotel['name'] ?? 'Unknown Hotel',
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: TColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 12),
            // Rating and Price Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    RatingBar.builder(
                      initialRating: (hotel['rating'] ?? 3.0).toDouble(),
                      minRating: 1,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemSize: 14,
                      itemPadding: const EdgeInsets.symmetric(horizontal: 1.0),
                      itemBuilder:
                          (context, _) => const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 14,
                          ),
                      onRatingUpdate: (rating) {},
                      ignoreGestures: true,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(hotel['rating'] ?? 3.0).toDouble()}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'PKR ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Colors.black54,
                        ),
                      ),
                      TextSpan(
                        text: NumberFormat('#,###').format(
                          ((hotel['price'] ?? 0.0) /
                                  dateController.nights.value)
                              .round(),
                        ),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotelImage() {
    final hotelCode = hotel['hotelCode']?.toString() ?? '';
    // Priority: 1) getHotelsDetails (hotel_id) API, 2) search API image, 3) asset
    return Obx(() {
      String imageUrl = controller.hotelImagesByCode.value[hotelCode] ??
          hotel['image']?.toString() ??
          '';

      // Check if the image is a full URL (starts with http/https)
      if (imageUrl.startsWith('http')) {
        return CachedNetworkImage(
        imageUrl: imageUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) {
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(color: TColors.primary),
            ),
          );
        },
        errorWidget: (context, url, error) {
          return Image.asset(
            'assets/img/cardbg/broken-image.png',
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          );
        },
      );
    }
    // Check if the image is a relative path starting with '/'
    if (imageUrl.startsWith('/')) {
      String fullImageUrl = 'https://static.giinfotech.ae/medianew$imageUrl';
      return CachedNetworkImage(
        imageUrl: fullImageUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) {
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(color: TColors.primary),
            ),
          );
        },
        errorWidget: (context, url, error) {
          return Image.asset(
            'assets/img/cardbg/broken-image.png',
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          );
        },
      );
    }
    // Empty or non-URL: use default asset
    String assetPath =
        imageUrl.isEmpty ? 'assets/images/hotel1.jpg' : imageUrl;
    return Image.asset(
      assetPath,
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/img/cardbg/broken-image.png',
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      },
    );
    });
  }
}

class MapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String hotelName;

  const MapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.hotelName,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  final SearchHotelController controller = Get.find<SearchHotelController>();
  final HotelDateController dateController = Get.find<HotelDateController>();

  @override
  void initState() {
    super.initState();
    _createMarkers();
  }

  Future<void> _createMarkers() async {
    markers.clear();

    // Add the selected hotel marker with price
    final selectedHotelPrice = _getSelectedHotelPrice();
    final selectedPricePerNight =
        selectedHotelPrice != null
            ? (selectedHotelPrice / dateController.nights.value).round()
            : 0;

    final selectedMarkerIcon = await _createPriceMarker(
      'PKR $selectedPricePerNight',
      true, // isSelected
    );

    markers.add(
      Marker(
        markerId: MarkerId('selected_${widget.hotelName}'),
        position: LatLng(widget.latitude, widget.longitude),
        icon: selectedMarkerIcon,
        onTap: () {
          _showHotelDetails(_getSelectedHotelData(), 0.0, isSelected: true);
        },
      ),
    );

    // Add nearby hotels markers with prices
    for (var hotel in controller.originalHotels) {
      double lat = double.tryParse(hotel['latitude']?.toString() ?? '') ?? 0.0;
      double lon = double.tryParse(hotel['longitude']?.toString() ?? '') ?? 0.0;
      String name = hotel['name'] ?? 'Unknown Hotel';

      // Skip if it's the same hotel or coordinates are invalid
      if (name == widget.hotelName || (lat == 0.0 && lon == 0.0)) continue;

      // Calculate distance to filter nearby hotels (within ~50km radius)
      double distance = _calculateDistance(
        widget.latitude,
        widget.longitude,
        lat,
        lon,
      );

      if (distance <= 50) {
        // Show hotels within 50km
        double hotelPrice =
            double.tryParse(
              hotel['price'].toString().replaceAll(',', '').trim(),
            ) ??
            0.0;

        int pricePerNight =
            hotelPrice > 0
                ? (hotelPrice / dateController.nights.value).round()
                : 0;

        final nearbyMarkerIcon = await _createPriceMarker(
          pricePerNight > 0 ? 'PKR $pricePerNight' : 'N/A',
          false, // isSelected
        );

        markers.add(
          Marker(
            markerId: MarkerId('nearby_$name'),
            position: LatLng(lat, lon),
            icon: nearbyMarkerIcon,
            onTap: () {
              _showHotelDetails(hotel, distance);
            },
          ),
        );
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<BitmapDescriptor> _createPriceMarker(
    String price,
    bool isSelected,
  ) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint =
        Paint()..color = isSelected ? Colors.red : TColors.primary;
    final Paint borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    const double width = 150;
    const double height = 80;
    const double borderRadius = 22;

    // Draw background with rounded rectangle
    final RRect rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      const Radius.circular(borderRadius),
    );

    canvas.drawRRect(rect, paint);
    canvas.drawRRect(rect, borderPaint);

    // Draw text
    final textStyle = ui.TextStyle(
      color: Colors.white,
      fontSize: 30,
      fontWeight: FontWeight.bold,
    );
    final paragraphStyle = ui.ParagraphStyle(textAlign: TextAlign.center);
    final paragraphBuilder =
        ui.ParagraphBuilder(paragraphStyle)
          ..pushStyle(textStyle)
          ..addText(price);
    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: width));

    canvas.drawParagraph(paragraph, Offset(0, (height - paragraph.height) / 2));

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }

  double? _getSelectedHotelPrice() {
    for (var hotel in controller.originalHotels) {
      if (hotel['name'] == widget.hotelName) {
        return double.tryParse(
          hotel['price'].toString().replaceAll(',', '').trim(),
        );
      }
    }
    return null;
  }

  Map<String, dynamic> _getSelectedHotelData() {
    for (var hotel in controller.originalHotels) {
      if (hotel['name'] == widget.hotelName) {
        return hotel;
      }
    }
    return {
      'name': widget.hotelName,
      'address': 'Address not available',
      'rating': 3.0,
      'price': _getSelectedHotelPrice() ?? 0.0,
    };
  }

  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  void _showHotelDetails(
    Map hotel,
    double distance, {
    bool isSelected = false,
  }) {
    double hotelPrice =
        double.tryParse(hotel['price'].toString().replaceAll(',', '').trim()) ??
        0.0;

    int pricePerNight =
        hotelPrice > 0 ? (hotelPrice / dateController.nights.value).round() : 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Make the entire hotel info container clickable
              GestureDetector(
                onTap: () {
                  // Close the bottom sheet first
                  Get.back();

                  // Navigate to hotel details
                  _navigateToHotelDetails(hotel);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Hotel Image on left side - also clickable
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildSmallHotelImage(hotel),
                      ),
                      const SizedBox(width: 12),
                      // Hotel details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hotel['name'] ?? 'Unknown Hotel',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hotel['address'] ?? 'Address not available',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!isSelected && distance > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${distance.toStringAsFixed(1)} km away',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Arrow icon to indicate clickability and selected badge
                      Column(
                        children: [
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Selected',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: TColors.primary,
                            size: 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Rating and Price Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Rating
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: (hotel['rating'] ?? 3.0).toDouble(),
                        itemBuilder:
                            (context, index) =>
                                const Icon(Icons.star, color: Colors.orange),
                        itemCount: 5,
                        itemSize: 16.0,
                        direction: Axis.horizontal,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(hotel['rating'] ?? 3.0).toDouble()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Price with larger text
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'PKR $pricePerNight',
                        style: TextStyle(
                          fontSize: 22,
                          color: TColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'per night',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // View Details Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back(); // Close the bottom sheet
                    _navigateToHotelDetails(hotel);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Add this new method to handle navigation to hotel details
  void _navigateToHotelDetails(Map hotel) {
    // Update controller values with selected hotel data
    controller.ratingstar.value = (hotel['rating'] as double).toInt();
    controller.hotelCode.value = hotel['hotelCode'];
    controller.hotelCity.value = hotel['hotelCity'];
    controller.lat.value = hotel['latitude'];
    controller.lon.value = hotel['longitude'];
    controller.hotelAddress.value = hotel['address'] ?? "";

    // Clear previous room data
    controller.roomsdata.clear();

    // Fetch hotel details and navigate
    ApiServiceHotel().fetchHotelDetails(hotel['hotelCode']);
    controller.filterhotler();

    Get.off(
      () => HotelInfoScreen(
        hotelId: hotel['hotelCode'],
        hotelData: hotel as Map<String, dynamic>,
      ),
    );
  }

  // Helper method to build small hotel image
  Widget _buildSmallHotelImage(Map hotel) {
    String imageUrl = hotel['image'] ?? '';

    Widget imageWidget;

    // Check if the image is a full URL (starts with http/https)
    if (imageUrl.startsWith('http')) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        placeholder:
            (context, url) => Container(
              width: 60,
              height: 60,
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(
                  color: TColors.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
        errorWidget:
            (context, url, error) => Image.asset(
              'assets/img/cardbg/broken-image.png',
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
      );
    }
    // Check if the image is a relative path starting with '/'
    else if (imageUrl.startsWith('/')) {
      String fullImageUrl = 'https://static.giinfotech.ae/medianew$imageUrl';
      imageWidget = CachedNetworkImage(
        imageUrl: fullImageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        placeholder:
            (context, url) => Container(
              width: 60,
              height: 60,
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(
                  color: TColors.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
        errorWidget:
            (context, url, error) => Image.asset(
              'assets/img/cardbg/broken-image.png',
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
      );
    }
    // If imageUrl is empty or doesn't match above conditions, use default asset
    else {
      String assetPath =
          imageUrl.isEmpty ? 'assets/images/hotel1.jpg' : imageUrl;
      imageWidget = Image.asset(
        assetPath,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) => Image.asset(
              'assets/img/cardbg/broken-image.png',
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
      );
    }

    return imageWidget;
  }

  @override
  Widget build(BuildContext context) {
    final CameraPosition initialPosition = CameraPosition(
      target: LatLng(widget.latitude, widget.longitude),
      zoom: 16, // Adjusted zoom to show more area with price markers
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hotel Location & Prices',
          style: TextStyle(color: TColors.primary),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: Icon(Icons.arrow_back, color: TColors.primary),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _showLegend();
            },
            icon: Icon(Icons.info_outline, color: TColors.primary),
          ),
          // IconButton(
          //   onPressed: () {
          //     _togglePriceDisplay();
          //   },
          //   icon: Icon(Icons.monetization_on, color: TColors.primary),
          // ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: initialPosition,
        markers: markers,
        onMapCreated: (GoogleMapController controller) {
          mapController = controller;
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "refresh",
            onPressed: () {
              _createMarkers();
            },
            backgroundColor: TColors.primary,
            mini: true,
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "zoom_out",
            onPressed: () {
              if (markers.isNotEmpty) {
                _fitAllMarkers();
              }
            },
            backgroundColor: TColors.primary,
            child: const Icon(Icons.zoom_out_map, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showLegend() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Map Legend'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Selected Hotel'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: TColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Nearby Hotels'),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Price Information:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('• Prices shown are per night'),
              const Text('• Tap markers for hotel details'),
              const Text('• Hotels within 50km radius shown'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                try {
                  Get.back();
                } catch (e) {
                  // Dialog already closed
                }
              },
              child: Text('OK', style: TextStyle(color: TColors.primary)),
            ),
          ],
        );
      },
    );
  }

  void _togglePriceDisplay() {
    // This function could be used to toggle between different price display modes
    // For now, it refreshes the markers
    _createMarkers();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Prices updated!'),
        backgroundColor: TColors.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _fitAllMarkers() {
    if (mapController == null || markers.isEmpty) return;

    LatLngBounds bounds = _createBounds(
      markers.map((marker) => marker.position).toList(),
    );

    mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        100,
      ), // Increased padding for price markers
    );
  }

  LatLngBounds _createBounds(List<LatLng> positions) {
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (LatLng position in positions) {
      minLat = min(minLat, position.latitude);
      maxLat = max(maxLat, position.latitude);
      minLng = min(minLng, position.longitude);
      maxLng = max(maxLng, position.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
