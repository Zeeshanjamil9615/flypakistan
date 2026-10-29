import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../services/api_service_cars.dart';
import '../../utility/colors.dart';
import '../tours/widgets/tours_message_view.dart';
import 'car_model.dart';
import 'cars_controller.dart';
import 'widgets/car_card.dart';
import 'widgets/other_car_card.dart';

/// Opens the details page of [car]. Opening another car from the "Other cars"
/// tab stacks a new page, so back returns to the previous car.
void openCarDetails(CarModel car) {
  Get.to(() => CarDetailsScreen(car: car), preventDuplicates: false);
}

/// Car details page like the website's: a tab with the selected car (photo,
/// rates, vehicle details, Call now / WhatsApp Now) and an "Other cars" tab
/// with the other cars in the same city.
///
/// Data comes from the car-details API. The car from the list is shown
/// straight away while its details load.
class CarDetailsScreen extends StatefulWidget {
  final CarModel car;

  const CarDetailsScreen({super.key, required this.car});

  @override
  State<CarDetailsScreen> createState() => _CarDetailsScreenState();
}

class _CarDetailsScreenState extends State<CarDetailsScreen>
    with SingleTickerProviderStateMixin {
  final ApiServiceCars _api = ApiServiceCars();
  final CarsController controller = CarsController.instance;
  late final TabController _tabController;

  late CarModel _car = widget.car;
  List<CarModel> _otherCars = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    // Already true on the first load; set again for "Try Again".
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }
    try {
      final CarDetailsResponse response = await _api.fetchCarDetails(
        widget.car.id,
      );
      if (!mounted) return;
      setState(() {
        _car = response.car;
        _otherCars = response.otherCars;
      });
    } on CarsApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: TColors.primary,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _car.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            if (_car.city.isNotEmpty)
              Text(
                'Rent a Car in ${_car.city}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildDetailsTab(), _buildOtherCarsTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: TColors.background2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: TColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: TColors.text,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          splashBorderRadius: BorderRadius.circular(8),
          tabs: [
            Tab(
              height: 36,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_car, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _car.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              height: 36,
              child: Text(
                _otherCars.isEmpty
                    ? 'Other cars'
                    : 'Other cars (${_otherCars.length})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Car tab ─────────────────────────────────────────────────────────────

  Widget _buildDetailsTab() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildOverview(),
              const SizedBox(height: 16),
              CarRates(car: _car),
              const SizedBox(height: 16),
              _buildVehicleDetails(),
              const SizedBox(height: 16),
              _buildContactNote(),
            ],
          ),
        ),
        _buildActionBar(),
      ],
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );

  /// Photo, "Faisalabad | Yaris Rent a Car" and the short description.
  Widget _buildOverview() {
    return Container(
      decoration: _cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CarImage(url: _car.image, height: 220),
              if (_car.year.isNotEmpty)
                Positioned(
                  left: 12,
                  top: 12,
                  child: CarYearBadge(year: _car.year),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      if (_car.city.isNotEmpty)
                        TextSpan(
                          text: '${_car.city} | ',
                          style: const TextStyle(color: TColors.grey),
                        ),
                      TextSpan(
                        text: '${_car.name} Rent a Car',
                        style: const TextStyle(color: TColors.primary),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                if (_car.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _car.description,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Color, capacity, transmission, year and city, as in the website's table.
  Widget _buildVehicleDetails() {
    final List<Widget> rows = [
      if (_car.color.isNotEmpty)
        _buildSpecRow(Icons.palette_outlined, 'Vehicle Color', _car.color),
      if (_car.capacity > 0)
        _buildSpecRow(
          Icons.event_seat_outlined,
          'Vehicle Capacity',
          _car.capacityLabel,
        ),
      if (_car.transmission.isNotEmpty)
        _buildSpecRow(
          Icons.settings_outlined,
          'Vehicle Transmission',
          '${_car.transmission} Transmission',
        ),
      if (_car.year.isNotEmpty)
        _buildSpecRow(
          Icons.calendar_today_outlined,
          'Vehicle Year',
          _car.year,
        ),
      if (_car.city.isNotEmpty)
        _buildSpecRow(Icons.location_on_outlined, 'City', _car.city),
    ];

    final Widget content;
    if (_isLoading && !_car.hasSpecs) {
      content = _buildSpecsLoading();
    } else if (_errorMessage.isNotEmpty && !_car.hasSpecs) {
      content = ToursMessageView(
        icon: Icons.cloud_off,
        message: _errorMessage,
        actionLabel: 'Try Again',
        onAction: _loadDetails,
      );
    } else {
      content = Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
            rows[i],
          ],
        ],
      );
    }

    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: TColors.text,
            ),
          ),
          const SizedBox(height: 4),
          content,
        ],
      ),
    );
  }

  Widget _buildSpecRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 18, color: TColors.iconclr),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: TColors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: TColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsLoading() {
    Widget box(double height, double width) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: TColors.background3,
            borderRadius: BorderRadius.circular(4),
          ),
        );

    return Column(
      children: List.generate(
        4,
        (_) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              box(18, 18),
              const SizedBox(width: 10),
              box(12, 120),
              const Spacer(),
              box(12, 70),
            ],
          ),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(begin: 0.5, end: 1, duration: const Duration(milliseconds: 700));
  }

  Widget _buildContactNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TColors.background2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TColors.primary.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent, size: 20, color: TColors.iconclr),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Call or WhatsApp us: '),
                      TextSpan(
                        text: CarsController.displayPhone,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: TColors.primary,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 13, color: TColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 16,
                color: TColors.iconclr,
              ),
              const SizedBox(width: 8),
              Text(
                'Book with confidence: No hidden charges',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Red "Call now" and green "WhatsApp Now", as on the website.
  Widget _buildActionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: controller.callNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TColors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.call, size: 20),
                label: const Text(
                  'Call now',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CarWhatsAppButton(
              car: _car,
              height: 48,
              label: 'WhatsApp Now',
            ),
          ),
        ],
      ),
    );
  }

  // ─── Other cars tab ──────────────────────────────────────────────────────

  Widget _buildOtherCarsTab() {
    if (_otherCars.isEmpty) {
      if (_isLoading) {
        return const Center(
          child: CircularProgressIndicator(color: TColors.primary),
        );
      }
      final bool failed = _errorMessage.isNotEmpty;
      return Center(
        child: ToursMessageView(
          icon: failed ? Icons.cloud_off : Icons.directions_car_outlined,
          message: failed
              ? _errorMessage
              : 'No other cars${_car.city.isEmpty ? '' : ' in ${_car.city}'} right now.',
          actionLabel: failed ? 'Try Again' : null,
          onAction: failed ? _loadDetails : null,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      // +1 for the header.
      itemCount: _otherCars.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        if (index == 0) return _buildOtherCarsHeader();
        return OtherCarCard(car: _otherCars[index - 1]);
      },
    );
  }

  Widget _buildOtherCarsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _car.city.isEmpty ? 'More cars' : 'More cars in ${_car.city}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: TColors.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${_otherCars.length} ${_otherCars.length == 1 ? 'car' : 'cars'} '
          'available  •  Tap a car to see its details',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
