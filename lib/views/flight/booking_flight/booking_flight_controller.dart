import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:country_picker/country_picker.dart';
import 'package:ready_flights/views/flight/form/flight_booking_controller.dart';
import 'package:ready_flights/views/users/login/login_api_service/login_api.dart';

import '../../../../widgets/travelers_selection_bottom_sheet.dart';

class TravelerInfo {
  final TextEditingController titleController;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController passportCnicController;
  final TextEditingController nationalityController;
  final TextEditingController dateOfBirthController;
  final TextEditingController passportExpiryController;
  final TextEditingController genderController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final bool isInfant;

  // Country objects for better handling
  final Rx<Country?> phoneCountry;
  final Rx<Country?> nationalityCountry;

  // Flag to prevent infinite loops when syncing
  bool _isUpdatingTitleGender = false;

  TravelerInfo({required this.isInfant})
      : titleController = TextEditingController(),
        firstNameController = TextEditingController(),
        lastNameController = TextEditingController(),
        passportCnicController = TextEditingController(),
        nationalityController = TextEditingController(),
        dateOfBirthController = TextEditingController(),
        passportExpiryController = TextEditingController(),
        genderController = TextEditingController(),
        phoneController = TextEditingController(),
        emailController = TextEditingController(),
        phoneCountry = Rx<Country?>(Country.parse('PK')),
        nationalityCountry = Rx<Country?>(Country.parse('PK')) {

    // Set initial values
    nationalityController.text = nationalityCountry.value?.displayNameNoCountryCode ?? '';

    // Listen to country changes
    phoneCountry.listen((country) {
      // Phone country changes are handled in the UI
    });

    nationalityCountry.listen((country) {
      nationalityController.text = country?.displayNameNoCountryCode ?? '';
    });

    // Add listeners for title/gender synchronization
    titleController.addListener(_onTitleChanged);
    genderController.addListener(_onGenderChanged);
  }

  void _onTitleChanged() {
    if (_isUpdatingTitleGender) return;

    _isUpdatingTitleGender = true;
    String title = titleController.text;

    switch (title) {
      case 'Mr':
      case 'Mstr':
        genderController.text = 'Male';
        break;
      case 'Mrs':
      case 'Ms':
      case 'Miss':
        genderController.text = 'Female';
        break;
      case 'Inf':
        break;
    }
    _isUpdatingTitleGender = false;
  }

  void _onGenderChanged() {
    if (_isUpdatingTitleGender) return;

    _isUpdatingTitleGender = true;
    String gender = genderController.text;
    String currentTitle = titleController.text;

    if (gender == 'Male') {
      if (isInfant) {
        titleController.text = 'Inf';
      } else if (currentTitle.isEmpty || ['Mrs', 'Ms', 'Miss'].contains(currentTitle)) {
        bool isChild = currentTitle == 'Miss' ||
            (currentTitle.isEmpty && !isInfant && isChildTraveler());
        titleController.text = isChild ? 'Mstr' : 'Mr';
      }
    } else if (gender == 'Female') {
      if (isInfant) {
        titleController.text = 'Inf';
      } else if (currentTitle.isEmpty || ['Mr', 'Mstr'].contains(currentTitle)) {
        bool isChild = currentTitle == 'Mstr' ||
            (currentTitle.isEmpty && !isInfant && isChildTraveler());
        titleController.text = isChild ? 'Miss' : 'Ms';
      }
    }
    _isUpdatingTitleGender = false;
  }

  bool isChildTraveler() {
    return false;
  }

  void dispose() {
    titleController.removeListener(_onTitleChanged);
    genderController.removeListener(_onGenderChanged);

    titleController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    passportCnicController.dispose();
    nationalityController.dispose();
    dateOfBirthController.dispose();
    passportExpiryController.dispose();
    genderController.dispose();
    phoneController.dispose();
    emailController.dispose();
  }

  bool isValid() {
    if (isInfant) {
      return titleController.text.isNotEmpty &&
          firstNameController.text.isNotEmpty &&
          lastNameController.text.isNotEmpty &&
          dateOfBirthController.text.isNotEmpty &&
          nationalityCountry.value != null;
    } else {
      return titleController.text.isNotEmpty &&
          firstNameController.text.isNotEmpty &&
          lastNameController.text.isNotEmpty &&
          passportCnicController.text.isNotEmpty &&
          nationalityCountry.value != null &&
          dateOfBirthController.text.isNotEmpty &&
          passportExpiryController.text.isNotEmpty &&
          genderController.text.isNotEmpty &&
          phoneController.text.isNotEmpty &&
          emailController.text.isNotEmpty &&
          phoneCountry.value != null;
    }
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = {
      'title': titleController.text,
      'firstName': firstNameController.text,
      'lastName': lastNameController.text,
      'dateOfBirth': dateOfBirthController.text,
      'nationality': nationalityCountry.value?.countryCode ?? '',
      'nationalityCode': nationalityCountry.value?.countryCode ?? '',
      'gender': genderController.text,
    };

    if (!isInfant) {
      data.addAll({
        'passportNumber': passportCnicController.text,
        'passportExpiry': passportExpiryController.text,
        'phone': getFormattedPhoneNumber(),
        'phoneCountryCode': phoneCountry.value?.phoneCode ?? '',
        'phoneCountry': phoneCountry.value?.countryCode ?? '',
        'email': emailController.text,
      });
    }

    return data;
  }

