import 'package:flutter/material.dart';
import '../../../utility/colors.dart';
import '../../../utility/app_constants.dart';
import 'group_selection_screen.dart';

class GroupTicketsSelector extends StatelessWidget {
  const GroupTicketsSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: _buildGroupBox(
            title: 'UMRAH GROUP',
            icon: Icons.mosque,
            onTap: () {
              _navigateToGroupSelection(context, 'UMRAH GROUP');
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _buildGroupBox(
            title: 'ONE WAY GROUP',
            icon: Icons.flight,
            onTap: () {
              _navigateToGroupSelection(context, 'ONE WAY GROUP');
            },
          ),
        ),
      ],
    );
  }
  
  void _navigateToGroupSelection(BuildContext context, String groupType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupSelectionScreen(
          groupType: groupType,
        ),
      ),
    );
  }

  Widget _buildGroupBox({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(
            color: AppConstants.fieldBorderColor,
            width: 1,
          ),
          boxShadow: AppConstants.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              child: Icon(
                icon,
                size: AppConstants.iconSize * 1.5,
                color: TColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

