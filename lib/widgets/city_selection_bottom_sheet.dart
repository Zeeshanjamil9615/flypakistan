import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../utility/colors.dart';
import '../../../utility/app_constants.dart';

class AirportData {
  final String code;
  final String name;
  final String cityName;
  final String countryName;
  final String cityCode;

  AirportData({
    required this.code,
    required this.name,
    required this.cityName,
    required this.countryName,
    required this.cityCode,
  });

  factory AirportData.fromJson(Map<String, dynamic> json) {
    return AirportData(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      cityName: json['city_name'] ?? '',
      countryName: json['country_name'] ?? '',
      cityCode: json['city_code'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'city_name': cityName,
      'country_name': countryName,
      'city_code': cityCode,
    };
  }
}

enum FieldType { departure, destination }

class AirportController extends GetxController {
  var airports = <AirportData>[].obs;
  var defaultDepartureAirports = <AirportData>[].obs;
  var defaultDestinationAirports = <AirportData>[].obs;
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var filteredAirports = <AirportData>[].obs;
  var isAirportsLoaded = false.obs;
  var recentSearches = <AirportData>[].obs;

  final List<String> departureAirportCodes = [
    "KHI",
    "LHE",
    "ISB",
    "LYP",
    "PEW",
    "MUX",
    "SKT"
  ];

  final List<String> destinationAirportCodes = [
    "DXB",
    "JED",
    "MED",
    "LON",
    "CDG",
    "IST",
    "KUL",
    "GYD",
    "BKK"
  ];

  @override
  void onInit() {
    super.onInit();
    loadRecentSearches();
    // Auto-fetch airports if not already loaded
    if (!isAirportsLoaded.value && !isLoading.value) {
      fetchAirports();
    }
  }

  Future<void> fetchAirports() async {
    try {
      // Reset previous states
      isLoading.value = true;
      errorMessage.value = '';

      final response = await http
          .get(Uri.parse('https://agent1.pk/api.php?type=airports'), headers: {
        'Connection': 'keep-alive'
      }).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Connection timeout');
      });

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success' && jsonData['data'] is List) {
          final List<dynamic> airportsData = jsonData['data'];

          // Check if data is actually received
          if (airportsData.isEmpty) {
            errorMessage.value = 'No airports found';
            return;
          }

          airports.value =
              airportsData.map((item) => AirportData.fromJson(item)).toList();

          _filterDefaultAirports();

          isAirportsLoaded.value = true;
        } else {
          errorMessage.value = jsonData['message'] ?? 'Invalid data format';
        }
      } else {
        errorMessage.value =
        'Failed to load airports. Status: ${response.statusCode}';
      }
    } on SocketException {
      errorMessage.value = 'No internet connection';
    } on TimeoutException {
      errorMessage.value = 'Connection timeout. Please try again';
    } catch (e) {
      errorMessage.value = 'Unexpected error: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }

  void _filterDefaultAirports() {
    if (airports.isEmpty) return;

    defaultDepartureAirports.value = airports
        .where((airport) => departureAirportCodes.contains(airport.code))
        .toList()
      ..sort((a, b) {
        final indexA = departureAirportCodes.indexOf(a.code);
        final indexB = departureAirportCodes.indexOf(b.code);
        return indexA.compareTo(indexB);
      });

    defaultDestinationAirports.value = airports
        .where((airport) => destinationAirportCodes.contains(airport.code))
        .toList()
      ..sort((a, b) {
        final indexA = destinationAirportCodes.indexOf(a.code);
        final indexB = destinationAirportCodes.indexOf(b.code);
        return indexA.compareTo(indexB);
      });
  }

  void searchAirports(String query, FieldType fieldType) {
    if (query.isEmpty) {
      filteredAirports.value = fieldType == FieldType.departure
          ? defaultDepartureAirports
          : defaultDestinationAirports;
    } else {
      final searchQuery = query.toLowerCase();
      filteredAirports.value = airports
          .where((airport) =>
      airport.cityName.toLowerCase().contains(searchQuery) ||
          airport.name.toLowerCase().contains(searchQuery) ||
          airport.code.toLowerCase().contains(searchQuery) ||
          airport.countryName.toLowerCase().contains(searchQuery))
          .toList();
    }
  }

  Future<void> loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentSearchesJson = prefs.getStringList('recentSearches') ?? [];

      recentSearches.value = recentSearchesJson
          .map((json) => AirportData.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      print('Error loading recent searches: $e');
    }
  }

  Future<void> addToRecentSearches(AirportData airport) async {
    try {
      // Remove if already exists to avoid duplicates
      recentSearches.removeWhere((item) => item.code == airport.code);

      // Add to beginning of list
      recentSearches.insert(0, airport);

      // Keep only the most recent 5 searches
      if (recentSearches.length > 5) {
        recentSearches.removeLast();
      }

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final jsonList = recentSearches
          .map((airport) => jsonEncode(airport.toJson()))
          .toList();
      await prefs.setStringList('recentSearches', jsonList);
    } catch (e) {
      print('Error saving recent searches: $e');
    }
  }
}

class CitySelectionBottomSheet extends StatefulWidget {
  final Function(AirportData) onCitySelected;
  final FieldType fieldType;

