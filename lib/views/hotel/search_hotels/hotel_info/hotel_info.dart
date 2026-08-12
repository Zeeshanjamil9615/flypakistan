import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ready_flights/services/api_service_hotel.dart';
import 'package:ready_flights/utility/colors.dart';
import 'package:ready_flights/views/hotel/search_hotels/hotel_info/hotel_images.dart';
import 'package:ready_flights/views/hotel/search_hotels/search_hotel_controller.dart';
import 'package:ready_flights/views/hotel/search_hotels/select_room/selectroom.dart';

class HotelInfoScreen extends StatefulWidget {
  final String hotelId;
  final Map<String, dynamic> hotelData;

  const HotelInfoScreen({
    Key? key,
    required this.hotelId,
    required this.hotelData,
  }) : super(key: key);

  @override
  State<HotelInfoScreen> createState() => _HotelInfoScreenState();
}

class _HotelInfoScreenState extends State<HotelInfoScreen> {
  final SearchHotelController controller = Get.find<SearchHotelController>();
  final ApiServiceHotel apiService = ApiServiceHotel();
  
  Map<String, dynamic>? hotelDetails;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    print("hotel 1");

    fetchHotelDetails();
    print("hotel 2");

  }

  Future<void> fetchHotelDetails() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final details = await apiService.fetchHotelDetails(widget.hotelId);
      
      setState(() {
        hotelDetails = details;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load hotel details. Please try again.';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.background,
      body: SafeArea(
        child: Stack( // Changed to Stack to overlay floating button
          children: [
            // Main content
            isLoading
                ? _buildLoadingWidget()
                : errorMessage != null
                    ? _buildErrorWidget()
                    : hotelDetails == null
                        ? _buildNoDataWidget()
                        : _buildHotelContent(),
            
            // Floating Select Room Button
            if (!isLoading && errorMessage == null && hotelDetails != null)
              _buildFloatingSelectRoomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(TColors.primary),
          ),
          SizedBox(height: 16),
          Text(
            'Loading hotel details...',
            style: TextStyle(
              color: TColors.text,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: TColors.red,
          ),
          const SizedBox(height: 16),
          Text(
            errorMessage ?? 'Something went wrong',
            style: const TextStyle(
              color: TColors.text,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: fetchHotelDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: TColors.primary,
              foregroundColor: TColors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hotel_outlined,
            size: 64,
            color: TColors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No hotel details available',
            style: TextStyle(
              color: TColors.text,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelContent() {
    final data = hotelDetails!['data'];
    if (data == null) return _buildNoDataWidget();

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(data),
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildHotelInfo(data),
              _buildImageGallery(data),
              _buildDescription(data),
              _buildAmenities(data),
              const SizedBox(height: 100), // Space for floating button
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(Map<String, dynamic> data) {
    final images = data['images'] as List<dynamic>? ?? [];
    final primaryImage = data['logo'] ?? 
        (images.isNotEmpty ? images[0] : 'assets/img/cardbg/broken-image.png');

    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: TColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: TColors.white),
        onPressed: () => Get.back(),
      ),
      actions: [
        if (images.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.photo_library, color: TColors.white),
            onPressed: () {
              Get.to(() => HotelImagesGalleryScreen(
                images: images.cast<String>(),
                hotelName: data['hotel_name'] ?? 'Hotel Gallery',
              ));
            },
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: primaryImage,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: TColors.grey.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(TColors.primary),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: TColors.grey.withOpacity(0.3),
                child: const Icon(
                  Icons.image_not_supported,
                  size: 50,
                  color: TColors.grey,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotelInfo(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['hotel_name'] ?? 'Unknown Hotel',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: TColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
               GestureDetector(
                      onTap: () {
                        Get.to(
                          () => MapScreen(
                            latitude:
                                double.tryParse(
                                   controller.lat.toString()
                                ) ??
                                0.0,
                            longitude:
                                double.tryParse(
                                  controller.lon.toString()
                                ) ??
                                0.0,
                            hotelName: '${controller.hotelName.toString()} Hotel',
                          ),
                        );
                      },
                      child: Icon(
                        Icons.location_on_rounded,
                        color: TColors.iconclr,
                        size: 30,
                      ),
                    ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${controller.hotelAddress()}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: TColors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
         if (controller.ratingstar.value > 0)
  Row(
    children: [
      ...List.generate(5, (index) {
        return Icon(
          index < controller.ratingstar.value
              ? Icons.star
              : Icons.star_border,
          color: Colors.amber,
          size: 20,
        );
      }),
      const SizedBox(width: 8),
      Text(
        '${controller.ratingstar.value} Stars',
        style: const TextStyle(
          fontSize: 14,
          color: TColors.text,
        ),
      ),
    ],
  ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(Map<String, dynamic> data) {
    final images = data['images'] as List<dynamic>? ?? [];
    
    if (images.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: TColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: TColors.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.photo_library,
                      color: TColors.iconclr,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Photos (${images.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: TColors.text,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    Get.to(() => HotelImagesGalleryScreen(
                      images: images.cast<String>(),
                      hotelName: data['hotel_name'] ?? 'Hotel Gallery',
                    ));
                  },
                  icon: const Icon(
                    Icons.fullscreen,
                    size: 16,
                    color: TColors.iconclr,
                  ),
                  label: const Text(
                    'View All',
                    style: TextStyle(
                      color: TColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 120,
            padding: const EdgeInsets.only(left: 16, bottom: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length > 6 ? 6 : images.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    Get.to(() => HotelImagesGalleryScreen(
                      images: images.cast<String>(),
                      hotelName: data['hotel_name'] ?? 'Hotel Gallery',
                      initialIndex: index,
                    ));
                  },
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: images[index],
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                color: TColors.grey.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(TColors.primary),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                color: TColors.grey.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.image_not_supported,
                                color: TColors.grey,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                        if (index == 5 && images.length > 6)
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '+${images.length - 6}',
                                    style: const TextStyle(
                                      color: TColors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'more',
                                    style: TextStyle(
                                      color: TColors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(Map<String, dynamic> data) {
    final description = data['description'] as String? ?? '';
    
    if (description.isEmpty) return const SizedBox.shrink();

    // Remove HTML tags and decode HTML entities
    String cleanDescription = description
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&#x27;', "'")
        .replaceAll('&quot;', '"')
        .trim();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TColors.primary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: TColors.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description,
                color: TColors.iconclr,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: TColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            cleanDescription,
            style: const TextStyle(
              fontSize: 14,
              color: TColors.text,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenities(Map<String, dynamic> data) {
    final amenities = data['uhi_amenities'] as List<dynamic>? ?? [];
    
    if (amenities.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TColors.primary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: TColors.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.star,
                color: TColors.iconclr,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Amenities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: TColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: amenities.map<Widget>((amenity) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: TColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: TColors.primary.withOpacity(0.3)),
                ),
                child: Text(
                  amenity.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: TColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

Widget _buildFloatingSelectRoomButton() {
  return Positioned(
    bottom: 20,
    left: 16,
    right: 16,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: TColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () async {
          // Set controller values
          controller.ratingstar.value = widget.hotelData['rating']?.toInt() ?? 0;
          controller.hotelCode.value = widget.hotelData['hotelCode'] ?? '';
          controller.hotelCity.value = widget.hotelData['hotelCity'] ?? '';
          controller.lat.value = widget.hotelData['latitude']?.toString() ?? '';
          controller.lon.value = widget.hotelData['longitude']?.toString() ?? '';
          controller.hotelAddress.value = widget.hotelData['address'] ?? '';
          
          controller.roomsdata.clear();
          
          // Show loading indicator
          Get.dialog(
            const Center(
              child: CircularProgressIndicator(color: TColors.primary),
            ),
            barrierDismissible: false,
          );
          
          // Own-DB hotels load their rooms from our own database, third-party
          // hotels from the Arabian RoomDetails API.
          await ApiServiceHotel().fetchRoomsForHotel(widget.hotelData);
          
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
                    Icon(Icons.info_outline, color: TColors.iconclr, size: 28),
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
            // No filterhotler() here: it rebuilds `originalHotels` from the
            // currently visible list, which would silently drop every hotel the
            // active filter/search hid and reset the user's sorting.
            Get.to(() => const SelectRoomScreen());
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: TColors.primary,
          foregroundColor: TColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 4)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bed,
              size: 20,
              color: TColors.white,
            ),
            const SizedBox(width: 8),
            const Text(
              'Select Room',
              style: TextStyle(
                fontSize: 18,
                color: TColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
  );
} 
}
class MapScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final CameraPosition initialPosition = CameraPosition(
      target: LatLng(latitude, longitude),
      zoom: 15,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: const Icon(Icons.arrow_back, color: TColors.iconclr),
        ),
      ),
      body: SafeArea(
        top: false,
        child: GoogleMap(
          initialCameraPosition: initialPosition,
          markers: {
            Marker(
              markerId: MarkerId(hotelName),
              position: LatLng(latitude, longitude),
              infoWindow: InfoWindow(title: hotelName),
            ),
          },
        ),
      ),
    );
  }
}