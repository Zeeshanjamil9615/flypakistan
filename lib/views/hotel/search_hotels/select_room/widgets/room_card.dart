import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ready_flights/utility/utils.dart';

import '../../../../../services/api_service_hotel.dart';
import '../../../../../utility/colors.dart';
import '../../search_hotel_controller.dart';

class RoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final int nights;
  final Function(dynamic) onSelect;
  final bool isSelected;
  final bool showBookNowButton;
  final bool isLoading;
  final int roomIndex;

  const RoomCard({
    super.key,
    required this.room,
    required this.nights,
    required this.onSelect,
    required this.isSelected,
    this.showBookNowButton = false,
    this.isLoading = false,
    required this.roomIndex,
  });

  void _showCancellationPolicy(BuildContext context) async {
    final apiService = ApiServiceHotel();
    final controller = Get.find<SearchHotelController>();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: CircularProgressIndicator(color: TColors.primary),
          ),
    );

    try {
      final response = await apiService.getCancellationPolicy(
        sessionId: controller.sessionId.value,
        hotelCode: controller.hotelCode.value,
        groupCode: room['groupCode'] as int,
        currency: "USD",
        rateKeys: [room['rateKey']],
      );

      // Dismiss loading dialog
      // ignore: use_build_context_synchronously
      Navigator.pop(context);

      if (response != null) {
        final rooms = response['rooms']?['room'] as List?;
        if (rooms?.isNotEmpty ?? false) {
          final roomData = rooms![0];
          final isCancellationAvailable =
              roomData['isCancelationPolicyAvailble'] ?? false;
          final policies = roomData['policies']?['policy'] as List?;

          showDialog(
            // ignore: use_build_context_synchronously
            context: context,
            barrierDismissible: false,
            builder:
                (context) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    height: 600,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: TColors.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Cancellation Policy',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: TColors.text,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: TColors.iconclr,
                              ),
                              onPressed: () {
                                try {
                                  Navigator.pop(context);
                                } catch (e) {
                                  // Context no longer valid
                                }
                              },
                              color: TColors.grey,
                            ),
                          ],
                        ),
                        const Divider(color: TColors.background3),
                        const SizedBox(height: 12),
                        if (!isCancellationAvailable)
                          const Text(
                            'Cancellation policy is not available for this room.',
                            style: TextStyle(color: TColors.grey),
                          )
                        else if (policies == null || policies.isEmpty)
                          const Text(
                            'No cancellation policy details available.',
                            style: TextStyle(color: TColors.grey),
                          )
                        else
                          ...policies.map((policy) {
                            final conditions = policy['condition'] as List?;
                            if (conditions == null || conditions.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Container(
                              color: TColors.white,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:
                                    conditions.map((condition) {
                                      final fromDate = DateTime.tryParse(
                                        condition['fromDate'] ?? '',
                                      );
                                      final toDate = DateTime.tryParse(
                                        condition['toDate'] ?? '',
                                      );
                                      final percentage = condition['percentage'];
                                      final timezone = condition['timezone'];
                              
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: TColors.white,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: TColors.primary.withOpacity(
                                                0.1,
                                              ),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: TColors.primary
                                                    .withOpacity(0.05),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Container(
                                                      color: TColors.white,
                              
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Date Range Section
                                                if (fromDate != null &&
                                                    toDate != null)
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(8),
                                                        decoration: BoxDecoration(
                                                          color: TColors.primary
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: const Icon(
                                                          Icons.calendar_today,
                                                          color: TColors.iconclr,
                                                          size: 20,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            const Text(
                                                              'Valid Period',
                                                              style: TextStyle(
                                                                color: TColors.grey,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight.w500,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Text(
                                                              '${DateFormat('MMM dd, yyyy').format(fromDate)} - ${DateFormat('MMM dd, yyyy').format(toDate)}',
                                                              style:
                                                                  const TextStyle(
                                                                    color:
                                                                        TColors
                                                                            .text,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontSize: 14,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                            
                                                if (fromDate != null)
                                                  const SizedBox(height: 16),
                                            
                                                // Time Section
                                                if (condition['fromTime'] != null &&
                                                    condition['toTime'] != null)
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(8),
                                                        decoration: BoxDecoration(
                                                          color: TColors.primary
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: const Icon(
                                                          Icons.access_time,
                                                          color: TColors.iconclr,
                                                          size: 20,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            const Text(
                                                              'Time Window',
                                                              style: TextStyle(
                                                                color: TColors.grey,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight.w500,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Text(
                                                              '${condition['fromTime']} - ${condition['toTime']}',
                                                              style:
                                                                  const TextStyle(
                                                                    color:
                                                                        TColors
                                                                            .text,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontSize: 14,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                            
                                                if (condition['fromTime'] != null)
                                                  const SizedBox(height: 16),
                                            
                                                // Cancellation Amount Section
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(
                                                        8,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: TColors.primary
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.payments_outlined,
                                                        color: TColors.iconclr,
                                                        size: 20,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'Refund Amount',
                                                            style: TextStyle(
                                                              color: TColors.grey,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight.w500,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Row(
                                                            children: [
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal: 8,
                                                                      vertical: 4,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      percentage ==
                                                                              '100'
                                                                          ? Colors
                                                                              .green
                                                                              .withOpacity(
                                                                                0.1,
                                                                              )
                                                                          : percentage ==
                                                                              '0'
                                                                          ? TColors
                                                                              .third
                                                                              .withOpacity(
                                                                                0.1,
                                                                              )
                                                                          : TColors
                                                                              .primary
                                                                              .withOpacity(
                                                                                0.1,
                                                                              ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        4,
                                                                      ),
                                                                ),
                                                                child: Text(
                                                                  '$percentage% Return',
                                                                  style: TextStyle(
                                                                    color:
                                                                        percentage ==
                                                                                '100'
                                                                            ? Colors
                                                                                .green
                                                                            : percentage ==
                                                                                '0'
                                                                            ? TColors
                                                                                .third
                                                                            : TColors
                                                                                .primary,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontSize: 14,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            
                                                if (timezone != null) ...[
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.public,
                                                        size: 16,
                                                        color: TColors.grey,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Timezone: $timezone',
                                                        style: const TextStyle(
                                                          color: TColors.grey,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            );
                          }).toList(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
          );
        }
      }
    } catch (e) {
      // Dismiss loading dialog if still showing
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
      print('Error showing cancellation policy: $e');
    }
  }

 void _showPriceBreakup(BuildContext context) async {
  final apiService = ApiServiceHotel();
  final controller = Get.find<SearchHotelController>();

  // Show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (context) => const Center(
          child: CircularProgressIndicator(color: TColors.primary),
        ),
  );

  try {
    final response = await apiService.getPriceBreakup(
      sessionId: controller.sessionId.value,
      hotelCode: controller.hotelCode.value,
      groupCode: room['groupCode'] as int,
      currency: "USD",
      rateKeys: [room['rateKey']],
    );

    // Dismiss loading dialog
    // ignore: use_build_context_synchronously
    Navigator.pop(context);

    if (response != null) {
      final priceBreakdown = response['priceBreakdown'] as List?;
      if (priceBreakdown?.isNotEmpty ?? false) {
        final roomData = priceBreakdown![0];
        print(roomData['dateRange']);
        final dateRanges =
            roomData['dateRange'] != null
                ? List<Map<String, dynamic>>.from(roomData['dateRange'])
                : null;

        showDialog(
          // ignore: use_build_context_synchronously
          context: context,
          barrierDismissible: false,
          builder:
              (context) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  height: 600,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: TColors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Price Breakup Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: TColors.text,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: TColors.iconclr,
                            ),
                            onPressed: () {
                              try {
                                Navigator.pop(context);
                              } catch (e) {
                                // Context no longer valid
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(color: TColors.background3),
                      if (dateRanges == null || dateRanges.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No price breakup details available for this room.',
                            style: TextStyle(color: TColors.grey),
                          ),
                        )
                      else
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                // Summary Section











                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: TColors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: TColors.primary.withOpacity(0.1),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildSummaryRow(
                                        'Gross Amount',
                                        ((roomData['grossAmount'] ?? 0) * apiService.currentROE).toStringAsFixed(0),
                                        Icons.monetization_on_outlined,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildSummaryRow(
                                        'Tax',
                                        ((roomData['tax'] ?? 0) * apiService.currentROE).toStringAsFixed(0),
                                        Icons.receipt_long_outlined,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildSummaryRow(
                                        'Net Amount',
                                        ((roomData['netAmount'] ?? 0) * apiService.currentROE).toStringAsFixed(0),
                                        Icons.account_balance_wallet_outlined,
                                      ),
                                    ],
                                  ),
                                ),
                                // Daily Price Breakdown
                                ...dateRanges.map((dateRange) {
                                  print(dateRanges);
                                  final fromDate = DateTime.tryParse(
                                    dateRange['fromDate'] ?? '',
                                  );
                                  if (fromDate == null) {
                                    return const SizedBox.shrink();
                                  }

                                  // Convert supplier price to PKR
                                  final supplierPrice = double.tryParse(dateRange['supplierText']?.toString() ?? '0') ?? 0.0;
                                  final priceInPKR = (supplierPrice * apiService.currentROE);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: TColors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: TColors.primary.withOpacity(
                                          0.1,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(
                                                8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: TColors.primary
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.calendar_today,
                                                color: TColors.iconclr,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                DateFormat(
                                                  'MMM dd, yyyy',
                                                ).format(fromDate),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Price for this night',
                                              style: TextStyle(
                                                color: TColors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'PKR ${priceInPKR.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: TColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
        );
      }
    }
  } catch (e) {
    // Dismiss loading dialog if still showing
    // ignore: use_build_context_synchronously
    Navigator.pop(context);
    print('Error showing price breakup: $e');
  }
}

Widget _buildSummaryRow(String label, String value, IconData icon) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Icon(icon, size: 15, color: TColors.iconclr),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: TColors.grey, fontSize: 13),
          ),
        ],
      ),
      Text(
        'PKR $value',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: TColors.text,
        ),
      ),
    ],
  );
}
  @override
  Widget build(BuildContext context) {
    final pricePerNight = (room['price']['net']) / nights ?? 0.0;
    final totalPrice = pricePerNight * nights;
    final isRefundable = (room['rateType'] ?? '').toLowerCase() == 'refundable';

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? TColors.primary.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? TColors.primary : Colors.grey.shade100,
          width: isSelected ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Content Area
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Meal Type + Refundable Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meal Icon & Text
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  TColors.primary.withOpacity(0.15),
                                  TColors.primary.withOpacity(0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getMealIcon(room['meal'] ?? ''),
                              color: TColors.iconclr,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              room['meal'] ?? 'Room Only',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Refundable Badge
                    _buildRefundableBadge(isRefundable),
                  ],
                ),
                
                const SizedBox(height: 14),
                
                // Price Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      // Per Night Price
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.dark_mode_outlined,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Per Night',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'PKR ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: NumberFormat('#,###').format(pricePerNight.round()),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Divider
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.shade300,
                      ),
                      // Total Price
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Total ($nights ${nights == 1 ? 'night' : 'nights'})',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'PKR ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: TColors.primary.withOpacity(0.7),
                                      ),
                                    ),
                                    TextSpan(
                                      text: NumberFormat('#,###').format(totalPrice.round()),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: TColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // // Remarks (if any)
                // if (room['remarks']?['remark'] != null) ...[
                //   const SizedBox(height: 10),
                //   Row(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Icon(
                //         Icons.info_outline_rounded,
                //         size: 14,
                //         color: Colors.grey.shade400,
                //       ),
                //       const SizedBox(width: 6),
                //       Expanded(
                //         child: Text(
                //           room['remarks']['remark'][0]['text'] ?? '',
                //           style: TextStyle(
                //             color: Colors.grey.shade500,
                //             fontSize: 11,
                //             height: 1.4,
                //           ),
                //           maxLines: 2,
                //           overflow: TextOverflow.ellipsis,
                //         ),
                //       ),
                //     ],
                //   ),
                // ],
                //
                const SizedBox(height: 12),
                //
                // Action Buttons Row
                Row(
                  children: [
                    // Info Links
                    InkWell(
                      onTap: () => _showCancellationPolicy(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.policy_outlined,
                              size: 14,
                              color: TColors.iconclr.withOpacity(0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Policy',
                              style: TextStyle(
                                color: TColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 16,
                      color: Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    InkWell(
                      onTap: () => _showPriceBreakup(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_outlined,
                              size: 14,
                              color: TColors.iconclr.withOpacity(0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Breakup',
                              style: TextStyle(
                                color: TColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Book Now / Select Button
                    _buildActionButton(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton() {
    if (showBookNowButton) {
      return SizedBox(
        height: 36,
        child: ElevatedButton(
          onPressed: isLoading ? null : () => onSelect(room),
          style: ElevatedButton.styleFrom(
            backgroundColor: TColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Book Now',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: isSelected
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Selected',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          : OutlinedButton(
              onPressed: () => onSelect(room),
              style: OutlinedButton.styleFrom(
                foregroundColor: TColors.primary,
                side: BorderSide(color: TColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Select',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
    );
  }

  Widget _buildRefundableBadge(bool isRefundable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isRefundable ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isRefundable 
              ? Colors.green.shade200 
              : Colors.red.shade200,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRefundable ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 13,
            color: isRefundable ? Colors.green.shade600 : Colors.red.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            isRefundable ? 'Refundable' : 'Non-refundable',
            style: TextStyle(
              color: isRefundable ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getMealIcon(String meal) {
    final lowerMeal = meal.toLowerCase();
    if (lowerMeal.contains('breakfast')) {
      return Icons.free_breakfast_outlined;
    } else if (lowerMeal.contains('lunch') || lowerMeal.contains('dinner')) {
      return Icons.restaurant_outlined;
    } else if (lowerMeal.contains('all inclusive') || lowerMeal.contains('full board')) {
      return Icons.dining_outlined;
    } else if (lowerMeal.contains('half board')) {
      return Icons.brunch_dining_outlined;
    }
    return Icons.hotel_outlined;
  }
}

