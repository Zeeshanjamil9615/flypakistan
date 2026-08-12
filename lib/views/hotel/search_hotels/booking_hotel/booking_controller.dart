import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:country_picker/country_picker.dart';
import '../../../../services/api_service_hotel.dart';
import '../../../users/login/login_api_service/login_api.dart';
import '../../hotel/guests/guests_controller.dart';
import '../../hotel/hotel_date_controller.dart';
import '../search_hotel_controller.dart';
import '../select_room/controller/select_room_controller.dart';

class HotelGuestInfo {
  final TextEditingController titleController;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;

  HotelGuestInfo()
    : titleController = TextEditingController(),
      firstNameController = TextEditingController(),
      lastNameController = TextEditingController();

  void dispose() {
    titleController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
  }

  bool isValid() {
    return titleController.text.isNotEmpty &&
        firstNameController.text.isNotEmpty &&
        lastNameController.text.isNotEmpty;
  }
}

class RoomGuests {
  final List<HotelGuestInfo> adults;
  final List<HotelGuestInfo> children;

  RoomGuests({required this.adults, required this.children});

  void dispose() {
    for (var adult in adults) {
      adult.dispose();
    }
    for (var child in children) {
      child.dispose();
    }
  }
}

class BookingController extends GetxController {
  String? getValidationError() {
  // Check terms and conditions first
  // if (!acceptedTerms.value) {
  //   return "Please accept the terms and conditions";
  // }

  // Check booker information
  if (titleController.text.isEmpty) {
    return "Please select booker title";
  }
  if (firstNameController.text.isEmpty) {
    return "Please enter booker first name";
  }
  if (lastNameController.text.isEmpty) {
    return "Please enter booker last name";
  }
  if (emailController.text.isEmpty) {
    return "Please enter email address";
  }
  if (!isEmailValid(emailController.text)) {
    return "Please enter a valid email address";
  }
  if (phoneController.text.isEmpty) {
    return "Please enter phone number";
  }
  if (!isPhoneValid(phoneController.text)) {
    return "Please enter a valid phone number";
  }
  // if (addressController.text.isEmpty) {
  //   return "Please enter address";
  // }
  // if (cityController.text.isEmpty) {
  //   return "Please enter city";
  // }

  // Check guest information for each room
  for (int roomIndex = 0; roomIndex < roomGuests.length; roomIndex++) {
    var room = roomGuests[roomIndex];
    
    // Check adults
    for (int adultIndex = 0; adultIndex < room.adults.length; adultIndex++) {
      var adult = room.adults[adultIndex];
      if (adult.titleController.text.isEmpty) {
        return "Please select title for Adult ${adultIndex + 1} in Room ${roomIndex + 1}";
      }
      if (adult.firstNameController.text.isEmpty) {
        return "Please enter first name for Adult ${adultIndex + 1} in Room ${roomIndex + 1}";
      }
      if (adult.lastNameController.text.isEmpty) {
        return "Please enter last name for Adult ${adultIndex + 1} in Room ${roomIndex + 1}";
      }
    }
    
    // Check children
    for (int childIndex = 0; childIndex < room.children.length; childIndex++) {
      var child = room.children[childIndex];
      if (child.titleController.text.isEmpty) {
        return "Please select title for Child ${childIndex + 1} in Room ${roomIndex + 1}";
      }
      if (child.firstNameController.text.isEmpty) {
        return "Please enter first name for Child ${childIndex + 1} in Room ${roomIndex + 1}";
      }
      if (child.lastNameController.text.isEmpty) {
        return "Please enter last name for Child ${childIndex + 1} in Room ${roomIndex + 1}";
      }
    }
  }

  // If all validations pass, return null
  return null;
}

// Room guest information
final RxList<RoomGuests> roomGuests = <RoomGuests>[].obs;
SearchHotelController searchHotelController =
    Get.find<SearchHotelController>();
HotelDateController hotelDateController = Get.find<HotelDateController>();
  GuestsController guestsController = Get.find<GuestsController>();

  ApiServiceHotel apiService = ApiServiceHotel();
  var booking_num = 0.obs;
  var payment_status = "PENDING".obs;


  // Booker Information
  final titleController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final specialRequestsController = TextEditingController();

  // Country picker for phone
  final Rx<Country> selectedCountry = Country.parse('PK').obs; // Default to Pakistan

  // Special Requests Checkboxes
  final isGroundFloor = false.obs;
  final isHighFloor = false.obs;
  final isLateCheckout = false.obs;
  final isEarlyCheckin = false.obs;
  final isTwinBed = false.obs;
  final isSmoking = false.obs;

  // Terms and Conditions
  final acceptedTerms = false.obs;

