import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../utility/colors.dart';
import '../../../utility/app_constants.dart';
import '../../../views/home/home_screen.dart';

class GroupBookingThankYouScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;

  const GroupBookingThankYouScreen({
    super.key,
    required this.bookingData,
  });

  @override
  Widget build(BuildContext context) {
    final group = bookingData['group'] as Map<String, dynamic>;
    final passengers = bookingData['passengers'] as Map<int, Map<String, dynamic>>;
    final flights = bookingData['flights'] as List<Map<String, dynamic>>;
    final transactionId = bookingData['transaction_id'];
    final totalPrice = bookingData['totalPrice'] as double;
    final adults = bookingData['adults'] as int;
    final children = bookingData['children'] as int;
    final infants = bookingData['infants'] as int;
    
    final airline = (group['airline'] is List && (group['airline'] as List).isNotEmpty)
        ? group['airline'][0]
        : null;
    final logoFile = airline != null ? (airline['logo_url'] ?? '') : '';
    final logoUrl = logoFile.isNotEmpty
        ? 'https://alsaboorportal.com/assets/img/airline-logo/$logoFile'
        : '';
    final airlineName = airline != null ? (airline['airline_name'] ?? '') : '';
    final pnr = group['pnr']?.toString() ?? '';
    final deptDate = group['dept_date']?.toString() ?? '';
    final arvDate = group['arv_date']?.toString() ?? '';

    return Scaffold(
      backgroundColor: TColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: TColors.primary,
        automaticallyImplyLeading: false,
        title: const Text(
          "Booking Confirmed",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: () => _generatePDF(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSuccessHeader(),
            const SizedBox(height: 20),
            _buildBookingStatusCard(pnr, deptDate, transactionId),
            const SizedBox(height: 16),
            _buildPassengerDetailsCard(passengers, adults, children, infants),
            const SizedBox(height: 16),
            _buildFlightDetailsCard(flights, group, logoUrl, airlineName),
            const SizedBox(height: 16),
            _buildEmergencyContactCard(),
            const SizedBox(height: 20),
            _buildActionButtons(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'BOOKING SUCCESSFULLY MADE',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: TColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'This is to inform you that your ticket reservation has been successfully placed on hold',
            style: TextStyle(
              fontSize: 14,
              color: TColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'We request you to make the payment by ${DateFormat('EEE dd MMM yyyy HH:mm').format(DateTime.now().add(const Duration(hours: 24)))}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: TColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Below are our account details:',
            style: TextStyle(
              fontSize: 14,
              color: TColors.text,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingStatusCard(String pnr, String deptDate, dynamic transactionId) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Your booking is ON-REQUEST',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Departure Date:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      deptDate.isNotEmpty
                          ? DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(deptDate))
                          : 'N/A',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PNR:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      pnr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: TColors.primary,
                      ),
                    ),
                  ],
                ),
                if (transactionId != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Transaction ID:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        transactionId.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerDetailsCard(
    Map<int, Map<String, dynamic>> passengers,
    int adults,
    int children,
    int infants,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.person, color: TColors.primary),
                SizedBox(width: 8),
                Text(
                  'Passenger details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(0.5),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1.5),
              },
              children: [
                const TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Sr#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Pax Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Passport#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                ...passengers.entries.map((entry) {
                  final index = entry.key;
                  final passenger = entry.value;
                  final title = passenger['title'] as String? ?? '';
                  final givenName = passenger['givenName'] as String? ?? '';
                  final surName = passenger['surName'] as String? ?? '';
                  final passportNo = passenger['passportNo'] as String? ?? '';
                  final fullName = '$title $givenName $surName'.trim().toUpperCase();
                  
                  return TableRow(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey, width: 0.3)),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(fullName, style: const TextStyle(fontSize: 12)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(passportNo, style: const TextStyle(fontSize: 12)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('On Request', style: TextStyle(fontSize: 12, color: Colors.orange)),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightDetailsCard(
    List<Map<String, dynamic>> flights,
    Map<String, dynamic> group,
    String logoUrl,
    String airlineName,
  ) {
    if (flights.isEmpty) return const SizedBox.shrink();

    final outboundFlight = flights.firstWhere(
      (f) => (f['sr'] ?? 0) == 1,
      orElse: () => flights.first,
    );
    final returnFlight = flights.length > 1
        ? flights.firstWhere(
            (f) => (f['sr'] ?? 0) == 2,
            orElse: () => flights.last,
          )
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.flight_takeoff, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Departure from ${outboundFlight['origin'] ?? 'Origin'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFlightRow(outboundFlight, group, logoUrl, airlineName),
          ),
          if (returnFlight != null) ...[
            const Divider(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flight_land, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Departure from ${returnFlight['origin'] ?? 'Origin'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildFlightRow(returnFlight, group, logoUrl, airlineName),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlightRow(
    Map<String, dynamic> flight,
    Map<String, dynamic> group,
    String logoUrl,
    String airlineName,
  ) {
    final date = flight['flight_date']?.toString() ?? '';
    final formattedDate = date.isNotEmpty
        ? DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(date))
        : '';
    final deptTime = flight['dept_time']?.toString() ?? '';
    final arvTime = flight['arv_time']?.toString() ?? '';
    final origin = flight['origin']?.toString() ?? '';
    final destination = flight['destination']?.toString() ?? '';
    final flightNo = flight['flight_no']?.toString() ?? '';
    final baggage = flight['baggage']?.toString() ?? '';
    final meal = group['meal']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (logoUrl.isNotEmpty)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: logoUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            if (logoUrl.isNotEmpty) const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (airlineName.isNotEmpty)
                    Text(
                      airlineName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  if (formattedDate.isNotEmpty)
                    Text(
                      formattedDate,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deptTime.isNotEmpty ? deptTime.substring(0, 5) : '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  origin,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                  ),
                  Icon(Icons.flight, size: 16, color: TColors.primary),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  arvTime.isNotEmpty ? arvTime.substring(0, 5) : '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  destination,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (baggage.isNotEmpty) ...[
              Icon(Icons.luggage, size: 14, color: Colors.blue[700]),
              const SizedBox(width: 4),
              Text('$baggage KG', style: TextStyle(fontSize: 11, color: Colors.blue[700])),
            ],
            const SizedBox(width: 12),
            Icon(Icons.event_seat, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            const Text('Unassigned', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(width: 12),
            Icon(Icons.restaurant, size: 14, color: Colors.orange[700]),
            const SizedBox(width: 4),
            Text(
              meal.isNotEmpty ? meal : 'Buy on board, if available',
              style: TextStyle(fontSize: 11, color: Colors.orange[700]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmergencyContactCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Emergency Contact',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: TColors.text,
            ),
          ),
          const SizedBox(height: 12),
          _buildContactRow('Agency', 'Journey Online 2'),
          const SizedBox(height: 8),
          _buildContactRow('Contact No', '+92 3067119099'),
          const SizedBox(height: 8),
          _buildContactRow('Address', 'Canal Road'),
        ],
      ),
    );
  }

  Widget _buildContactRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Get.offAll(() => const HomeScreen()),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: TColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Back Home',
                style: TextStyle(
                  color: TColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _generatePDF(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.print, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Print',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePDF(BuildContext context) async {
    try {
      final pdf = await _createPDF();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf,
        name: 'Group_Booking_${bookingData['transaction_id'] ?? DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF generation failed: $e')),
      );
    }
  }

  Future<Uint8List> _createPDF() async {
    final pdf = pw.Document();
    final group = bookingData['group'] as Map<String, dynamic>;
    final passengers = bookingData['passengers'] as Map<int, Map<String, dynamic>>;
    final flights = bookingData['flights'] as List<Map<String, dynamic>>;
    final transactionId = bookingData['transaction_id'];
    final totalPrice = bookingData['totalPrice'] as double;
    final pnr = group['pnr']?.toString() ?? '';
    final deptDate = group['dept_date']?.toString() ?? '';
    
    final airline = (group['airline'] is List && (group['airline'] as List).isNotEmpty)
        ? group['airline'][0]
        : null;
    final airlineName = airline != null ? (airline['airline_name'] ?? '') : '';
    final logoFile = airline != null ? (airline['logo_url'] ?? '') : '';
    final logoUrl = logoFile.isNotEmpty
        ? 'https://alsaboorportal.com/assets/img/airline-logo/$logoFile'
        : '';

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Ready Flights',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Group Booking Confirmation',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'PNR: $pnr',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (transactionId != null)
                      pw.Text(
                        'Transaction ID: $transactionId',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            
            // Booking Status
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.orange100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 8,
                    height: 8,
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.orange,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'Your booking is ON-REQUEST',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange900,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Passenger Details
            pw.Text(
              'Passenger details',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Sr#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Pax Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Passport#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                  ],
                ),
                ...passengers.entries.map((entry) {
                  final index = entry.key;
                  final passenger = entry.value;
                  final title = passenger['title'] as String? ?? '';
                  final givenName = passenger['givenName'] as String? ?? '';
                  final surName = passenger['surName'] as String? ?? '';
                  final passportNo = passenger['passportNo'] as String? ?? '';
                  final fullName = '$title $givenName $surName'.trim().toUpperCase();
                  
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${index + 1}', style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(fullName, style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(passportNo, style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('On Request', style: pw.TextStyle(fontSize: 10, color: PdfColors.orange)),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
            pw.SizedBox(height: 20),
            
            // Flight Details
            ...flights.map((flight) {
              final date = flight['flight_date']?.toString() ?? '';
              final formattedDate = date.isNotEmpty
                  ? DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(date))
                  : '';
              final deptTime = flight['dept_time']?.toString() ?? '';
              final arvTime = flight['arv_time']?.toString() ?? '';
              final origin = flight['origin']?.toString() ?? '';
              final destination = flight['destination']?.toString() ?? '';
              final flightNo = flight['flight_no']?.toString() ?? '';
              final baggage = flight['baggage']?.toString() ?? '';
              final meal = group['meal']?.toString() ?? '';
              
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Departure from $origin',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            deptTime.isNotEmpty ? deptTime.substring(0, 5) : '',
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(origin, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Text('→', style: pw.TextStyle(fontSize: 16)),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            arvTime.isNotEmpty ? arvTime.substring(0, 5) : '',
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(destination, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      if (baggage.isNotEmpty)
                        pw.Text('$baggage KG', style: pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(width: 12),
                      pw.Text('Unassigned', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(width: 12),
                      pw.Text(
                        meal.isNotEmpty ? meal : 'Buy on board, if available',
                        style: pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                ],
              );
            }).toList(),
            
            // Emergency Contact
            pw.SizedBox(height: 20),
            pw.Text(
              'Emergency Contact',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Agency: Journey Online 2', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Contact No: +92 3067119099', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Address: Canal Road', style: const pw.TextStyle(fontSize: 10)),
            
            // Footer
            pw.SizedBox(height: 30),
            pw.Center(
              child: pw.Text(
                'Thank you for booking with Ready Flights!',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}

