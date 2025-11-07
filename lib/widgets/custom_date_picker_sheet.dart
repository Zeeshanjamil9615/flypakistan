import 'package:flutter/material.dart';
import '../utility/colors.dart';
import '../utility/app_constants.dart';

class CustomDatePickerSheet extends StatefulWidget {
  final DateTime? selectedDate;
  final DateTime? initialDate;
  final DateTimeRange? selectedDateRange;
  final Function(DateTime)? onDateSelected;
  final Function(DateTimeRange)? onDateRangeSelected;
  final String title;
  final String? label;
  final bool isRangeSelection;

  const CustomDatePickerSheet({
    super.key,
    this.selectedDate,
    this.initialDate,
    this.selectedDateRange,
    this.onDateSelected,
    this.onDateRangeSelected,
    required this.title,
    this.label,
    this.isRangeSelection = false,
  });

  @override
  State<CustomDatePickerSheet> createState() => _CustomDatePickerSheetState();
}

class _CustomDatePickerSheetState extends State<CustomDatePickerSheet> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  late DateTime _today;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSelectingStart = true;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    // Always start with current month
    _currentMonth = DateTime(_today.year, _today.month);
    _selectedDate = widget.selectedDate ?? _today;
    
    if (widget.isRangeSelection && widget.selectedDateRange != null) {
      _startDate = widget.selectedDateRange!.start;
      _endDate = widget.selectedDateRange!.end;
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  void _selectDate(DateTime date) {
    if (widget.isRangeSelection) {
      setState(() {
        if (_isSelectingStart || _startDate == null) {
          _startDate = date;
          _endDate = null;
          _isSelectingStart = false;
        } else {
          if (date.isBefore(_startDate!)) {
            _endDate = _startDate;
            _startDate = date;
          } else {
            _endDate = date;
          }
          _isSelectingStart = true;
        }
      });
      
      if (_startDate != null && _endDate != null) {
        widget.onDateRangeSelected!(DateTimeRange(start: _startDate!, end: _endDate!));
        Navigator.pop(context);
      }
    } else {
      setState(() {
        _selectedDate = date;
      });
      widget.onDateSelected!(date);
      Navigator.pop(context);
    }
  }

  bool _isDateSelected(DateTime date) {
    if (widget.isRangeSelection) {
      if (_startDate != null && _endDate != null) {
        return date.isAtSameMomentAs(_startDate!) || date.isAtSameMomentAs(_endDate!);
      } else if (_startDate != null) {
        return date.isAtSameMomentAs(_startDate!);
      }
      return false;
    } else {
      return _selectedDate.year == date.year &&
          _selectedDate.month == date.month &&
          _selectedDate.day == date.day;
    }
  }

  bool _isDateInRange(DateTime date) {
    if (widget.isRangeSelection && _startDate != null && _endDate != null) {
      return date.isAfter(_startDate!) && date.isBefore(_endDate!);
    }
    return false;
  }

  bool _isDateDisabled(DateTime date) {
    return date.isBefore(DateTime(_today.year, _today.month, _today.day));
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
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
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // Multiple Months - Vertical Layout (12 months)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Current Month + Next 11 Months (12 months total)
                  for (int i = 0; i < 12; i++) ...[
                    _buildMonthCalendar(DateTime(_currentMonth.year, _currentMonth.month + i)),
                    if (i < 11) const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),

          // Selected Date Label
          if (widget.label != null && _isDateSelected(_selectedDate))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: TColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.label!,
                  style: TextStyle(
                    color: TColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar(DateTime month) {
    return Column(
      children: [
        // Month Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '${_getMonthName(month.month)} ${month.year}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        
        // Days of Week Header
        Row(
          children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: day == 'Sa' || day == 'Su' 
                              ? TColors.primary 
                              : Colors.black54,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        
        const SizedBox(height: 8),
        
        // Calendar Grid
        _buildCalendarGrid(month),
      ],
    );
  }

  Widget _buildCalendarGrid(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    List<Widget> dayWidgets = [];

    // Add empty cells for days before the first day of the month
    for (int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }

    // Add day cells for the current month
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isSelected = _isDateSelected(date);
      final isInRange = _isDateInRange(date);
      final isDisabled = _isDateDisabled(date);
      final isToday = date.year == _today.year &&
          date.month == _today.month &&
          date.day == _today.day;

      dayWidgets.add(
        GestureDetector(
          onTap: isDisabled ? null : () => _selectDate(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected 
                  ? TColors.primary 
                  : isInRange 
                      ? TColors.primary.withOpacity(0.2)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected && !isInRange
                  ? Border.all(color: TColors.primary, width: 1)
                  : null,
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isDisabled
                      ? Colors.grey.shade400
                      : isSelected
                          ? Colors.white
                          : isInRange
                              ? TColors.primary.withOpacity(0.7)
                              : isToday
                                  ? TColors.primary
                                  : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: dayWidgets.length,
      itemBuilder: (context, index) => dayWidgets[index],
    );
  }
}

// Helper function to show the date picker sheet
Future<DateTime?> showCustomDatePicker({
  required BuildContext context,
  DateTime? selectedDate,
  DateTime? initialDate,
  required String title,
  String? label,
}) {
  DateTime? result;
  
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    isDismissible: true,
    useSafeArea: true,
    builder: (context) => _AnimatedDatePickerSheet(
      selectedDate: selectedDate,
      initialDate: initialDate,
      title: title,
      label: label,
      isRangeSelection: false,
      onDateSelected: (date) {
        result = date;
      },
    ),
  ).then((_) => result);
}

// Helper function to show the date range picker sheet
Future<DateTimeRange?> showCustomDateRangePicker({
  required BuildContext context,
  DateTimeRange? selectedDateRange,
  DateTime? initialDate,
  required String title,
  String? label,
}) {
  DateTimeRange? result;
  
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    isDismissible: true,
    useSafeArea: true,
    builder: (context) => _AnimatedDatePickerSheet(
      selectedDateRange: selectedDateRange,
      initialDate: initialDate,
      title: title,
      label: label,
      isRangeSelection: true,
      onDateRangeSelected: (dateRange) {
        result = dateRange;
      },
    ),
  ).then((_) => result);
}

// Animated wrapper for the date picker sheet
class _AnimatedDatePickerSheet extends StatefulWidget {
  final DateTime? selectedDate;
  final DateTime? initialDate;
  final DateTimeRange? selectedDateRange;
  final Function(DateTime)? onDateSelected;
  final Function(DateTimeRange)? onDateRangeSelected;
  final String title;
  final String? label;
  final bool isRangeSelection;

  const _AnimatedDatePickerSheet({
    this.selectedDate,
    this.initialDate,
    this.selectedDateRange,
    this.onDateSelected,
    this.onDateRangeSelected,
    required this.title,
    this.label,
    this.isRangeSelection = false,
  });

  @override
  State<_AnimatedDatePickerSheet> createState() => _AnimatedDatePickerSheetState();
}

class _AnimatedDatePickerSheetState extends State<_AnimatedDatePickerSheet>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Slide animation controller
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // Fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Slide animation (bottom to up)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Fade animation for backdrop
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    // Start animations
    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _closeSheet() async {
    await Future.wait([
      _slideController.reverse(),
      _fadeController.reverse(),
    ]);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_slideAnimation, _fadeAnimation]),
      builder: (context, child) {
        return Stack(
          children: [
            // Backdrop with fade animation
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSheet,
                child: Container(
                  color: Colors.black.withOpacity(0.5 * _fadeAnimation.value),
                ),
              ),
            ),
            
            // Date picker sheet with slide animation
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomDatePickerSheet(
                  selectedDate: widget.selectedDate,
                  initialDate: widget.initialDate,
                  selectedDateRange: widget.selectedDateRange,
                  onDateSelected: widget.onDateSelected,
                  onDateRangeSelected: widget.onDateRangeSelected,
                  title: widget.title,
                  label: widget.label,
                  isRangeSelection: widget.isRangeSelection,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
