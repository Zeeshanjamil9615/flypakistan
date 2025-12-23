import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../../../services/api_service_group_tickets.dart';
import '../../../utility/colors.dart';
import '../../../utility/app_constants.dart';
import '../../../widgets/group_date_picker_sheet.dart';
import '../../../views/home/home_screen.dart';
import 'group_booking_thank_you_screen.dart';

class GroupBookingScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  final String groupType;

  const GroupBookingScreen({
    super.key,
    required this.group,
    required this.groupType,
  });

  @override
  State<GroupBookingScreen> createState() => _GroupBookingScreenState();
}

class _GroupBookingScreenState extends State<GroupBookingScreen> {
  final ApiServiceGroupTickets _api = ApiServiceGroupTickets();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _groupDetail;
  List<Map<String, dynamic>> _flights = [];

  int _adults = 1;
  int _children = 0;
  int _infants = 0;
  
  // Passenger data storage
  final Map<int, Map<String, dynamic>> _passengerData = {};
  
  // Helper to get passenger index
  int _getPassengerIndex(int displayIndex) {
    return displayIndex - 1;
  }
  
  // Helper to get passenger type
  String _getPassengerType(int index) {
    if (index < _adults) return 'Adult';
    if (index < _adults + _children) return 'Child';
    return 'Infant';
  }
  
  // Helper to get title options based on type
  List<String> _getTitleOptions(String type) {
    if (type == 'Adult') return ['Mr', 'Mrs', 'Ms'];
    if (type == 'Child') return ['Mstr', 'Miss'];
    return ['INF'];
  }
  
  // Initialize passenger data
  void _initializePassengerData() {
    final total = _adults + _children + _infants;
    for (int i = 0; i < total; i++) {
      if (!_passengerData.containsKey(i)) {
        final type = _getPassengerType(i);
        _passengerData[i] = {
          'title': _getTitleOptions(type).first,
          'givenName': '',
          'surName': '',
          'passportNo': '',
          'dob': null as DateTime?,
          'doi': null as DateTime?,
          'passportExpiry': null as DateTime?,
        };
      }
    }
    // Remove excess entries
    _passengerData.removeWhere((key, _) => key >= total);
  }
  
