import 'package:get/get.dart';
import 'package:ready_flights/services/api_service_hotel.dart';
import 'package:ready_flights/utility/utils.dart';

import '../../../hotel/hotel_date_controller.dart';

class SelectRoomController extends GetxController {
  var totalPrice = 0.0.obs;

  // Store prebook API response
  final Rx<Map<String, dynamic>> prebookResponse = Rx<Map<String, dynamic>>({});

  // Observable lists to store policy details for each room
  final RxList<List<Map<String, dynamic>>> roomsPolicyDetails =
      RxList<List<Map<String, dynamic>>>([]);

  // Observable maps to store room details
  final RxMap<int, String> roomNames = RxMap<int, String>({});
  final RxMap<int, String> roomMeals = RxMap<int, String>({});
  final RxMap<int, String> roomRateTypes = RxMap<int, String>({});
  final RxMap<int, double> roomPrices = RxMap<int, double>({});

  /// Own-DB room id per selected room index ('' for third-party rooms), so the
  /// booking request can tell our backend which room record was booked.
  final RxMap<int, String> roomIds = RxMap<int, String>({});
  get selectedRoomsData => null;

  /// Own-database booking: there is no PreBook response to store, so policy
  /// details stay empty and only the selected room data is (re)applied.
  ///
  /// [selectedRooms] maps room index -> the selected room map from
  /// `SearchHotelController.roomsdata`.
  void prepareOwnDbBooking(Map<int, dynamic> selectedRooms) {
    prebookResponse.value = {};
    roomsPolicyDetails.clear();

    selectedRooms.forEach((roomIndex, roomData) {
      if (roomData != null) updateSelectedRoom(roomIndex, roomData);
    });

    calculateTotalPrice();

    print('=== OWN DB BOOKING PREPARED (no prebook) ===');
    debugPrintRoomData();
  }

  // Method to store prebook response data for SINGLE ROOM booking
  void storePrebookResponseSingleRoom(Map<String, dynamic> response) {
    prebookResponse.value = response;
    
    // For single room, we only update policy details and keep existing room data
    if (response['hotel']?['rooms']?['room'] != null) {
      final rooms = response['hotel']['rooms']['room'] as List;
      
      roomsPolicyDetails.clear();
      
      // Only extract policy details, don't touch room data
      for (var i = 0; i < rooms.length; i++) {
        final room = rooms[i];
        int roomIndex = 0; // Single room always at index 0
        
        // Extract policy details only
        if (room['policies']?['policy'] != null) {
          List<Map<String, dynamic>> policyDetails = [];

          for (var policy in room['policies']['policy']) {
            if (policy['condition'] != null) {
              for (var condition in policy['condition']) {
                policyDetails.add({
                  "from_date": condition['fromDate'] ?? '',
                  "to_date": condition['toDate'] ?? '',
                  "timezone": condition['timezone'] ?? '',
                  "from_time": condition['fromTime'] ?? '',
                  "to_time": condition['toTime'] ?? '',
                  "percentage": condition['percentage'] ?? '',
                  "nights": condition['nights'] ?? '',
                  "fixed": condition['fixed'] ?? '',
                  "applicableOn": condition['applicableOn'] ?? '',
                });
              }
            }
          }

          while (roomsPolicyDetails.length <= roomIndex) {
            roomsPolicyDetails.add([]);
          }
          roomsPolicyDetails[roomIndex] = policyDetails;
        }
      }
    }
    
    print('=== SINGLE ROOM PREBOOK RESPONSE STORED ===');
    debugPrintRoomData();
  }

