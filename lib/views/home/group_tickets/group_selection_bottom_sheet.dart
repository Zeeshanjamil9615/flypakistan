import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../utility/colors.dart';
import '../../../utility/app_constants.dart';
import 'group_tickets_controller.dart';

class GroupSelectionBottomSheet extends StatelessWidget {
  final String groupType; // 'UMRAH GROUP' or 'ONE WAY GROUP'
  final ScrollController? scrollController;
  
  const GroupSelectionBottomSheet({
    super.key,
    required this.groupType,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(GroupTicketsController());
    
    // Fetch groups when bottom sheet opens with the correct group type
    controller.fetchAllGroups(groupType: groupType);
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPadding,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: TColors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Select $groupType',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: Obx(() {
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
                controller: scrollController,
                padding: const EdgeInsets.all(AppConstants.cardPadding),
                itemCount: controller.groups.length,
                itemBuilder: (context, index) {
                  final group = controller.groups[index];
                  
                  // Extract group name from API response
                  // Response fields: groupId, groupName, description
                  final groupName = group['groupName'] ?? 
                                   group['name'] ?? 
                                   group['title'] ?? 
                                   'Group ${index + 1}';
                  final groupId = group['groupId'] ?? group['id'] ?? '';
                  final description = group['description'] ?? '';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                      border: Border.all(
                        color: AppConstants.fieldBorderColor,
                        width: 1,
                      ),
                      boxShadow: AppConstants.cardShadow,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.cardPadding,
                        vertical: 8,
                      ),
                      title: Text(
                        groupName.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: description.isNotEmpty
                          ? Text(
                              description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: TColors.primary,
                      ),
                      onTap: () {
                        // TODO: Handle group selection
                        Navigator.of(context).pop();
                        // You can add navigation or callback here
                        if (Get.isRegistered<GroupTicketsController>()) {
                          Get.find<GroupTicketsController>().clearGroups();
                        }
                      },
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

