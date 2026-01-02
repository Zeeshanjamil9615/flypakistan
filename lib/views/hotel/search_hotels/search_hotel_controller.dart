import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

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

  // Initialize the filter data - call this after fetching hotels
  filterhotler() {
    originalHotels.value = List<Map<String, dynamic>>.from(hotels);
    filteredHotels.value = List<Map<String, dynamic>>.from(hotels);
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
            int hotelRating = (hotel['rating'] as double).round();
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
            // Remove commas and parse the price to a double
            String priceStr =
                hotel['price'].toString().replaceAll(',', '').trim();
            double price = double.tryParse(priceStr) ?? 0.0;
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
        case 'Price (low to high)':
          sortedList.sort((a, b) {
            double priceA =
                double.tryParse(
                  a['price'].toString().replaceAll(',', '').trim(),
                ) ??
                0.0;
            double priceB =
                double.tryParse(
                  b['price'].toString().replaceAll(',', '').trim(),
                ) ??
                0.0;
            return priceA.compareTo(priceB);
          });
          break;

        case 'Price (high to low)':
          sortedList.sort((a, b) {
            double priceA =
                double.tryParse(
                  a['price'].toString().replaceAll(',', '').trim(),
                ) ??
                0.0;
            double priceB =
                double.tryParse(
                  b['price'].toString().replaceAll(',', '').trim(),
                ) ??
                0.0;
            return priceB.compareTo(priceA);
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
      int hotelRating = (hotel['rating'] as double).round();
      return hotelRating == rating;
    }).length;
  }
}