  // Loading state
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Initialize with existing GuestsController data
    initializeRoomGuests();
    loadLoggedInBookerInfo();
  }

  void _setIfEmpty(TextEditingController controller, String? value) {
    final v = value?.toString().trim();
    if (v == null || v.isEmpty) return;
    if (controller.text.trim().isEmpty) {
      controller.text = v;
    }
  }

  void _tryParseAndSetPhone(String rawPhone) {
    // We store local-part (without country code) in `phoneController` because
    // request body uses `getFullPhoneNumber()` = +code + local-part.
    final normalized = rawPhone.replaceAll(' ', '').replaceAll('-', '');

    // If phone already includes a +countrycode, strip it when possible.
    if (normalized.startsWith('+')) {
      // Common case in Pakistan market.
      if (normalized.startsWith('+92')) {
        selectedCountry.value = Country.parse('PK');
        phoneController.text = normalized.substring(3); // remove +92
        return;
      }

      final currentCode = '+${selectedCountry.value.phoneCode}';
      if (normalized.startsWith(currentCode)) {
        phoneController.text = normalized.substring(currentCode.length);
        return;
      }
    }

    // Otherwise just fill as-is (user can adjust country picker).
    phoneController.text = rawPhone.trim();
  }

  Future<void> loadLoggedInBookerInfo() async {
    try {
      if (!Get.isRegistered<AuthController>()) return;

      final authController = Get.find<AuthController>();
      final isLoggedIn = await authController.isLoggedIn();
      if (!isLoggedIn) return;

      final userData = await authController.getUserData();
      if (userData == null || userData.isEmpty) return;

      // Booker basic info (only fill if user hasn't typed anything yet)
      _setIfEmpty(emailController, userData['cs_email'] ?? userData['email']);

      final rawFirstName =
          (userData['cs_fname'] ?? userData['contact_name'] ?? userData['name'])
              ?.toString();
      final rawLastName =
          (userData['cs_lname'] ?? userData['cs_lastname'] ?? userData['lname'])
              ?.toString();

      if ((rawLastName == null || rawLastName.trim().isEmpty) &&
          rawFirstName != null &&
          rawFirstName.trim().contains(' ')) {
        // If API gives a full name in cs_fname, split it into first/last.
        final parts =
            rawFirstName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
        final list = parts.toList();
        if (list.length >= 2) {
          _setIfEmpty(firstNameController, list.first);
          _setIfEmpty(lastNameController, list.sublist(1).join(' '));
        } else {
          _setIfEmpty(firstNameController, rawFirstName);
        }
      } else {
        _setIfEmpty(firstNameController, rawFirstName);
        _setIfEmpty(lastNameController, rawLastName);
      }

      final phone = (userData['cs_phone'] ?? userData['phone'])?.toString();
      if (phone != null && phone.trim().isNotEmpty && phoneController.text.trim().isEmpty) {
        _tryParseAndSetPhone(phone);
      }

      // Optional defaults
      _setIfEmpty(cityController, userData['cs_city'] ?? userData['city']);
      _setIfEmpty(addressController, userData['full_addrss'] ?? userData['address']);

      // If you store a title, respect it; otherwise leave user's choice.
      _setIfEmpty(titleController, userData['title'] ?? userData['cs_title']);
    } catch (e) {
      print('Error loading logged-in booker info: $e');
    }
  }

  void initializeRoomGuests() {
    final guestsController = Get.find<GuestsController>();

    roomGuests.clear();
    for (var room in guestsController.rooms) {
      final adults = List.generate(room.adults.value, (_) => HotelGuestInfo());

      final children = List.generate(
        room.children.value,
        (_) => HotelGuestInfo(),
      );

      roomGuests.add(RoomGuests(adults: adults, children: children));
    }
  }

  // Get full phone number with country code
  String getFullPhoneNumber() {
    return '+${selectedCountry.value.phoneCode}${phoneController.text}';
  }

  // Validation methods
  bool isEmailValid(String email) {
    return GetUtils.isEmail(email);
  }

  bool isPhoneValid(String phone) {
    return GetUtils.isPhoneNumber(phone);
  }

  bool validateBookerInfo() {
    return titleController.text.isNotEmpty &&
        firstNameController.text.isNotEmpty &&
        lastNameController.text.isNotEmpty &&
        emailController.text.isNotEmpty &&
        isEmailValid(emailController.text) &&
        phoneController.text.isNotEmpty &&
        isPhoneValid(phoneController.text) &&
        addressController.text.isNotEmpty &&
        cityController.text.isNotEmpty;
  }

  bool validateAllGuestInfo() {
    for (var room in roomGuests) {
      for (var adult in room.adults) {
        if (!adult.isValid()) return false;
      }
      for (var child in room.children) {
        if (!child.isValid()) return false;
      }
    }
    return true;
  }

  bool validateAll() {
    return validateBookerInfo() &&
        validateAllGuestInfo() &&
        acceptedTerms.value;
  }

  void resetForm() {
    // Reset booker information
    titleController.clear();
    firstNameController.clear();
    lastNameController.clear();
    emailController.clear();
    phoneController.clear();
    addressController.clear();
    cityController.clear();
    specialRequestsController.clear();

    // Reset country picker
    selectedCountry.value = Country.parse('PK'); // Reset to Pakistan

    // Reset special requests
    isGroundFloor.value = false;
    isHighFloor.value = false;
    isLateCheckout.value = false;
    isEarlyCheckin.value = false;
    isTwinBed.value = false;
    isSmoking.value = false;

    // Reset terms
    acceptedTerms.value = false;

    // Reset room guests
    initializeRoomGuests();
  }

  @override
  void onClose() {
    // Dispose booker information controllers
    titleController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    cityController.dispose();
    specialRequestsController.dispose();

    // Dispose room guest controllers
    for (var room in roomGuests) {
      room.dispose();
    }

    super.onClose();
  }

  Future<bool> saveHotelBookingToDB() async {
  final selectRoomController = Get.put(SelectRoomController());
  List<Map<String, dynamic>> roomsList = [];
  final dateFormat = DateFormat('yyyy-MM-dd');

  try {
    // Calculate total buying price from SelectRoomController instead of searchHotelController
    
    // Method 1: Use the total price from SelectRoomController (this already includes nights calculation)
     double totalSellingPrice = selectRoomController.totalPrice.value;
    
    // Calculate buying price by removing margin
    // Formula: buying_price = selling_price / (1 + margin%)
    double marginPercentage = apiService.currentMargin / 100; // e.g., 0.10 for 10%
    double totalBuyingPrice = totalSellingPrice / (1 + marginPercentage);

    
    

    print('=== BUYING PRICE CALCULATION DEBUG ===');
    print('Total from SelectRoomController: ${selectRoomController.totalPrice.value}');
    // print('PKR Price: ${pkrprice}');
    print('Calculated Buying Price (USD): $totalBuyingPrice');
    selectRoomController.roomPrices.forEach((roomIndex, price) {
      print('Room $roomIndex price: $price USD');
    });
    print('=======================================');

    for (var i = 0; i < roomGuests.length; i++) {
      List<Map<String, dynamic>> paxDetails = [];

      // Add adults
      for (var adult in roomGuests[i].adults) {
        if (adult.titleController.text.isEmpty ||
            adult.firstNameController.text.isEmpty ||
            adult.lastNameController.text.isEmpty) {
          throw Exception('Adult details missing for room ${i + 1}');
        }

        paxDetails.add({
          "type": "Adult",
          "title": adult.titleController.text.trim(),
          "first": adult.firstNameController.text.trim(),
          "last": adult.lastNameController.text.trim(),
          "age": "",
        });
      }

      // Add children with null safety
      if (roomGuests[i].children.isNotEmpty) {
        for (var j = 0; j < roomGuests[i].children.length; j++) {
          var child = roomGuests[i].children[j];
          var childAge =
              guestsController.rooms[i].childrenAges.isNotEmpty &&
                      j < guestsController.rooms[i].childrenAges.length
                  ? guestsController.rooms[i].childrenAges[j].toString()
                  : "0";

          if (child.titleController.text.isEmpty ||
              child.firstNameController.text.isEmpty ||
              child.lastNameController.text.isEmpty) {
            throw Exception('Child details missing for room ${i + 1}');
          }

          paxDetails.add({
            "type": "Child",
            "title": child.titleController.text.trim(),
            "first": child.firstNameController.text.trim(),
            "last": child.lastNameController.text.trim(),
            "age": childAge,
          });
        }
      }

      // Get the policy details for the room
      final policyDetails = selectRoomController.getPolicyDetailsForRoom(i);
      String pEndDate = "";
      String pEndTime = "";

      if (policyDetails.isNotEmpty) {
        final firstPolicy = policyDetails.first;

        // Try all possible key formats to be safe
        // First try snake_case keys from the request body example
        if (firstPolicy['to_date'] != null &&
            firstPolicy['to_date'].isNotEmpty) {
          List<String> dateParts = firstPolicy['to_date'].split('T');
          if (dateParts.isNotEmpty) {
            pEndDate = dateParts[0];
          }
        }
        // Then try camelCase keys that might be coming from the API
        else if (firstPolicy['toDate'] != null &&
            firstPolicy['toDate'].isNotEmpty) {
          List<String> dateParts = firstPolicy['toDate'].split('T');
          if (dateParts.isNotEmpty) {
            pEndDate = dateParts[0];
          }
        }

        // Same approach for time
        if (firstPolicy['to_time'] != null) {
          pEndTime = firstPolicy['to_time'];
        } else if (firstPolicy['toTime'] != null) {
          pEndTime = firstPolicy['toTime'];
        }

        // Print a debug message
        print("Policy data extracted - Date: $pEndDate, Time: $pEndTime");
      }
      // Create room object with null safety
      Map<String, dynamic> roomObject = {
        "p_nature": selectRoomController.getRateType(i),
        "p_type": "CAN",
        "p_end_date": pEndDate,
        "p_end_time": pEndTime,
        "room_name": selectRoomController.getRoomName(i),
        "room_bordbase": selectRoomController.getRoomMeal(i),
        // Own-DB rooms are identified by their room id ('' for third-party).
        "room_id": selectRoomController.getRoomId(i),
        "policy_details": policyDetails,
        "pax_details": paxDetails,
      };

      roomsList.add(roomObject);
    }

    // Prepare special requests list
    List<String> specialRequests = [];
    if (isGroundFloor.value) specialRequests.add("Ground Floor");
    if (isHighFloor.value) specialRequests.add("High Floor");
    if (isLateCheckout.value) specialRequests.add("Late checkout");
    if (isEarlyCheckin.value) specialRequests.add("Early checkin");
    if (isTwinBed.value) specialRequests.add("Twin Bed");
    if (isSmoking.value) specialRequests.add("Smoking");

    // Own-database hotels never go through the third-party search/PreBook, so
    // they have no session, group code or rate key to send.
    final bool isOwnDbHotel = searchHotelController.isOwnDbHotel.value;

    // Create request body with null safety - using full phone number with country code
    final Map<String, dynamic> requestBody = {
      "bookeremail": emailController.text.trim(),
      "bookerfirst": firstNameController.text.trim(),
      "bookerlast": lastNameController.text.trim(),
      "bookertel": getFullPhoneNumber(), // Using full phone number with country code
      "bookeraddress": addressController.text.trim(),
      "bookercompany": "",
      "bookercountry": "",
      "bookercity": cityController.text.trim(),
      "om_ordate": DateTime.now().toIso8601String().split('T')[0].toString(),
      "cancellation_buffer": "",
      "session_id": isOwnDbHotel ? "" : searchHotelController.sessionId.value,
      "group_code":
          isOwnDbHotel
              ? ""
              : (searchHotelController.roomsdata.isNotEmpty
                  ? searchHotelController.roomsdata[0]['groupCode'] ?? ""
                  : ""),
      "rate_key": isOwnDbHotel ? "" : _buildRateKey(),
      "om_hid": searchHotelController.hotelCode.value,
      "om_nights": hotelDateController.nights.value,
      "buying_price": double.parse(totalBuyingPrice.toStringAsFixed(2)), // Without margin
      "selling_price": double.parse(totalSellingPrice.toStringAsFixed(2)), 
      "om_regid": searchHotelController.destinationCode.value,
      "om_hname": searchHotelController.hotelName.value,
      "om_destination": searchHotelController.hotelCity.value,
      "om_trooms": guestsController.roomCount.value,
      "om_chindate": dateFormat.format(hotelDateController.checkInDate.value),
      "om_choutdate": dateFormat.format(
        hotelDateController.checkOutDate.value,
      ),
      "om_spreq": specialRequests.isEmpty ? "" : specialRequests.join(', '),
      "om_smoking": "",
      "om_status": "0",
      "payment_status": "Pending",
      "om_suppliername": isOwnDbHotel ? "Flypakistan" : "Arabian",
      "Rooms": roomsList,
    };

    print('=== FINAL REQUEST BODY BUYING PRICE ===');
    print(requestBody);
    print('======================================');

    isLoading.value = true;
    // Send the booking request
    final bool success = await apiService.bookHotel(requestBody);
    print('=== BOOKING API RESULT ===');
    print('Success: $success');

    isLoading.value = false;
    return success;
  } catch (e) {
    isLoading.value = false;
    rethrow;
  }
}


  String _buildRateKey() {
    try {
      if (searchHotelController.selectedRoomsData.isEmpty) return "";

      List<String> rateKeys =
          searchHotelController.selectedRoomsData
              .map((room) => room['rateKey']?.toString() ?? "")
              .where((key) => key.isNotEmpty)
              .toList();

      return rateKeys.isEmpty ? "" : "start${rateKeys.join('za,in')}";
    } catch (e) {
      print('Error building rate key: $e');
      return "";
    }
  }
}