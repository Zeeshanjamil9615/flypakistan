import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../widgets/colors.dart';
import '../../../../../utility/app_constants.dart';
import '../../../../../utility/colors.dart' as ucol;
import 'guests_controller.dart';

class GuestsField extends StatefulWidget {
  const GuestsField({super.key});

  @override
  State<GuestsField> createState() => _GuestsFieldState();
}

class _GuestsFieldState extends State<GuestsField> {

  final GuestsController controller = Get.find<GuestsController>();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showGuestsDialog(context),
      child: Container(
        height: AppConstants.fieldHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(color: AppConstants.fieldBorderColor),
          boxShadow: AppConstants.cardShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.person_outline, color: ucol.TColors.iconclr, size: AppConstants.smallIconSize),
            const SizedBox(width: 8),
            Expanded(
              child: Obx(() => Text(
                '${controller.roomCount.value} Rooms, ${controller.totalAdults} Adults, ${controller.totalChildren} Children',
                style: AppConstants.fieldValueStyle,
                overflow: TextOverflow.ellipsis,
              )),
            ),
          ],
        ),
      ),
    );
  }

  void _showGuestsDialog(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: ucol.TColors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Rooms & Guests',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRoomsRow(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Obx(() => ListView.builder(
                          itemCount: controller.roomCount.value,
                          itemBuilder: (context, index) {
                            return _buildRoomSection(index);
                          },
                        )),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: AppConstants.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ucol.TColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
                      ),
                    ),
                    child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoomsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Rooms', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Obx(() => Row(
          children: [
            IconButton(
              onPressed: controller.decrementRooms,
              icon: const Icon(Icons.remove_circle_outline, color: ucol.TColors.iconclr),
            ),
            Text('${controller.roomCount.value}'),
            IconButton(
              onPressed: controller.incrementRooms,
              icon: const Icon(Icons.add_circle_outline, color: ucol.TColors.iconclr),
            ),
          ],
        )),
      ],
    );
  }

  Widget _buildRoomSection(int roomIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Room ${roomIndex + 1}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ucol.TColors.primary)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Adults'),
            Obx(() => Row(
              children: [
                IconButton(
                  onPressed: () => controller.decrementAdults(roomIndex),
                  icon: const Icon(Icons.remove_circle_outline, color: ucol.TColors.iconclr),
                ),
                Text('${controller.rooms[roomIndex].adults.value}'),
                IconButton(
                  onPressed: () => controller.incrementAdults(roomIndex),
                  icon: const Icon(Icons.add_circle_outline, color: ucol.TColors.iconclr),
                ),
              ],
            )),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Children'),
            Obx(() => Row(
              children: [
                IconButton(
                  onPressed: () => controller.decrementChildren(roomIndex),
                  icon: const Icon(Icons.remove_circle_outline, color: ucol.TColors.iconclr),
                ),
                Text('${controller.rooms[roomIndex].children.value}'),
                IconButton(
                  onPressed: () => controller.incrementChildren(roomIndex),
                  icon: const Icon(Icons.add_circle_outline, color: ucol.TColors.iconclr),
                ),
              ],
            )),
          ],
        ),
        Obx(() => Column(
          children: List.generate(
            controller.rooms[roomIndex].children.value,
                (childIndex) => _buildChildAgeSelector(roomIndex, childIndex),
          ),
        )),
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildChildAgeSelector(int roomIndex, int childIndex) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Child ${childIndex + 1} Age'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<int>(
              value: controller.rooms[roomIndex].childrenAges[childIndex],
              underline: const SizedBox(),
              items: List.generate(18, (index) => DropdownMenuItem(
                value: index,
                child: Text('$index'),
              )),
              onChanged: (age) {
                if (age != null) {
                  controller.updateChildAge(roomIndex, childIndex, age);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}