  String getFormattedPhoneNumber() {
    String phone = phoneController.text.trim();
    String countryCode = phoneCountry.value?.phoneCode ?? '92';

    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }

    return '+$countryCode$phone';
  }
}

class BookingFlightController extends GetxController {
  final TravelersController travelersController = Get.put(TravelersController());
  final AuthController authController = Get.find<AuthController>();

  // Travelers information
  final RxList<TravelerInfo> adults = <TravelerInfo>[].obs;
  final RxList<TravelerInfo> children = <TravelerInfo>[].obs;
  final RxList<TravelerInfo> infants = <TravelerInfo>[].obs;

  // Booker Information
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final remarksController = TextEditingController();

  // Booker country information
  final Rx<Country?> bookerPhoneCountry = Rx<Country?>(Country.parse('PK'));

  // Pricing information
  final totalAmount = 0.0.obs;
  final currencyCode = 'PKR'.obs;

  // Loading state
  final isLoading = false.obs;
  final isLoadingUserData = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadUserDataAndInitialize();
  }

  Future<void> _loadUserDataAndInitialize() async {
    isLoadingUserData.value = true;
    
    try {
      // Sync traveler counts from FlightBookingController if available
      _syncTravelerCountsFromSearch();
      
      // Check if user is logged in and get their data
      final isLoggedIn = await authController.isLoggedIn();
      
      if (isLoggedIn) {
        final userData = await authController.getUserData();
        
        if (userData != null) {
          _populateBookerData(userData);
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      isLoadingUserData.value = false;
      initializeTravelers();
      
      // Listen to changes in traveler counts
      ever(travelersController.adultCount, (_) => updateAdults());
      ever(travelersController.childrenCount, (_) => updateChildren());
      ever(travelersController.infantCount, (_) => updateInfants());
    }
  }

  void _syncTravelerCountsFromSearch() {
    try {
      final flightBookingController = Get.find<FlightBookingController>();
      // Sync the counts from search to travelers controller
      travelersController.adultCount.value = flightBookingController.adultCount.value;
      travelersController.childrenCount.value = flightBookingController.childrenCount.value;
      travelersController.infantCount.value = flightBookingController.infantCount.value;
      print('Synced traveler counts: ${travelersController.adultCount.value} adults, ${travelersController.childrenCount.value} children, ${travelersController.infantCount.value} infants');
    } catch (e) {
      // FlightBookingController not found, use defaults
      print('FlightBookingController not found, using default traveler counts: $e');
    }
  }

  void _populateBookerData(Map<String, dynamic> userData) {
    // Populate name - handle both full name and first/last name scenarios
    String fullName = userData['cs_fname'] ?? userData['cs_company'] ?? '';
    List<String> nameParts = fullName.trim().split(' ');
    
    if (nameParts.length > 1) {
      firstNameController.text = nameParts.first;
      lastNameController.text = nameParts.sublist(1).join(' ');
    } else {
      firstNameController.text = fullName;
      lastNameController.text = '';
    }

    // Populate email
    emailController.text = userData['cs_email'] ?? '';

    // Populate phone
    String phone = userData['cs_phone'] ?? '';
    if (phone.isNotEmpty) {
      // Clean and format phone number
      phone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      
      // Try to extract country code if phone starts with +
      if (phone.startsWith('+')) {
        // Try to parse country code
        String phoneWithoutPlus = phone.substring(1);
        
        // Common country codes (you can expand this)
        Map<String, String> countryCodeMap = {
          '92': 'PK',  // Pakistan
          '1': 'US',   // USA/Canada
          '44': 'GB',  // UK
          '971': 'AE', // UAE
          '966': 'SA', // Saudi Arabia
          '91': 'IN',  // India
        };
        
        // Try to match country code
        for (var entry in countryCodeMap.entries) {
          if (phoneWithoutPlus.startsWith(entry.key)) {
            try {
              bookerPhoneCountry.value = Country.parse(entry.value);
              // Remove country code from phone number
              phoneController.text = phoneWithoutPlus.substring(entry.key.length);
            } catch (e) {
              print('Error parsing country: $e');
            }
            break;
          }
        }
        
        // If no country code matched, just remove the + and use as is
        if (phoneController.text.isEmpty) {
          phoneController.text = phoneWithoutPlus;
        }
      } else {
        // No country code, assume it's local number
        // Remove leading zero if present
        if (phone.startsWith('0')) {
          phone = phone.substring(1);
        }
        phoneController.text = phone;
      }
    }

    print('Booker data populated: ${firstNameController.text} ${lastNameController.text}, ${emailController.text}, ${phoneController.text}');
  }

  void initializeTravelers() {
    updateAdults();
    updateChildren();
    updateInfants();
  }

  void updateAdults() {
    final currentCount = adults.length;
    final newCount = travelersController.adultCount.value;

    if (newCount > currentCount) {
      for (var i = currentCount; i < newCount; i++) {
        adults.add(TravelerInfo(isInfant: false));
      }
    } else if (newCount < currentCount) {
      for (var i = currentCount - 1; i >= newCount; i--) {
        adults[i].dispose();
        adults.removeAt(i);
      }
    }
  }

  void updateChildren() {
    final currentCount = children.length;
    final newCount = travelersController.childrenCount.value;

    if (newCount > currentCount) {
      for (var i = currentCount; i < newCount; i++) {
        final childTraveler = TravelerInfo(isInfant: false);
        children.add(childTraveler);
      }
    } else if (newCount < currentCount) {
      for (var i = currentCount - 1; i >= newCount; i--) {
        children[i].dispose();
        children.removeAt(i);
      }
    }
  }

  void updateInfants() {
    final currentCount = infants.length;
    final newCount = travelersController.infantCount.value;

    if (newCount > currentCount) {
      for (var i = currentCount; i < newCount; i++) {
        infants.add(TravelerInfo(isInfant: true));
      }
    } else if (newCount < currentCount) {
      for (var i = currentCount - 1; i >= newCount; i--) {
        infants[i].dispose();
        infants.removeAt(i);
      }
    }
  }

  bool get isDomesticFlight {
    try {
      return Get.find<FlightBookingController>().isDomesticFlight;
    } catch (e) {
      return false;
    }
  }

  String getFormattedBookerPhoneNumber() {
    String phone = phoneController.text.trim();
    String countryCode = bookerPhoneCountry.value?.phoneCode ?? '92';

    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }

    return '+$countryCode$phone';
  }

  void showPhoneCountryPicker(BuildContext context, TravelerInfo travelerInfo) {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (Country country) {
        travelerInfo.phoneCountry.value = country;
      },
      countryListTheme: CountryListThemeData(
        flagSize: 25,
        backgroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16, color: Colors.blueGrey),
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.8,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          hintText: 'Start typing to search',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: const Color(0xFF8C98A8).withOpacity(0.2),
            ),
          ),
        ),
      ),
    );
  }

  void showBookerPhoneCountryPicker(BuildContext context) {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (Country country) {
        bookerPhoneCountry.value = country;
      },
      countryListTheme: CountryListThemeData(
        flagSize: 25,
        backgroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16, color: Colors.blueGrey),
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.8,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          hintText: 'Start typing to search',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: const Color(0xFF8C98A8).withOpacity(0.2),
            ),
          ),
        ),
      ),
    );
  }

  void showNationalityPicker(BuildContext context, TravelerInfo travelerInfo) {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (Country country) {
        travelerInfo.nationalityCountry.value = country;
      },
      countryListTheme: CountryListThemeData(
        flagSize: 25,
        backgroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16, color: Colors.blueGrey),
        bottomSheetHeight: 500,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        inputDecoration: InputDecoration(
          labelText: 'Search nationality',
          hintText: 'Start typing to search',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: const Color(0xFF8C98A8).withOpacity(0.2),
            ),
          ),
        ),
      ),
    );
  }

  bool isEmailValid(String email) {
    return GetUtils.isEmail(email);
  }

  bool isPhoneValid(String phone) {
    return phone.isNotEmpty && phone.length >= 7;
  }

  bool validateBookerInfo() {
    return firstNameController.text.isNotEmpty &&
        lastNameController.text.isNotEmpty &&
        emailController.text.isNotEmpty &&
        isEmailValid(emailController.text) &&
        phoneController.text.isNotEmpty &&
        isPhoneValid(phoneController.text) &&
        bookerPhoneCountry.value != null;
  }

  bool validateAllTravelersInfo() {
    bool adultsValid = adults.every((adult) => adult.isValid());
    bool childrenValid = children.every((child) => child.isValid());
    bool infantsValid = infants.every((infant) => infant.isValid());

    return adultsValid && childrenValid && infantsValid;
  }

  bool validateAll() {
    return validateBookerInfo() && validateAllTravelersInfo();
  }

  void resetForm() {
    firstNameController.clear();
    lastNameController.clear();
    emailController.clear();
    phoneController.clear();
    remarksController.clear();
    bookerPhoneCountry.value = Country.parse('PK');
    _disposeTravelers(adults);
    _disposeTravelers(children);
    _disposeTravelers(infants);

    initializeTravelers();
  }

  @override
  void onClose() {
    _disposeTravelers(adults);
    _disposeTravelers(children);
    _disposeTravelers(infants);

    super.onClose();
  }

  void _disposeTravelers(List<TravelerInfo> travelers) {
    for (final traveler in travelers) {
      traveler.dispose();
    }
    travelers.clear();
  }
}