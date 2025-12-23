import 'package:flutter/material.dart';
import '../utility/colors.dart';
import '../utility/app_constants.dart';

class GroupDatePickerSheet extends StatefulWidget {
  final DateTime? selectedDate;
  final DateTime? initialDate;
  final Function(DateTime)? onDateSelected;
  final String title;
  final String fieldType; // 'dob', 'doi', 'passportExpiry'
  final String passengerType; // 'Adult', 'Child', 'Infant'

  const GroupDatePickerSheet({
    super.key,
    this.selectedDate,
    this.initialDate,
    this.onDateSelected,
    required this.title,
    required this.fieldType,
    required this.passengerType,
  });

  @override
  State<GroupDatePickerSheet> createState() => _GroupDatePickerSheetState();
}

class _GroupDatePickerSheetState extends State<GroupDatePickerSheet> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  late DateTime _today;
  DateTime? _firstDate;
  DateTime? _lastDate;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _calculateDateConstraints();
    
    print('🔍 [GroupDatePicker] Initializing for fieldType: ${widget.fieldType}, passengerType: ${widget.passengerType}');
    print('🔍 [GroupDatePicker] _firstDate: $_firstDate, _lastDate: $_lastDate');
    
    // Auto-set initial date based on field type and passenger type
    bool hasValidDate = false;
    
    if (widget.selectedDate != null) {
      print('🔍 [GroupDatePicker] Checking widget.selectedDate: ${widget.selectedDate}');
      if (!_isDateDisabled(widget.selectedDate!)) {
        print('✅ [GroupDatePicker] widget.selectedDate is valid, using it');
        _currentMonth = widget.selectedDate!;
        _selectedDate = widget.selectedDate!;
        hasValidDate = true;
      } else {
        print('⚠️ [GroupDatePicker] widget.selectedDate is disabled (outside valid range)');
      }
    }
    
    if (!hasValidDate && widget.initialDate != null) {
      print('🔍 [GroupDatePicker] Checking widget.initialDate: ${widget.initialDate}');
      if (!_isDateDisabled(widget.initialDate!)) {
        print('✅ [GroupDatePicker] widget.initialDate is valid, using it');
        _currentMonth = widget.initialDate!;
        _selectedDate = widget.initialDate!;
        hasValidDate = true;
      } else {
        print('⚠️ [GroupDatePicker] widget.initialDate is disabled (outside valid range), will find valid date');
      }
    }
    
    // If we still don't have a valid date, calculate one
    if (!hasValidDate) {
      print('🔍 [GroupDatePicker] Auto-calculating initial date');
      // Auto-set year based on field type and passenger type
      final now = DateTime.now();
      int targetYear;
      
      if (widget.fieldType == 'dob') {
        // Date of Birth
        if (widget.passengerType == 'Adult') {
          targetYear = now.year - 12; // 12 years ago for adult
        } else if (widget.passengerType == 'Child') {
          targetYear = now.year - 2; // 2 years ago for child
        } else {
          // Infant: current year
          targetYear = now.year;
        }
      } else if (widget.fieldType == 'doi') {
        // Date of Issue: current year
        targetYear = now.year;
      } else if (widget.fieldType == 'passportExpiry') {
        // Passport Expiry: current year
        targetYear = now.year;
      } else {
        targetYear = now.year;
      }
      
      // Find a valid month and date in the target year
      // For DOB (Adult/Child), we need to find a month that definitely has valid dates
      DateTime? validDate;
      DateTime? validMonth;
      
      // For Adult and Child DOB, the lastDate is restrictive (exact day match)
      // So we need to find a month that's definitely before the lastDate
      if (widget.fieldType == 'dob') {
        if (widget.passengerType == 'Adult' || widget.passengerType == 'Child') {
          print('🔍 [GroupDatePicker] Searching for valid date for ${widget.passengerType} DOB in year $targetYear');
          
          // For Adult/Child, find a month that's definitely before the lastDate
          // Start from January and go forward until we find a valid month
          for (int month = 1; month <= 12; month++) {
            // Quick check: does this month have any valid dates?
            if (!_hasValidDatesInMonth(targetYear, month)) {
              print('🔍 [GroupDatePicker] Month $month in year $targetYear has no valid dates, skipping');
              continue;
            }
            
            // Try to find a valid date in this month
            final testMaxDay = DateTime(targetYear, month + 1, 0).day;
            for (int day = 1; day <= testMaxDay; day++) {
              final testDate = DateTime(targetYear, month, day);
              if (!_isDateDisabled(testDate)) {
                print('✅ [GroupDatePicker] Found valid date: $testDate in month $month');
                validDate = testDate;
                validMonth = DateTime(targetYear, month, 1);
                break;
              }
            }
            
            if (validDate != null) break;
          }
          
          // If still no valid date found, try one year before (for adult)
          if (validDate == null && widget.passengerType == 'Adult') {
            print('⚠️ [GroupDatePicker] No valid date found in target year, trying previous year');
            final testYear = targetYear - 1;
            if (_firstDate == null || testYear >= _firstDate!.year) {
              // Start from a safe month (like January) that should have valid dates
              for (int month = 1; month <= 12; month++) {
                if (!_hasValidDatesInMonth(testYear, month)) {
                  continue;
                }
                final testMaxDay = DateTime(testYear, month + 1, 0).day;
                for (int day = 1; day <= testMaxDay; day++) {
                  final testDate = DateTime(testYear, month, day);
                  if (!_isDateDisabled(testDate)) {
                    print('✅ [GroupDatePicker] Found valid date in previous year: $testDate');
                    validDate = testDate;
                    validMonth = DateTime(testYear, month, 1);
                    break;
                  }
                }
                if (validDate != null) break;
              }
            }
          }
        } else {
          // For Infant, use simpler logic
          for (int month = 1; month <= 12; month++) {
            final testMaxDay = DateTime(targetYear, month + 1, 0).day;
            for (int day = 1; day <= testMaxDay; day++) {
              final testDate = DateTime(targetYear, month, day);
              if (!_isDateDisabled(testDate)) {
                validDate = testDate;
                validMonth = DateTime(targetYear, month, 1);
                break;
              }
            }
            if (validDate != null) break;
          }
        }
      } else {
        // For DOI and Passport Expiry, use simpler logic
        for (int month = 1; month <= 12; month++) {
          final testMaxDay = DateTime(targetYear, month + 1, 0).day;
          for (int day = 1; day <= testMaxDay; day++) {
            final testDate = DateTime(targetYear, month, day);
            if (!_isDateDisabled(testDate)) {
              validDate = testDate;
              validMonth = DateTime(targetYear, month, 1);
              break;
            }
          }
          if (validDate != null) break;
        }
      }
      
      // Set current month and selected date
      if (validMonth != null && validDate != null) {
        print('🔍 [GroupDatePicker] Found valid date: $validDate in month: $validMonth');
        _currentMonth = validMonth;
        _selectedDate = validDate;
      } else {
        print('⚠️ [GroupDatePicker] No valid date found, using fallback');
        // Fallback: use January of target year (should be safe for most cases)
        _currentMonth = DateTime(targetYear, 1, 1);
        final fallbackDate = DateTime(targetYear, 1, 15);
        if (!_isDateDisabled(fallbackDate)) {
          print('✅ [GroupDatePicker] Fallback date is valid: $fallbackDate');
          _selectedDate = fallbackDate;
        } else {
          print('⚠️ [GroupDatePicker] Fallback date is disabled, searching for valid date in January');
          // Find first valid date in January
          bool foundValid = false;
          for (int day = 1; day <= 31; day++) {
            final testDate = DateTime(targetYear, 1, day);
            if (!_isDateDisabled(testDate)) {
              print('✅ [GroupDatePicker] Found valid date in January: $testDate');
              _selectedDate = testDate;
              foundValid = true;
              break;
            }
          }
          // If still no valid date, use first day (even if disabled, it will be shown)
          if (!foundValid) {
            print('⚠️ [GroupDatePicker] No valid date found in January, using first day');
            _selectedDate = DateTime(targetYear, 1, 1);
          }
        }
      }
      
      print('🔍 [GroupDatePicker] Final _currentMonth: $_currentMonth');
      print('🔍 [GroupDatePicker] Final _selectedDate: $_selectedDate');
      print('🔍 [GroupDatePicker] Is _selectedDate disabled? ${_isDateDisabled(_selectedDate)}');
    }
  }

  void _calculateDateConstraints() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (widget.fieldType == 'dob') {
      // Date of Birth constraints based on passenger type
      if (widget.passengerType == 'Infant') {
        // Infant: must be at least 1 day old, less than 2 years
        _firstDate = DateTime(now.year - 2, now.month, now.day).add(const Duration(days: 1));
        _lastDate = today.subtract(const Duration(days: 1));
      } else if (widget.passengerType == 'Child') {
        // Child: must be at least 2 years old, less than 12 years
        _firstDate = DateTime(now.year - 12, now.month, now.day).add(const Duration(days: 1));
        _lastDate = DateTime(now.year - 2, now.month, now.day);
      } else {
        // Adult: must be at least 12 years old, no upper limit
        _firstDate = DateTime(now.year - 120, 1, 1); // 120 years ago, start of year
        _lastDate = DateTime(now.year - 12, now.month, now.day);
      }
    } else if (widget.fieldType == 'doi') {
      // Date of Issue: cannot be in the future
      _firstDate = DateTime(now.year - 20, 1, 1); // 20 years ago, start of year
      _lastDate = today;
    } else if (widget.fieldType == 'passportExpiry') {
      // Passport Expiry: cannot be in the past, at least today
      _firstDate = today;
      _lastDate = DateTime(now.year + 20, 12, 31); // 20 years from now, end of year
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
    print('🔍 [GroupDatePicker] _selectDate called with: $date');
    print('🔍 [GroupDatePicker] Is date disabled? ${_isDateDisabled(date)}');
    
    if (_isDateDisabled(date)) {
      print('❌ [GroupDatePicker] Date is disabled, cannot select');
      return;
    }
    
    print('✅ [GroupDatePicker] Date is valid, selecting...');
    setState(() {
      _selectedDate = date;
    });
    widget.onDateSelected?.call(date);
    Navigator.pop(context);
  }

  bool _isDateSelected(DateTime date) {
    return _selectedDate.year == date.year &&
        _selectedDate.month == date.month &&
        _selectedDate.day == date.day;
  }

  bool _isDateDisabled(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (_firstDate != null) {
      final firstDateOnly = DateTime(_firstDate!.year, _firstDate!.month, _firstDate!.day);
      if (dateOnly.isBefore(firstDateOnly)) {
        return true;
      }
    }
    
    if (_lastDate != null) {
      final lastDateOnly = DateTime(_lastDate!.year, _lastDate!.month, _lastDate!.day);
      if (dateOnly.isAfter(lastDateOnly)) {
        return true;
      }
    }
    
    return false;
  }
  
  // Helper method to check if a month has any valid dates
  bool _hasValidDatesInMonth(int year, int month) {
    final maxDay = DateTime(year, month + 1, 0).day;
    for (int day = 1; day <= maxDay; day++) {
      final testDate = DateTime(year, month, day);
      if (!_isDateDisabled(testDate)) {
        return true;
      }
    }
    return false;
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
      height: MediaQuery.of(context).size.height * 0.75,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getDateRangeHint(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
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

          // Month Navigation with Quick Selection
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _canGoToPreviousMonth() ? _previousMonth : null,
                  icon: Icon(
                    Icons.chevron_left,
                    color: _canGoToPreviousMonth() ? TColors.primary : Colors.grey[300],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Clickable Month
                    GestureDetector(
                      onTap: () => _showMonthPicker(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getMonthName(_currentMonth.month),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, size: 20, color: TColors.primary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Clickable Year
                    GestureDetector(
                      onTap: () => _showYearPicker(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_getDisplayYear()}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, size: 20, color: TColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _canGoToNextMonth() ? _nextMonth : null,
                  icon: Icon(
                    Icons.chevron_right,
                    color: _canGoToNextMonth() ? TColors.primary : Colors.grey[300],
                  ),
                ),
              ],
            ),
          ),

          // Days of Week Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: day == 'Sa' || day == 'Su' 
                                  ? TColors.primary 
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Calendar Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCalendarGrid(_currentMonth),
            ),
          ),

          // Selected Date Display
          if (_selectedDate != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 16, color: TColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    _formatSelectedDate(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: TColors.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getDateRangeHint() {
    if (widget.fieldType == 'dob') {
      if (widget.passengerType == 'Infant') {
        return 'Select date between 1 day and 2 years ago';
      } else if (widget.passengerType == 'Child') {
        return 'Select date between 2 and 12 years ago';
      } else {
        return 'Select date (at least 12 years ago)';
      }
    } else if (widget.fieldType == 'doi') {
      return 'Select date (cannot be in the future)';
    } else if (widget.fieldType == 'passportExpiry') {
      return 'Select date (cannot be in the past)';
    }
    return '';
  }

  String _formatSelectedDate() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  bool _canGoToPreviousMonth() {
    if (_firstDate == null) return true;
    final prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    return prevMonth.year >= _firstDate!.year || 
           (prevMonth.year == _firstDate!.year && prevMonth.month >= _firstDate!.month);
  }

  bool _canGoToNextMonth() {
    if (_lastDate == null) return true;
    final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    return nextMonth.year <= _lastDate!.year || 
           (nextMonth.year == _lastDate!.year && nextMonth.month <= _lastDate!.month);
  }

  int _getDisplayYear() {
    // Show the current month's year if it's valid, otherwise show most recent valid year
    final currentYear = _currentMonth.year;
    
    // Check if current year is within the valid range
    if (_firstDate != null && currentYear < _firstDate!.year) {
      return _getMostRecentValidYear();
    }
    if (_lastDate != null && currentYear > _lastDate!.year) {
      return _getMostRecentValidYear();
    }
    
    // Additional validation based on field type
    final now = DateTime.now();
    if (widget.fieldType == 'dob') {
      if (widget.passengerType == 'Adult') {
        // Adult: year should be <= (now.year - 12)
        if (currentYear > (now.year - 12)) {
          return _getMostRecentValidYear();
        }
      } else if (widget.passengerType == 'Child') {
        // Child: year should be between (now.year - 12) and (now.year - 2)
        if (currentYear < (now.year - 12) || currentYear > (now.year - 2)) {
          return _getMostRecentValidYear();
        }
      } else {
        // Infant: year should be >= (now.year - 2) and <= now.year
        if (currentYear < (now.year - 2) || currentYear > now.year) {
          return _getMostRecentValidYear();
        }
      }
    } else if (widget.fieldType == 'doi') {
      // DOI: year should be <= now.year
      if (currentYear > now.year) {
        return _getMostRecentValidYear();
      }
    } else if (widget.fieldType == 'passportExpiry') {
      // Passport Expiry: year should be >= now.year
      if (currentYear < now.year) {
        return _getMostRecentValidYear();
      }
    }
    
    // Current year is valid, show it
    return currentYear;
  }

  int _getMostRecentValidYear() {
    final now = DateTime.now();
    
    if (widget.fieldType == 'dob') {
      if (widget.passengerType == 'Adult') {
        // Adult: most recent is 12 years ago
        return now.year - 12;
      } else if (widget.passengerType == 'Child') {
        // Child: most recent is 2 years ago
        return now.year - 2;
      } else {
        // Infant: most recent is current year
        return now.year;
      }
    } else if (widget.fieldType == 'doi') {
      // DOI: most recent is current year
      return now.year;
    } else if (widget.fieldType == 'passportExpiry') {
      // Passport Expiry: most recent is current year
      return now.year;
    }
    
    return now.year;
  }

  void _showMonthPicker() {
    final months = List.generate(12, (index) => index + 1);
    final currentMonth = _currentMonth.month;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 400,
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
              padding: const EdgeInsets.all(16),
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
                  const Text(
                    'Select Month',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                ),
                itemCount: months.length,
                itemBuilder: (context, index) {
                  final month = months[index];
                  final isSelected = month == currentMonth;
                  final monthDate = DateTime(_currentMonth.year, month, 1);
                  final isDisabled = _isDateDisabled(monthDate) && 
                                     _isDateDisabled(DateTime(_currentMonth.year, month, 28));
                  
                  return GestureDetector(
                    onTap: isDisabled ? null : () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, month, 1);
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? TColors.primary 
                            : isDisabled 
                                ? Colors.grey[100] 
                                : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected 
                              ? TColors.primary 
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _getMonthName(month).substring(0, 3),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isDisabled 
                                ? Colors.grey[400] 
                                : isSelected 
                                    ? Colors.white 
                                    : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showYearPicker() {
    final now = DateTime.now();
    List<int> years = [];
    
    if (widget.fieldType == 'dob') {
      // For DOB, show years going backwards (oldest first)
      if (widget.passengerType == 'Adult') {
        // Adult: 12 to 120 years ago (oldest first)
        for (int i = 12; i <= 120; i++) {
          years.add(now.year - i);
        }
      } else if (widget.passengerType == 'Child') {
        // Child: 2 to 12 years ago (oldest first)
        for (int i = 2; i <= 12; i++) {
          years.add(now.year - i);
        }
      } else {
        // Infant: 0 to 2 years ago (oldest first)
        for (int i = 0; i <= 2; i++) {
          years.add(now.year - i);
        }
      }
    } else if (widget.fieldType == 'doi') {
      // DOI: now to 20 years ago (recent years first)
      for (int i = 0; i <= 20; i++) {
        years.add(now.year - i);
      }
    } else if (widget.fieldType == 'passportExpiry') {
      // Passport Expiry: now to 20 years ahead
      for (int i = 0; i <= 20; i++) {
        years.add(now.year + i);
      }
    }
    
    final currentYear = _currentMonth.year;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 500,
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
              padding: const EdgeInsets.all(16),
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
                  const Text(
                    'Select Year',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final year = years[index];
                  final isSelected = year == currentYear;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        // Keep the same month, just change year
                        final newMonth = _currentMonth.month;
                        _currentMonth = DateTime(year, newMonth, 1);
                        // Adjust selected date if needed
                        final maxDay = DateTime(year, newMonth + 1, 0).day;
                        final selectedDay = _selectedDate.day > maxDay ? maxDay : _selectedDate.day;
                        _selectedDate = DateTime(year, newMonth, selectedDay);
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? TColors.primary : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? TColors.primary : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            year.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
      final isDisabled = _isDateDisabled(date);
      final isToday = date.year == _today.year &&
          date.month == _today.month &&
          date.day == _today.day;

      dayWidgets.add(
        GestureDetector(
          onTap: isDisabled ? null : () {
            print('🔍 [GroupDatePicker] Day $day tapped, date: $date, disabled: $isDisabled');
            _selectDate(date);
          },
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isSelected 
                  ? TColors.primary 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected
                  ? Border.all(color: TColors.primary, width: 1.5)
                  : null,
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isDisabled
                      ? Colors.grey[300]
                      : isSelected
                          ? Colors.white
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
Future<DateTime?> showGroupDatePicker({
  required BuildContext context,
  DateTime? selectedDate,
  DateTime? initialDate,
  required String title,
  required String fieldType,
  required String passengerType,
}) {
  DateTime? result;
  
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    isDismissible: true,
    useSafeArea: true,
    builder: (context) => _AnimatedGroupDatePickerSheet(
      selectedDate: selectedDate,
      initialDate: initialDate,
      title: title,
      fieldType: fieldType,
      passengerType: passengerType,
      onDateSelected: (date) {
        result = date;
      },
    ),
  ).then((_) => result);
}

// Animated wrapper for the date picker sheet
class _AnimatedGroupDatePickerSheet extends StatefulWidget {
  final DateTime? selectedDate;
  final DateTime? initialDate;
  final Function(DateTime)? onDateSelected;
  final String title;
  final String fieldType;
  final String passengerType;

  const _AnimatedGroupDatePickerSheet({
    this.selectedDate,
    this.initialDate,
    this.onDateSelected,
    required this.title,
    required this.fieldType,
    required this.passengerType,
  });

  @override
  State<_AnimatedGroupDatePickerSheet> createState() => _AnimatedGroupDatePickerSheetState();
}

class _AnimatedGroupDatePickerSheetState extends State<_AnimatedGroupDatePickerSheet>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
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
                child: GroupDatePickerSheet(
                  selectedDate: widget.selectedDate,
                  initialDate: widget.initialDate,
                  onDateSelected: widget.onDateSelected,
                  title: widget.title,
                  fieldType: widget.fieldType,
                  passengerType: widget.passengerType,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

