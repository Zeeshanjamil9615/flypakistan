import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:ready_flights/services/api_service_hotel.dart';
import 'package:ready_flights/services/hotel_merge_util.dart';

class SearchHotelController extends GetxController {
  // Define the hotels list with explicit type
  final RxList<Map<String, dynamic>> hotels = <Map<String, dynamic>>[].obs;

  // Observable lists with explicit types
  final RxList<Map<String, dynamic>> filteredHotels =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> originalHotels =
      <Map<String, dynamic>>[].obs;
  final RxList<bool> selectedRatings = List<bool>.filled(5, false).obs;
  
  // Loading state
  final isLoading = false.obs;

  var dio = Dio();

  // Initialize the filter data - call this after fetching hotels.
  // NOTE: only call this right after a new search result is loaded — it rebuilds
  // `originalHotels` from the current list, so calling it while a filter is
  // applied would make the filtered subset the new full list.
  void filterhotler() {
    // Take a snapshot of the latest API result and normalize default ordering
    final List<Map<String, dynamic>> snapshot = List<Map<String, dynamic>>.from(
      hotels,
    );

    // Default "Recommended" sorting so list is not random by default.
    // Primary: source — third-party (Arabian) hotels always above our own-DB ones
    // Secondary: higher rating first
    // Tertiary: lower price first (stable tie-breaker)
    snapshot.sort((a, b) {
      final int sourceCompare = _sourceRank(a).compareTo(_sourceRank(b));
      if (sourceCompare != 0) return sourceCompare;

      final double ratingA = _parseRating(a['rating']);
      final double ratingB = _parseRating(b['rating']);
      final int ratingCompare = ratingB.compareTo(ratingA); // desc
      if (ratingCompare != 0) return ratingCompare;

      return _sortablePrice(a).compareTo(_sortablePrice(b)); // asc
    });

    originalHotels.value = snapshot;
    filteredHotels.value = List<Map<String, dynamic>>.from(snapshot);
    hotels.value = List<Map<String, dynamic>>.from(snapshot);
  }

  /// Third-party hotels rank above own-database hotels everywhere in the list.
  int _sourceRank(Map<String, dynamic> hotel) => isOwnHotel(hotel) ? 1 : 0;

  /// Price used for sorting. "Price on call" hotels carry no amount, so they are
  /// pushed to the end of every price sort instead of pretending to cost 0.
  double _sortablePrice(Map<String, dynamic> hotel) =>
      isPriceOnCall(hotel) ? double.infinity : _parsePrice(hotel['price']);

  double _parsePrice(dynamic price) {
    final String priceStr = price?.toString().replaceAll(',', '').trim() ?? '';
    return double.tryParse(priceStr) ?? 0.0;
  }

  double _parseRating(dynamic rating) {
    if (rating is num) return rating.toDouble();
    return double.tryParse(rating?.toString() ?? '') ?? 0.0;
  }

  void filterByRating() {
    List<int> selectedStars = [];

    // Collect selected ratings based on the selected checkboxes
    for (int i = 0; i < selectedRatings.length; i++) {
      if (selectedRatings[i]) {
        selectedStars.add(5 - i); // Match stars with index
      }
    }

    // Debugging: Print the selected ratings
    if (kDebugMode) {
      print("Selected ratings: $selectedStars");
      print("Original hotels count: ${originalHotels.length}");
    }

    // Print sample hotel ratings for debugging
    if (originalHotels.isNotEmpty) {
      for (
        int i = 0;
        i < (originalHotels.length > 3 ? 3 : originalHotels.length);
        i++
      ) {
        if (kDebugMode) {
          print(
            "Hotel $i: rating = ${originalHotels[i]['rating']} (type: ${originalHotels[i]['rating'].runtimeType})",
          );
        }
      }
    }

    if (selectedStars.isEmpty) {
      // Show all hotels if no filter is selected
      filteredHotels.value = List<Map<String, dynamic>>.from(originalHotels);
      hotels.value = List<Map<String, dynamic>>.from(originalHotels);
    } else {
      // Apply the rating filter - convert rating to int for comparison
      filteredHotels.value =
          originalHotels.where((hotel) {
            // Convert rating to int for comparison (round to nearest integer)
            int hotelRating = _parseRating(hotel['rating']).round();
            bool matches = selectedStars.contains(hotelRating);
            if (kDebugMode) {
              print(
                "Hotel: ${hotel['name']}, Rating: $hotelRating, Matches: $matches",
              );
            }
            return matches;
          }).toList();

      hotels.value = List<Map<String, dynamic>>.from(filteredHotels);
    }

    // Debugging: Print the filtered list
    if (kDebugMode) {
      print("Filtered hotels count: ${filteredHotels.length}");
    }
  }

  // Method to filter hotels by price range
  void filterByPriceRange(double minPrice, double maxPrice) {
    try {
      if (kDebugMode) {
        print("Filtering by price range: $minPrice - $maxPrice");
        print("Original hotels count: ${originalHotels.length}");
      }

      // Create a new list with filtered hotels
      List<Map<String, dynamic>> filtered =
          originalHotels.where((hotel) {
            // "Price on call" hotels have no amount to compare, so a price
            // range never hides them.
            if (isPriceOnCall(hotel)) return true;

            // Remove commas and parse the price to a double
            double price = _parsePrice(hotel['price']);
            bool inRange = price >= minPrice && price <= maxPrice;

            if (kDebugMode) {
              print(
                "Hotel: ${hotel['name']}, Price: $price, In Range: $inRange",
              );
            }
            return inRange;
          }).toList();

      // Update the filtered and main lists
      filteredHotels.value = filtered;
      hotels.value = List<Map<String, dynamic>>.from(filtered);

      if (kDebugMode) {
        print("Price filtered hotels count: ${filtered.length}");
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error filtering hotels: $e');
      }
    }
  }

