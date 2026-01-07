# LoggerService - Production-Ready Logging System

## Overview

The `LoggerService` is a production-ready logging system for the ReadyFlights Flutter Android app. It saves API requests, responses, and errors to organized files in Android external storage.

## Features

- ✅ **Debug Mode Only**: Logs are only created in debug builds (`kDebugMode`)
- ✅ **Organized Structure**: Logs are organized by category (flights/hotels/errors) and date
- ✅ **Sensitive Data Masking**: Automatically masks tokens, passwords, and other sensitive information
- ✅ **Automatic Directory Creation**: Creates folder structure automatically if it doesn't exist
- ✅ **Separate Files**: Each request and response is saved in a separate file
- ✅ **Null Safety**: Fully null-safe implementation
- ✅ **No Print Statements**: Doesn't use `print` or `debugPrint` as per requirements

## Directory Structure

```
/storage/emulated/0/ReadyFlights/
 └── logs/
     ├── flights/
     │   └── YYYY-MM-DD/
     │       ├── request_<timestamp>.txt
     │       └── response_<timestamp>.txt
     ├── hotels/
     │   └── YYYY-MM-DD/
     │       ├── request_<timestamp>.txt
     │       └── response_<timestamp>.txt
     └── errors/
         └── YYYY-MM-DD/
             └── error_<timestamp>.txt
```

## Android Permissions

**Note**: On Android 10+ (API 29+), accessing `/storage/emulated/0/` directly requires special permissions. The service will attempt to access this path and fall back gracefully to app-specific storage if access is denied.

If you need to access `/storage/emulated/0/` on Android 10+, add this permission to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
    tools:ignore="ScopedStorage" />
```

Then request the permission at runtime using a package like `permission_handler`.

## Usage Examples

### Basic Usage

```dart
final logger = LoggerService();

// Log a flights API request
await logger.logFlightsRequest(
  endpoint: 'https://api.flydubai.com/res/v3/pricing/flightswithfares',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer token123', // Will be automatically masked
  },
  body: {
    'origin': 'DXB',
    'destination': 'KHI',
    'date': '2024-01-15',
  },
);

// Log a flights API response
await logger.logFlightsResponse(
  endpoint: 'https://api.flydubai.com/res/v3/pricing/flightswithfares',
  statusCode: 200,
  body: responseData,
);

// Log an error
await logger.logError(
  error: exception,
  stackTrace: stackTrace,
  context: {
    'method': 'searchFlights',
    'userId': '12345',
  },
);
```

### Integration with API Service

The service has been integrated into `ApiServiceFlyDubai.searchFlights()` method. Here's how it works:

1. **Request Logging**: Before making the API call, the request is logged with:
   - Endpoint URL
   - Request headers (sensitive data masked)
   - Request body (formatted JSON)

2. **Response Logging**: After receiving the response, it's logged with:
   - Endpoint URL
   - HTTP status code
   - Response body (formatted JSON)

3. **Error Logging**: If an exception occurs, it's logged with:
   - Error message
   - Stack trace
   - Additional context (method name, parameters, etc.)

### Example Log File Content

**Request file** (`request_1705123456789.txt`):
```
================================================================================
FLIGHTS API REQUEST
================================================================================
Timestamp: 2024-01-15 10:30:45.789
API Name: Flights
Endpoint: https://api.flydubai.com/res/v3/pricing/flightswithfares

Request Headers:
--------------------------------------------------------------------------------
Content-Type: application/json
Authorization: Bearer ********token (masked)
Cookie: visid_incap_3059742=...

Request Body:
--------------------------------------------------------------------------------
{
  "RetrieveFareQuoteDateRange": {
    "RetrieveFareQuoteDateRangeRequest": {
      "Origin": "DXB",
      "Destination": "KHI",
      ...
    }
  }
}

================================================================================
```

**Response file** (`response_1705123457900.txt`):
```
================================================================================
FLIGHTS API RESPONSE
================================================================================
Timestamp: 2024-01-15 10:30:45.900
API Name: Flights
Endpoint: https://api.flydubai.com/res/v3/pricing/flightswithfares
Status Code: 200

Response Body:
--------------------------------------------------------------------------------
{
  "RetrieveFareQuoteDateRangeResponse": {
    "RetrieveFareQuoteDateRangeResult": {
      "FlightSegments": [...],
      ...
    }
  }
}

================================================================================
```

## Sensitive Data Masking

The service automatically masks the following fields:
- `authorization`, `authorization:`
- `bearer`, `token`, `access_token`, `accessToken`
- `password`, `pwd`
- `secret`, `client_secret`, `clientSecret`
- `api_key`, `apiKey`, `apikey`

Masking format:
- Short values (≤10 chars): `***`
- Medium values (≤20 chars): `first4***last4`
- Long values (>20 chars): `first8***last8`

## Implementation Details

- **Singleton Pattern**: Uses singleton pattern for easy access
- **Async Operations**: All file operations are asynchronous
- **Error Handling**: Silently fails if logging cannot be completed (won't break app flow)
- **Platform Support**: Currently optimized for Android; falls back to app documents directory on other platforms

## Integration into Other API Services

To integrate logging into other API services:

1. Import the logger service:
   ```dart
   import 'services/logger_service.dart';
   ```

2. Log request before API call:
   ```dart
   final logger = LoggerService();
   await logger.logFlightsRequest(
     endpoint: endpoint,
     headers: headers,
     body: requestBody,
   );
   ```

3. Log response after API call:
   ```dart
   await logger.logFlightsResponse(
     endpoint: endpoint,
     statusCode: response.statusCode,
     body: responseData,
   );
   ```

4. Log errors in catch block:
   ```dart
   catch (e, stackTrace) {
     await logger.logError(
       error: e,
       stackTrace: stackTrace,
       context: {'method': 'methodName'},
     );
   }
   ```

## Notes

- Logs are **only created in debug mode** - no performance impact in release builds
- Existing log files are **never deleted** - they accumulate over time
- Each log file has a unique timestamp to prevent overwrites
- The service handles all errors gracefully and won't crash the app

