  // Format date for display
  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd-MM-yyyy').format(date);
  }
  
  // Show date picker
  Future<void> _showDatePicker({
    required BuildContext context,
    required int passengerIndex,
    required String field,
    required String fieldType,
    required String passengerType,
  }) async {
    final currentDate = _passengerData[passengerIndex]?[field] as DateTime?;
    
    final date = await showGroupDatePicker(
      context: context,
      selectedDate: currentDate,
      initialDate: currentDate ?? DateTime.now(),
      title: _getDatePickerTitle(field),
      fieldType: fieldType,
      passengerType: passengerType,
    );
    
    if (date != null && mounted) {
      setState(() {
        _passengerData[passengerIndex] ??= {};
        _passengerData[passengerIndex]![field] = date;
      });
    }
  }
  
  String _getDatePickerTitle(String field) {
    switch (field) {
      case 'dob':
        return 'Select Date of Birth';
      case 'doi':
        return 'Select Date of Issue';
      case 'passportExpiry':
        return 'Select Passport Expiry';
      default:
        return 'Select Date';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _initializePassengerData();
  }

  Future<void> _loadDetails() async {
    final groupId = widget.group['id']?.toString() ?? '';
    if (groupId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Group ID missing';
      });
      return;
    }

    final result = await _api.getGroupDetails(groupId: groupId);
    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'];
      Map<String, dynamic>? detail;
      if (data is Map && data['groups'] is List && (data['groups'] as List).isNotEmpty) {
        detail = Map<String, dynamic>.from(data['groups'][0]);
      }
      setState(() {
        _groupDetail = detail ?? widget.group;
        _flights = _extractFlights(detail ?? widget.group);
        _loading = false;
      });
    } else {
      setState(() {
        _error = result['message'] ?? 'Failed to load group details';
        _groupDetail = widget.group;
        _flights = _extractFlights(widget.group);
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _extractFlights(Map<String, dynamic> group) {
    if (group['details'] is List) {
      final list = List<Map<String, dynamic>>.from(group['details']);
      list.sort((a, b) {
        final srA = a['sr'] ?? 0;
        final srB = b['sr'] ?? 0;
        return srA.compareTo(srB);
      });
      return list;
    }
    return [];
  }

  int get _availableSeats {
    final val = _groupDetail?['available_no_of_pax'] ?? widget.group['available_no_of_pax'] ?? 0;
    return int.tryParse(val.toString()) ?? 0;
  }

  double get _pricePerSeat {
    final price = _groupDetail?['price'] ?? widget.group['price'] ?? '0';
    return double.tryParse(price.toString()) ?? 0;
  }

  double get _childPrice {
    final price = _groupDetail?['price_child'] ?? widget.group['price_child'] ?? '0';
    final parsed = double.tryParse(price.toString()) ?? 0;
    // Fallback to adult price if child price is 0 or not provided
    return parsed > 0 ? parsed : _pricePerSeat;
  }

  double get _infantPrice {
    final price = _groupDetail?['price_infants'] ?? widget.group['price_infants'] ?? '0';
    final parsed = double.tryParse(price.toString()) ?? 0;
    // Fallback to 25% of adult price if infant price is 0 or not provided
    return parsed > 0 ? parsed : (_pricePerSeat * 0.25);
  }

  int get _totalSeatsUsed => _adults + _children; // infants don't take seats

  double get _totalPrice =>
      (_adults * _pricePerSeat) + (_children * _childPrice) + (_infants * _infantPrice);

  void _incrementAdults(bool up) {
    final next = up ? _adults + 1 : (_adults > 1 ? _adults - 1 : 1);
    if (up && _totalSeatsUsed + 1 > _availableSeats) return;
    if (!up && _infants > next) return; // infants <= adults
    setState(() {
      _adults = next;
      _initializePassengerData();
    });
  }

  void _incrementChildren(bool up) {
    final next = up ? _children + 1 : (_children > 0 ? _children - 1 : 0);
    if (up && (_totalSeatsUsed + 1) > _availableSeats) return;
    setState(() {
      _children = next;
      _initializePassengerData();
    });
  }

  void _incrementInfants(bool up) {
    final next = up ? _infants + 1 : (_infants > 0 ? _infants - 1 : 0);
    if (up && next > _adults) return; // infants cannot exceed adults
    setState(() {
      _infants = next;
      _initializePassengerData();
    });
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Group'),
        backgroundColor: TColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 12),
                      _buildFlightsCard(),
                      const SizedBox(height: 12),
                      _buildCountersAndPrice(),
                      const SizedBox(height: 12),
                      _buildPassengersForm(),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _submitting ? null : _submitBooking,
                          child: _submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Submit', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard() {
    final group = _groupDetail ?? widget.group;
    final airline = (group['airline'] is List && (group['airline'] as List).isNotEmpty)
        ? group['airline'][0]
        : null;
    final logoFile = airline != null ? (airline['logo_url'] ?? '') : '';
    final logoUrl =
        logoFile.isNotEmpty ? 'https://alsaboorportal.com/assets/img/airline-logo/$logoFile' : '';
    final airlineName = airline != null ? (airline['airline_name'] ?? '') : '';
    final sector = group['sector']?.toString() ?? '';
    final baggage = group['baggage']?.toString() ?? '';
    final meal = group['meal']?.toString() ?? '';
    final available = _availableSeats;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppConstants.cardShadow,
        border: Border.all(color: AppConstants.fieldBorderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppConstants.fieldBorderColor.withOpacity(0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: logoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: logoUrl,
                      fit: BoxFit.contain,
                    )
                  : Icon(Icons.flight, color: TColors.primary.withOpacity(0.6), size: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (airlineName.isNotEmpty)
                  Text(
                    airlineName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                const SizedBox(height: 4),
                if (sector.isNotEmpty)
                  Text(
                    'Sector: $sector',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (available > 0)
                      _chip(Icons.event_seat, '$available seats', Colors.green[700]!, Colors.green),
                    if (baggage.isNotEmpty)
                      _chip(Icons.luggage, '$baggage KG', Colors.blue[700]!, Colors.blue),
                    if (meal.isNotEmpty)
                      _chip(Icons.restaurant, meal, Colors.orange[700]!, Colors.orange),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.groupType,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                _pricePerSeat > 0 ? 'PKR ${_pricePerSeat.toStringAsFixed(0)}' : '',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: TColors.primary,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color fg, Color bgBase) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgBase.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightsCard() {
    if (_flights.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppConstants.cardShadow,
        border: Border.all(color: AppConstants.fieldBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sector Details',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ..._flights.map((flight) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _flightRow(flight),
              )),
        ],
      ),
    );
  }

  Widget _flightRow(Map<String, dynamic> flight) {
    final route = '${flight['origin'] ?? ''}-${flight['destination'] ?? ''}';
    final times = '${flight['dept_time'] ?? ''} - ${flight['arv_time'] ?? ''}';
    final date = flight['flight_date']?.toString() ?? '';
    final baggage = flight['baggage']?.toString() ?? '';
    final flightNo = flight['flight_no']?.toString() ?? '';
    return Row(
      children: [
        Icon(Icons.flight, size: 14, color: TColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(route, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('$times • $date', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        if (flightNo.isNotEmpty)
          Text('SV$flightNo', style: TextStyle(fontSize: 11, color: TColors.primary)),
        if (baggage.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text('$baggage KG', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ],
    );
  }

  Widget _buildCountersAndPrice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppConstants.cardShadow,
        border: Border.all(color: AppConstants.fieldBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Passengers', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _counterRow('Adults', _adults, canDecrement: _adults > 1, onChange: _incrementAdults),
          _counterRow('Child', _children, onChange: _incrementChildren),
          _counterRow('Infant', _infants, onChange: _incrementInfants),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppConstants.fieldBorderColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _priceLine('Adult', _pricePerSeat),
                    _priceLine('Child', _childPrice),
                    _priceLine('Infant', _infantPrice),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total Price',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                      'PKR ${_totalPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: TColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Seats: $_totalSeatsUsed / $_availableSeats',
                      style: TextStyle(
                        fontSize: 11,
                        color: _totalSeatsUsed <= _availableSeats
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceLine(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: PKR ${value.toStringAsFixed(0)}',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
    );
  }

  Widget _counterRow(String label, int value,
      {required void Function(bool up) onChange, bool canDecrement = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Row(
            children: [
              _counterBtn(Icons.remove, () => onChange(false), enabled: canDecrement),
              Container(
                width: 36,
                alignment: Alignment.center,
                child: Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              _counterBtn(Icons.add, () => onChange(true),
                  enabled: _totalSeatsUsed < _availableSeats || label == 'Infant'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap, {bool enabled = true}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? TColors.primary.withOpacity(0.1) : Colors.grey[200],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppConstants.fieldBorderColor.withOpacity(0.6)),
        ),
        child: Icon(icon, size: 14, color: enabled ? TColors.primary : Colors.grey),
      ),
    );
  }

  Widget _buildPassengersForm() {
    final total = _adults + _children + _infants;
    if (total == 0) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppConstants.cardShadow,
        border: Border.all(color: AppConstants.fieldBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Passengers', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: total,
            itemBuilder: (context, index) {
              final type = _getPassengerType(index);
              return _passengerRow(index + 1, type);
            },
          ),
        ],
      ),
    );
  }

  Widget _passengerRow(int sr, String type) {
    final index = _getPassengerIndex(sr);
    final passenger = _passengerData[index] ?? {};
    final titleOptions = _getTitleOptions(type);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppConstants.fieldBorderColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$type $sr',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _dropdownField(
                  titleOptions,
                  passenger['title'] ?? titleOptions.first,
                  (value) {
                    setState(() {
                      _passengerData[index] ??= {};
                      _passengerData[index]!['title'] = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _textField(
                    'Given name',
                    passenger['givenName'] ?? '',
                    (value) {
                      _passengerData[index] ??= {};
                      _passengerData[index]!['givenName'] = value;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _textField(
                    'Surname',
                    passenger['surName'] ?? '',
                    (value) {
                      _passengerData[index] ??= {};
                      _passengerData[index]!['surName'] = value;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    'Passport #',
                    passenger['passportNo'] ?? '',
                    (value) {
                      _passengerData[index] ??= {};
                      _passengerData[index]!['passportNo'] = value;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dateField(
                    'Date of birth',
                    passenger['dob'] as DateTime?,
                    () => _showDatePicker(
                      context: context,
                      passengerIndex: index,
                      field: 'dob',
                      fieldType: 'dob',
                      passengerType: type,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _dateField(
                    'Date of issue',
                    passenger['doi'] as DateTime?,
                    () => _showDatePicker(
                      context: context,
                      passengerIndex: index,
                      field: 'doi',
                      fieldType: 'doi',
                      passengerType: type,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dateField(
                    'Passport expiry',
                    passenger['passportExpiry'] as DateTime?,
                    () => _showDatePicker(
                      context: context,
                      passengerIndex: index,
                      field: 'passportExpiry',
                      fieldType: 'passportExpiry',
                      passengerType: type,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownField(List<String> items, String value, Function(String) onChanged) {
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.fieldBorderColor.withOpacity(0.6)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(
            value: e,
            child: Text(e, style: const TextStyle(fontSize: 12)),
          )).toList(),
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ),
    );
  }

  Widget _textField(String hint, String value, Function(String) onChanged) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppConstants.fieldBorderColor.withOpacity(0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppConstants.fieldBorderColor.withOpacity(0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: TColors.primary),
        ),
        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      style: const TextStyle(fontSize: 12),
      controller: TextEditingController(text: value),
    );
  }
  
  Widget _dateField(String hint, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppConstants.fieldBorderColor.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date != null ? _formatDate(date) : hint,
                style: TextStyle(
                  fontSize: 12,
                  color: date != null ? Colors.black : Colors.grey,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today,
              size: 16,
              color: TColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitBooking() async {
    // Validate all passenger data
    final totalPassengers = _adults + _children + _infants;
    for (int i = 0; i < totalPassengers; i++) {
      final passenger = _passengerData[i];
      if (passenger == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all passenger details')),
        );
        return;
      }
      
      if ((passenger['givenName'] as String? ?? '').isEmpty ||
          (passenger['surName'] as String? ?? '').isEmpty ||
          (passenger['passportNo'] as String? ?? '').isEmpty ||
          passenger['dob'] == null ||
          passenger['doi'] == null ||
          passenger['passportExpiry'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill all details for ${_getPassengerType(i)} ${i + 1}')),
        );
        return;
      }
    }

    setState(() {
      _submitting = true;
    });

    try {
      final group = _groupDetail ?? widget.group;
      final groupId = group['id']?.toString() ?? '';
      final pnr = group['pnr']?.toString() ?? '';
      
      // Prepare passenger data arrays
      final List<String> paxTitle = [];
      final List<String> humanType = [];
      final List<String> surName = [];
      final List<String> givenName = [];
      final List<String> passNo = [];
      final List<String> dob = [];
      final List<String> doi = [];
      final List<String> doe = [];
      final List<String> adultPrice = [];
      final List<String> childPrice = [];
      final List<String> infantPrice = [];

      for (int i = 0; i < totalPassengers; i++) {
        final passenger = _passengerData[i]!;
        final type = _getPassengerType(i);
        
        paxTitle.add(passenger['title'] as String);
        humanType.add(type.toLowerCase());
        surName.add(passenger['surName'] as String);
        givenName.add(passenger['givenName'] as String);
        passNo.add(passenger['passportNo'] as String);
        dob.add(DateFormat('yyyy-MM-dd').format(passenger['dob'] as DateTime));
        doi.add(DateFormat('yyyy-MM-dd').format(passenger['doi'] as DateTime));
        doe.add(DateFormat('yyyy-MM-dd').format(passenger['passportExpiry'] as DateTime));
        
        if (type == 'Adult') {
          adultPrice.add(_pricePerSeat.toStringAsFixed(0));
          childPrice.add('0');
          infantPrice.add('0');
        } else if (type == 'Child') {
          adultPrice.add('0');
          childPrice.add(_childPrice.toStringAsFixed(0));
          infantPrice.add('0');
        } else {
          adultPrice.add('0');
          childPrice.add('0');
          infantPrice.add(_infantPrice.toStringAsFixed(0));
        }
      }

      // Generate ROE (Reference of booking) - using timestamp
      final roe = 'GRP${DateTime.now().millisecondsSinceEpoch}';

      final result = await _api.createBooking(
        groupId: groupId,
        roe: roe,
        noOfSeat: _totalSeatsUsed,
        pnr1: pnr,
        paxTitle: paxTitle,
        humanType: humanType,
        surName: surName,
        givenName: givenName,
        passNo: passNo,
        dob: dob,
        doi: doi,
        doe: doe,
        adultPrice: adultPrice,
        childPrice: childPrice,
        infantPrice: infantPrice,
      );

      setState(() {
        _submitting = false;
      });

      if (result['success'] == true) {
        // Navigate to thank you page
        Get.offAll(() => GroupBookingThankYouScreen(
          bookingData: {
            'transaction_id': result['transaction_id'],
            'group': group,
            'groupType': widget.groupType,
            'passengers': _passengerData,
            'adults': _adults,
            'children': _children,
            'infants': _infants,
            'totalPrice': _totalPrice,
            'flights': _flights,
          },
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Booking failed. Please try again.')),
        );
      }
    } catch (e) {
      setState(() {
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
}