  // Method to sort hotels
  void sortHotels(String sortOption) {
    try {
      List<Map<String, dynamic>> sortedList = List<Map<String, dynamic>>.from(
        hotels,
      );

      switch (sortOption) {
        // Both price sorts keep third-party hotels above own-DB hotels, and
        // "price on call" hotels at the bottom of their own group.
        case 'Price (low to high)':
          sortedList.sort((a, b) {
            final int sourceCompare = _sourceRank(a).compareTo(_sourceRank(b));
            if (sourceCompare != 0) return sourceCompare;
            return _sortablePrice(a).compareTo(_sortablePrice(b));
          });
          break;

        case 'Price (high to low)':
          sortedList.sort((a, b) {
            final int sourceCompare = _sourceRank(a).compareTo(_sourceRank(b));
            if (sourceCompare != 0) return sourceCompare;

            final bool onCallA = isPriceOnCall(a);
            final bool onCallB = isPriceOnCall(b);
            if (onCallA != onCallB) return onCallA ? 1 : -1;

            return _parsePrice(b['price']).compareTo(_parsePrice(a['price']));
          });
          break;

        case 'Recommended':
          sortedList = List<Map<String, dynamic>>.from(originalHotels);
          break;
      }

      hotels.value = sortedList;
    } catch (e) {
      if (kDebugMode) {
        print('Error sorting hotels: $e');
      }
    }
  }

  // Reset filters
  void resetFilters() {
    // Reset all filter states
    for (int i = 0; i < selectedRatings.length; i++) {
      selectedRatings[i] = false;
    }

    // Reset hotels to original list
    hotels.value = List<Map<String, dynamic>>.from(originalHotels);
    filteredHotels.value = List<Map<String, dynamic>>.from(originalHotels);

    if (kDebugMode) {
      print("Filters reset. Hotels count: ${hotels.length}");
    }
  }

  void searchHotelsByName(String query) {
    try {
      if (query.isEmpty) {
        // If query is empty, reset to original hotels
        hotels.value = List<Map<String, dynamic>>.from(originalHotels);
      } else {
        // Filter hotels based on the name matching the query
        hotels.value =
            originalHotels
                .where(
                  (hotel) => hotel['name'].toString().toLowerCase().contains(
                    query.toLowerCase(),
                  ),
                )
                .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error searching hotels by name: $e');
      }
    }
  }

  var roomsdata = [].obs;
  var ratingstar = 0.obs;
  var hotelid = 0.obs;

  /// True while the rooms currently in [roomsdata] came from our own database
  /// (hotel-details-api.php) instead of the third-party Arabian API.
  /// Own-DB rooms have no session/rateKey, so PreBook, CancellationPolicy and
  /// PriceBreakup are skipped for them and booking goes straight through.
  final isOwnDbHotel = false.obs;

  /// `rooms_gst_percent` of the own-DB hotel currently open (0 when unknown or
  /// when a third-party hotel is open).
  final ownHotelGstPercent = 0.obs;


  var hotelName = ''.obs;
  var image = ''.obs;
  var hotelCode = ''.obs;
  var sessionId = ''.obs;
  var destinationCode = ''.obs;
  var hotelCity = ''.obs;
  var lat = ''.obs;
  var lon = ''.obs;
  var hotelImage = ''.obs;
  var hotelAddress = ''.obs;

  /// Map of hotelCode -> image URL from getHotelsDetails (hotel_id) API when user scrolls
  final hotelImagesByCode = <String, String>{}.obs;
  final Set<String> _hotelImageLoadingIds = {};

  /// Call when a hotel card is shown: fetches image by hotel_id if not cached. No-op if already have image or request in progress.
  Future<void> ensureHotelImage(String hotelCode) async {
    if (hotelCode.isEmpty) return;
    if (hotelImagesByCode.value.containsKey(hotelCode)) return;
    if (_hotelImageLoadingIds.contains(hotelCode)) return;
    _hotelImageLoadingIds.add(hotelCode);
    try {
      final url = await ApiServiceHotel().fetchHotelDetailImage(hotelCode);
      if (url != null && url.isNotEmpty) {
        hotelImagesByCode.value = Map<String, String>.from(hotelImagesByCode.value)..[hotelCode] = url;
      }
    } finally {
      _hotelImageLoadingIds.remove(hotelCode);
    }
  }

  void clearHotelImageLoading() {
    _hotelImageLoadingIds.clear();
  }

  // Add this property to store selected rooms data
  final RxList<Map<String, dynamic>> selectedRoomsData =
      <Map<String, dynamic>>[].obs;

  // Add this method to update selected rooms data
  void updateSelectedRoom(int index, Map<String, dynamic> roomData) {
    if (selectedRoomsData.length <= index) {
      selectedRoomsData.add(roomData);
    } else {
      selectedRoomsData[index] = roomData;
    }
  }

  // Helper method to get hotels count by rating for UI display
  int getHotelCountByRating(int rating) {
    return originalHotels.where((hotel) {
      int hotelRating = _parseRating(hotel['rating']).round();
      return hotelRating == rating;
    }).length;
  }
}