  // Method to store prebook response data for MULTIPLE ROOM booking
  void storePrebookResponseMultipleRooms(Map<String, dynamic> response) {
    prebookResponse.value = response;

    if (response['hotel']?['rooms']?['room'] != null) {
      final rooms = response['hotel']['rooms']['room'] as List;
      
      roomsPolicyDetails.clear();
      
      // Create a map to match selected rooms with prebook response rooms
      Map<String, dynamic> responseRoomMap = {};
      
      // First, map response rooms by their rateKey for matching
      for (var room in rooms) {
        String rateKey = room['rateKey'] ?? '';
        if (rateKey.isNotEmpty) {
          responseRoomMap[rateKey] = room;
        }
      }
      
      // Now update only policy details for existing selected rooms
      roomNames.forEach((roomIndex, roomName) {
        // Find matching room in response by comparing room data
        var matchingResponseRoom = rooms.firstWhere(
          (responseRoom) {
            return responseRoom['roomName'] == roomName && 
                   responseRoom['meal'] == roomMeals[roomIndex];
          },
          orElse: () => null,
        );
        
        if (matchingResponseRoom != null) {
          // Extract policy details for this room
          if (matchingResponseRoom['policies']?['policy'] != null) {
            List<Map<String, dynamic>> policyDetails = [];

            for (var policy in matchingResponseRoom['policies']['policy']) {
              if (policy['condition'] != null) {
                for (var condition in policy['condition']) {
                  policyDetails.add({
                    "from_date": condition['fromDate'] ?? '',
                    "to_date": condition['toDate'] ?? '',
                    "timezone": condition['timezone'] ?? '',
                    "from_time": condition['fromTime'] ?? '',
                    "to_time": condition['toTime'] ?? '',
                    "percentage": condition['percentage'] ?? '',
                    "nights": condition['nights'] ?? '',
                    "fixed": condition['fixed'] ?? '',
                    "applicableOn": condition['applicableOn'] ?? '',
                  });
                }
              }
            }

            while (roomsPolicyDetails.length <= roomIndex) {
              roomsPolicyDetails.add([]);
            }
            roomsPolicyDetails[roomIndex] = policyDetails;
          }
        }
      });
    }

    print('=== MULTIPLE ROOMS PREBOOK RESPONSE STORED ===');
    debugPrintRoomData();
  }

  // Main method to store prebook response - decides which method to use
  void storePrebookResponse(Map<String, dynamic> response) {
    // Check if multiple rooms are selected
    if (roomNames.length > 1) {
      storePrebookResponseMultipleRooms(response);
    } else {
      storePrebookResponseSingleRoom(response);
    }
    
    // Recalculate total price after update
    calculateTotalPrice();
  }

  // Method to update the price for a specific room
  void updateRoomPrice(int roomIndex, double price) {
    roomPrices[roomIndex] = price;
    calculateTotalPrice();
  }

  // Method to calculate the total price of all selected rooms
  void calculateTotalPrice() {
    double total = 0.0;
    roomPrices.forEach((key, value) {
      total += value;
    });
    // ...existing code...
totalPrice.value = total ;
// ...existing code...
  }

  // Method to update room data when a room is selected
  void updateSelectedRoom(int roomIndex, dynamic roomData) {
    // Update room details with proper index
    roomNames[roomIndex] = roomData['roomName'] ?? '';
    roomMeals[roomIndex] = roomData['meal'] ?? '';
    roomRateTypes[roomIndex] = roomData['rateType'] ?? '';
    roomIds[roomIndex] = roomData['roomId']?.toString() ?? '';

    // Update room price
    double roomPrice = 0.0;
    if (roomData['price'] != null && roomData['price']['net'] != null) {
      try {
        roomPrice = double.parse(roomData['price']['net'].toString());
      } catch (e) {
        print('Error parsing room price: $e');
      }
    }

    // Get the number of nights
    // int nights = Get.find<HotelDateController>().nights.value;

    // Multiply price by nights to get total price for this room
    // roomPrice *= nights;

    // Update the room price and recalculate total
    updateRoomPrice(roomIndex, roomPrice);
    
    // Debug: Print the updated data
    print('=== ROOM SELECTED AT INDEX $roomIndex ===');
    debugPrintRoomData();
  }

  // Method to get policy details for a specific room
  List<Map<String, dynamic>> getPolicyDetailsForRoom(int roomIndex) {
    if (roomIndex < roomsPolicyDetails.length) {
      return roomsPolicyDetails[roomIndex];
    }
    return [];
  }

  // Method to get room name for a specific room
  String getRoomName(int roomIndex) {
    return roomNames[roomIndex] ?? '';
  }

  // Method to get meal plan for a specific room
  String getRoomMeal(int roomIndex) {
    return roomMeals[roomIndex] ?? '';
  }

  // Method to get rate type for a specific room
  String getRateType(int roomIndex) {
    return roomRateTypes[roomIndex] ?? '';
  }

  // Method to get price for a specific room
  double getRoomPrice(int roomIndex) {
    return roomPrices[roomIndex] ?? 0.0;
  }

  /// Own-DB room id for a specific room ('' for third-party rooms).
  String getRoomId(int roomIndex) {
    return roomIds[roomIndex] ?? '';
  }

  // Method to clear all stored data
  void clearData() {
    prebookResponse.value = {};
    roomsPolicyDetails.clear();
    roomNames.clear();
    roomMeals.clear();
    roomRateTypes.clear();
    roomPrices.clear();
    roomIds.clear();
    totalPrice.value = 0.0;
  }
  
  void debugPrintRoomData() {
    print('=== ROOM DATA DEBUG ===');
    roomNames.forEach((index, name) {
      print('Room $index: $name, Meal: ${roomMeals[index]}, Price: ${roomPrices[index]}');
    });
    print('=======================');
  }
}