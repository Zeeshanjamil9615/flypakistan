import 'package:flutter/material.dart';
import '../../../utility/colors.dart';
import '../../../utility/app_constants.dart';

class TypeSelector extends StatefulWidget {
  final ValueChanged<String> onTypeChanged;

  const TypeSelector({super.key, required this.onTypeChanged});

  @override
  TypeSelectorState createState() => TypeSelectorState();
}

class TypeSelectorState extends State<TypeSelector> {
  String selectedType = 'Flights';

  final List<Map<String, dynamic>> travelTypes = [
    {'icon': Icons.flight_takeoff, 'label': 'Flights'},
    {'icon': Icons.hotel, 'label': 'Hotels'},
    {'icon': Icons.group, 'label': 'Group Tickets'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: travelTypes.map((type) {
          final isSelected = selectedType == type['label'];

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedType = type['label'];
                widget.onTypeChanged(selectedType);
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        type['icon'],
                        size: 24,
                        color: isSelected
                            ? TColors.primary
                            : AppConstants.tabInactiveColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        type['label'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? TColors.primary
                              : AppConstants.tabInactiveColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Container(
                    height: 3,
                    width: 50,
                    decoration: BoxDecoration(
                      color: isSelected ? TColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}