  const CitySelectionBottomSheet({
    Key? key,
    required this.onCitySelected,
    required this.fieldType,
  }) : super(key: key);

  @override
  State<CitySelectionBottomSheet> createState() => _CitySelectionBottomSheetState();
}

class _CitySelectionBottomSheetState extends State<CitySelectionBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final AirportController _airportController = Get.put(AirportController());

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterAirports);
    _initializeData();
  }

  void _initializeData() {
    // Load airports if not already loaded
    if (!_airportController.isAirportsLoaded.value) {
      _airportController.fetchAirports();
    }

    // Set initial filtered airports based on field type
    _airportController.filteredAirports.value = widget.fieldType == FieldType.departure
        ? _airportController.defaultDepartureAirports
        : _airportController.defaultDestinationAirports;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterAirports() {
    _airportController.searchAirports(_searchController.text, widget.fieldType);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 1,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppConstants.cardBorderRadius),
                topRight: Radius.circular(AppConstants.cardBorderRadius),
              ),
              color: TColors.primary,
            ),
            child: Center(
              child: Text(
                widget.fieldType == FieldType.departure ? 'Select Departure City' : 'Select Destination City',
                style: AppConstants.sectionTitleStyle.copyWith(color: Colors.white),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppConstants.screenPadding),
            child: Container(
              height: AppConstants.fieldHeight,
              decoration: BoxDecoration(
                color: AppConstants.fieldBackgroundColor,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(color: AppConstants.fieldBorderColor),
                boxShadow: AppConstants.cardShadow,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for city or airport',
                  hintStyle: AppConstants.fieldLabelStyle,
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppConstants.tabInactiveColor,
                    size: AppConstants.smallIconSize,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          // Recent Searches Section
          Obx(() => _airportController.recentSearches.isNotEmpty
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'RECENT SEARCHES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              SizedBox(
                height: _airportController.recentSearches.length > 2 ? 120 : 80,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: _airportController.recentSearches.length,
                  itemBuilder: (context, index) {
                    final airport = _airportController.recentSearches[index];
                    return GestureDetector(
                      onTap: () {
                        widget.onCitySelected(airport);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              airport.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              airport.cityName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Divider(color: Colors.grey[300]),
            ],
          )
              : const SizedBox.shrink()),
          // Popular Cities Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'POPULAR CITIES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                // SizedBox(
                //   height: 100,
                //   child: Obx(() {
                //     final popularAirports = widget.fieldType == FieldType.departure
                //         ? _airportController.defaultDepartureAirports
                //         : _airportController.defaultDestinationAirports;
                //
                //     return popularAirports.isEmpty
                //         ? const Center(child: Text("Loading popular cities..."))
                //         : ListView.builder(
                //       scrollDirection: Axis.horizontal,
                //       itemCount: popularAirports.length,
                //       itemBuilder: (context, index) {
                //         final airport = popularAirports[index];
                //         return GestureDetector(
                //           onTap: () {
                //             _airportController.addToRecentSearches(airport);
                //             widget.onCitySelected(airport);
                //             Navigator.pop(context);
                //           },
                //           child: Container(
                //             width: 120,
                //             margin: const EdgeInsets.all(8),
                //             padding: const EdgeInsets.all(12),
                //             decoration: BoxDecoration(
                //               color: Colors.grey[100],
                //               borderRadius: BorderRadius.circular(8),
                //             ),
                //             child: Column(
                //               mainAxisAlignment: MainAxisAlignment.center,
                //               children: [
                //                 Text(
                //                   airport.code,
                //                   style: const TextStyle(
                //                     fontWeight: FontWeight.bold,
                //                     fontSize: 16,
                //                   ),
                //                 ),
                //                 Text(
                //                   airport.cityName,
                //                   textAlign: TextAlign.center,
                //                   style: const TextStyle(fontSize: 12),
                //                   overflow: TextOverflow.ellipsis,
                //                 ),
                //               ],
                //             ),
                //           ),
                //         );
                //       },
                //     );
                //   }),
                // ),
              ],
            ),
          ),
          Divider(color: Colors.grey[300]),
          // Airport List
          Expanded(
            child: Obx(() {
              if (_airportController.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_airportController.errorMessage.value.isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _airportController.errorMessage.value,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _airportController.fetchAirports(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TColors.primary,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (_airportController.filteredAirports.isEmpty) {
                return const Center(
                  child: Text('No airports found matching your model_controllers'),
                );
              }

              return ListView.builder(
                itemCount: _airportController.filteredAirports.length,
                itemBuilder: (context, index) {
                  final airport = _airportController.filteredAirports[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppConstants.screenPadding, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                      border: Border.all(color: AppConstants.fieldBorderColor),
                      boxShadow: AppConstants.cardShadow,
                    ),
                    child: ListTile(
                      onTap: () {
                        _airportController.addToRecentSearches(airport);
                        widget.onCitySelected(airport);
                        Navigator.pop(context);
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${airport.cityName}, ${airport.countryName}',
                                  style: AppConstants.fieldValueStyle,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  airport.name,
                                  style: AppConstants.fieldLabelStyle,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: TColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                            ),
                            child: Text(
                              airport.code,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: TColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}