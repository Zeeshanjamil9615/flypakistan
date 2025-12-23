import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../services/api_service_group_tickets.dart';

class GroupTicketsController extends GetxController {
  final ApiServiceGroupTickets _apiService = ApiServiceGroupTickets();
  
  final RxBool isLoading = false.obs;
  final RxList<Map<String, dynamic>> groups = <Map<String, dynamic>>[].obs;
  final RxString errorMessage = ''.obs;
  
  /// Fetch all groups from API
  /// groupType should be "UMRAH GROUP" or "ONE WAY GROUP"
  Future<void> fetchAllGroups({required String groupType}) async {
    isLoading.value = true;
    errorMessage.value = '';
    
    try {
      final result = await _apiService.getAllGroups(groupType: groupType);
      
      if (result['success'] == true) {
        final data = result['data'];
        
        // Handle response - it might be a Map or String (JSON string)
        Map<String, dynamic> responseData;
        if (data is String) {
          // Parse JSON string
          responseData = jsonDecode(data);
        } else if (data is Map) {
          responseData = data as Map<String, dynamic>;
        } else {
          groups.value = [];
          if (kDebugMode) {
            print('❌ Invalid response format: ${data.runtimeType}');
          }
          return;
        }
        
        // Check for error status in response
        if (responseData.containsKey('status') && responseData['status'] == 'error') {
          errorMessage.value = responseData['message'] ?? 'No groups found';
          groups.value = [];
          if (kDebugMode) {
            print('⚠️ API returned error: ${responseData['message']}');
          }
          return;
        }
        
        // Extract groups list based on actual API response structure
        // Response: {"groups": [{id, airline_id, dept_date, arv_date, price, airline, details, ...}]}
        if (responseData.containsKey('groups')) {
          final groupsList = responseData['groups'];
          if (groupsList is List && groupsList.isNotEmpty) {
            groups.value = List<Map<String, dynamic>>.from(groupsList);
          } else {
            groups.value = [];
            errorMessage.value = 'No groups available';
          }
        } else if (responseData.containsKey('data')) {
          final dataList = responseData['data'];
          if (dataList is List && dataList.isNotEmpty) {
            groups.value = List<Map<String, dynamic>>.from(dataList);
          } else {
            groups.value = [];
            errorMessage.value = 'No groups available';
          }
        } else if (data is List) {
          groups.value = List<Map<String, dynamic>>.from(data);
        } else {
          groups.value = [];
          errorMessage.value = 'No groups available';
        }
        
        if (kDebugMode) {
          print('✅ Groups loaded: ${groups.length}');
          if (groups.isNotEmpty) {
            print('📋 First group sample: ${groups.first}');
          }
        }
      } else {
        errorMessage.value = result['message'] ?? 'Failed to load groups';
        groups.value = [];
      }
    } catch (e) {
      errorMessage.value = 'An error occurred: ${e.toString()}';
      groups.value = [];
      if (kDebugMode) {
        print('❌ Error fetching groups: $e');
      }
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Clear groups list
  void clearGroups() {
    groups.value = [];
    errorMessage.value = '';
  }
}

