import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../utility/colors.dart';
import '../../../utility/app_constants.dart';
import 'group_tickets_controller.dart';
import 'group_booking_screen.dart';

class GroupSelectionScreen extends StatelessWidget {
  final String groupType; // 'UMRAH GROUP' or 'ONE WAY GROUP'
  
  const GroupSelectionScreen({
    super.key,
    required this.groupType,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(GroupTicketsController());
    
    // Fetch groups when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchAllGroups(groupType: groupType);
    });
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: TColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
            // Clear groups when leaving
            if (Get.isRegistered<GroupTicketsController>()) {
              Get.find<GroupTicketsController>().clearGroups();
            }
          },
        ),
        title: Text(
          'Select $groupType',
          style: AppConstants.appBarTitleStyle.copyWith(
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(TColors.primary),
              ),
            ),
          );
        }
        
        if (controller.errorMessage.value.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    controller.errorMessage.value,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => controller.fetchAllGroups(groupType: groupType),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (controller.groups.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'No groups available',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(AppConstants.cardPadding),
          itemCount: controller.groups.length,
          itemBuilder: (context, index) {
            final group = controller.groups[index];
            
            // Extract group information from API response
            // Response structure: {id, airline_id, dept_date, arv_date, sector, type, price, baggage, meal, pnr, available_no_of_pax, details[], airline[]}
            final groupId = group['id'] ?? '';
            final deptDate = group['dept_date'] ?? '';
            final arvDate = group['arv_date'] ?? '';
            final price = group['price'] ?? '';
            final availablePax = group['available_no_of_pax'] ?? 0;
            final pnr = group['pnr'] ?? '';
            
            // Get airline information
            String airlineName = '';
            String airlineShortName = '';
            String logoUrl = '';
            if (group['airline'] != null && group['airline'] is List && (group['airline'] as List).isNotEmpty) {
              final airline = (group['airline'] as List).first;
              airlineName = airline['airline_name'] ?? '';
              airlineShortName = airline['short_name'] ?? '';
              final logoFileName = airline['logo_url'] ?? '';
              if (logoFileName.isNotEmpty) {
                logoUrl = 'https://alsaboorportal.com/assets/img/airline-logo/$logoFileName';
              }
            }
            
            // Format dates
            String formattedDeptDate = '';
            String formattedArvDate = '';
            if (deptDate.isNotEmpty) {
              try {
                final date = DateTime.parse(deptDate);
                formattedDeptDate = '${date.day}/${date.month}/${date.year}';
              } catch (e) {
                formattedDeptDate = deptDate;
              }
            }
            if (arvDate.isNotEmpty) {
              try {
                final date = DateTime.parse(arvDate);
                formattedArvDate = '${date.day}/${date.month}/${date.year}';
              } catch (e) {
                formattedArvDate = arvDate;
              }
            }
            
            // Format price
            String formattedPrice = '';
            if (price.isNotEmpty) {
              try {
                final priceNum = double.parse(price);
                formattedPrice = 'PKR ${priceNum.toStringAsFixed(0)}';
              } catch (e) {
                formattedPrice = 'PKR $price';
              }
            }
            
            // Extract flight details
            List<Map<String, dynamic>> flightDetails = [];
            if (group['details'] != null && group['details'] is List) {
              flightDetails = List<Map<String, dynamic>>.from(group['details']);
            }
            
            // Get outbound and return flights
            Map<String, dynamic>? outboundFlight;
            Map<String, dynamic>? returnFlight;
            if (flightDetails.isNotEmpty) {
              // Sort by sr (sequence number) to get outbound and return
              flightDetails.sort((a, b) {
                final srA = a['sr'] ?? 0;
                final srB = b['sr'] ?? 0;
                return srA.compareTo(srB);
              });
              outboundFlight = flightDetails.first;
              if (flightDetails.length > 1) {
                returnFlight = flightDetails.last;
              }
            }
            
            // Get baggage and meal info
            final baggage = group['baggage'] ?? '';
            final meal = group['meal'] ?? '';
            
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GroupBookingScreen(
                      group: group,
                      groupType: groupType,
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
                  boxShadow: AppConstants.cardShadow,
                  border: Border.all(
                    color: AppConstants.fieldBorderColor.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Logo, Airline, Price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Airline Logo
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppConstants.fieldBorderColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: logoUrl.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: CachedNetworkImage(
                                        imageUrl: logoUrl,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) => Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              TColors.primary.withOpacity(0.3),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Icon(
                                          Icons.flight,
                                          color: TColors.primary.withOpacity(0.5),
                                          size: 20,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.flight,
                                      color: TColors.primary.withOpacity(0.5),
                                      size: 20,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Airline Name and Dates
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (airlineName.isNotEmpty)
                                  Text(
                                    airlineName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (formattedDeptDate.isNotEmpty) ...[
                                      Icon(Icons.flight_takeoff, size: 11, color: TColors.primary),
                                      const SizedBox(width: 3),
                                      Text(
                                        formattedDeptDate,
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                    if (formattedDeptDate.isNotEmpty && formattedArvDate.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.flight_land, size: 11, color: TColors.primary),
                                      const SizedBox(width: 3),
                                      Text(
                                        formattedArvDate,
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                        ],
                      ),
                      const SizedBox(height: 12),
                      // Flight Details Section
                      if (outboundFlight != null) ...[
                        // Outbound Flight
                        _buildFlightDetailRow(
                          icon: Icons.flight_takeoff,
                          route: '${outboundFlight['origin'] ?? ''}-${outboundFlight['destination'] ?? ''}',
                          flightNo: outboundFlight['flight_no'] ?? '',
                          time: '${outboundFlight['dept_time'] ?? ''} - ${outboundFlight['arv_time'] ?? ''}',
                          baggage: outboundFlight['baggage'] ?? '',
                          date: outboundFlight['flight_date'] ?? '',
                        ),
                        if (returnFlight != null) ...[
                          const SizedBox(height: 8),
                          // Return Flight
                          _buildFlightDetailRow(
                            icon: Icons.flight_land,
                            route: '${returnFlight['origin'] ?? ''}-${returnFlight['destination'] ?? ''}',
                            flightNo: returnFlight['flight_no'] ?? '',
                            time: '${returnFlight['dept_time'] ?? ''} - ${returnFlight['arv_time'] ?? ''}',
                            baggage: returnFlight['baggage'] ?? '',
                            date: returnFlight['flight_date'] ?? '',
                          ),
                        ],
                      ],
                      const SizedBox(height: 10),
                      // Footer: Availability, Meal (left) and Price (right)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // Availability Status
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                                      const SizedBox(width: 4),
                                      Text(
                                        availablePax > 0 ? '$availablePax seats' : 'Available on call',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Meal Info
                                if (meal.toString().isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.restaurant, size: 12, color: Colors.orange[700]),
                                        const SizedBox(width: 4),
                                        Text(
                                          meal.toString(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Baggage Info (kept commented as user had)
                                // if (baggage.toString().isNotEmpty)
                                //   Container(
                                //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                //     decoration: BoxDecoration(
                                //       color: Colors.blue.withOpacity(0.1),
                                //       borderRadius: BorderRadius.circular(4),
                                //     ),
                                //     child: Row(
                                //       mainAxisSize: MainAxisSize.min,
                                //       children: [
                                //         Icon(Icons.luggage, size: 12, color: Colors.blue[700]),
                                //         const SizedBox(width: 4),
                                //         Text(
                                //           '$baggage KG',
                                //           style: TextStyle(
                                //             fontSize: 10,
                                //             fontWeight: FontWeight.w600,
                                //             color: Colors.blue[700],
                                //           ),
                                //         ),
                                //       ],
                                //     ),
                                //   ),
                              ],
                            ),
                          ),
                          if (formattedPrice.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: TColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                formattedPrice,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: TColors.primary,
                                ),
                              ),
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
      }),
    );
  }
  
  Widget _buildFlightDetailRow({
    required IconData icon,
    required String route,
    required String flightNo,
    required String time,
    required String baggage,
    required String date,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppConstants.fieldBorderColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: TColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      route,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SV$flightNo',
                      style: TextStyle(
                        fontSize: 10,
                        color: TColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 10, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[700],
                      ),
                    ),
                    if (baggage.toString().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.luggage, size: 10, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '$baggage KG',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

