# FlyDubai Multi-City Implementation Guide for Web Developers

## Overview
This guide explains how to implement **Multi-City booking** for FlyDubai, highlighting the key differences from One-Way and Round-Trip implementations.

---

## 🔑 Key Differences: Multi-City vs One-Way/Return

### 1. **Data Structure**

#### One-Way / Round-Trip:
```javascript
// Single flight selection
selectedOutboundFlight: Flight | null
selectedReturnFlight: Flight | null  // Only for round-trip
selectedOutboundFareOption: Fare | null
selectedReturnFareOption: Fare | null
```

#### Multi-City:
```javascript
// Array of flights and fares (one per segment)
selectedMultiCityFlights: Flight[] = []
selectedMultiCityFareOptions: Fare[] = []
currentMultiCitySegment: number = 0  // Track which segment user is selecting
```

**Key Point:** Multi-city uses **arrays** instead of single values. Each array index represents one segment.

---

### 2. **Search API Request**

#### One-Way:
```javascript
{
  type: 0,
  origin: "LYP",
  destination: "JED",
  depDate: "2026-01-10",
  adult: 1,
  child: 0,
  infant: 0,
  cabin: "ECONOMY"
}
```

#### Round-Trip:
```javascript
{
  type: 1,
  origin: "LYP",
  destination: "JED",
  depDate: "2026-01-10,2026-01-15",  // Comma-separated dates
  adult: 1,
  child: 0,
  infant: 0,
  cabin: "ECONOMY"
}
```

#### Multi-City:
```javascript
{
  type: 2,
  origin: "LYP",  // First segment origin (can be ignored)
  destination: "JED",  // Last segment destination (can be ignored)
  depDate: "2026-01-10,2026-01-15",  // Comma-separated dates
  adult: 1,
  child: 0,
  infant: 0,
  cabin: "ECONOMY",
  multiCitySegments: [  // ⭐ KEY DIFFERENCE
    {
      from: "LYP",
      to: "JED",
      date: "2026-01-10"
    },
    {
      from: "MED",
      to: "LHE",
      date: "2026-01-15"
    }
  ]
}
```

**Key Point:** Multi-city requires a `multiCitySegments` array with all route pairs and dates.

---

### 3. **API Request Body Structure**

#### One-Way Request Body:
```json
{
  "FareQuoteDetails": [
    {
      "Origin": "LYP",
      "Destination": "JED",
      "DepartureDate": "2026-01-10",
      ...
    }
  ],
  "Passengers": [...],
  "Cabin": "ECONOMY"
}
```

#### Multi-City Request Body:
```json
{
  "FareQuoteDetails": [
    {
      "Origin": "LYP",
      "Destination": "JED",
      "DepartureDate": "2026-01-10",
      ...
    },
    {
      "Origin": "MED",
      "Destination": "LHE",
      "DepartureDate": "2026-01-15",
      ...
    }
  ],
  "Passengers": [...],
  "Cabin": "ECONOMY"
}
```

**Key Point:** Multi-city has **multiple objects** in `FareQuoteDetails` array.

---

### 4. **Flight Selection Flow**

#### One-Way / Round-Trip:
```
1. User searches → API returns flights
2. User selects ONE outbound flight
3. User selects fare option
4. (If round-trip) User selects ONE return flight
5. User selects return fare option
6. Proceed to extras/booking
```

#### Multi-City:
```
1. User searches with multiple segments → API returns flights for ALL segments
2. User selects flight for Segment 0
3. User selects fare option for Segment 0
4. System moves to Segment 1
5. User selects flight for Segment 1
6. User selects fare option for Segment 1
7. Repeat for all segments...
8. Proceed to extras/booking
```

**Key Point:** Multi-city requires **sequential selection** - user must complete each segment before moving to the next.

---

### 5. **Storing Selected Flights**

#### One-Way / Round-Trip:
```javascript
// Simple assignment
selectedOutboundFlight = flight;
selectedOutboundFareOption = fareOption;
```

#### Multi-City:
```javascript
// Array-based assignment with index
const segmentIndex = currentMultiCitySegment; // e.g., 0, 1, 2...

selectedMultiCityFlights[segmentIndex] = flight;
selectedMultiCityFareOptions[segmentIndex] = fareOption;

// Move to next segment
currentMultiCitySegment = segmentIndex + 1;
```

**Key Point:** Use **array indexing** to store selections per segment.

---

### 6. **Add to Cart / Booking IDs**

#### One-Way:
```javascript
const bookingIds = [
  `${outboundFlight.lfid}_${fareIndex}`
];
```

#### Round-Trip:
```javascript
const bookingIds = [
  `${outboundFlight.lfid}_${outboundFareIndex}`,
  `${returnFlight.lfid}_${returnFareIndex}`
];
```

#### Multi-City:
```javascript
const bookingIds = [];
for (let i = 0; i < selectedMultiCityFlights.length; i++) {
  const flight = selectedMultiCityFlights[i];
  const fareOption = selectedMultiCityFareOptions[i];
  const fareIndex = getFareIndex(flight, fareOption);
  bookingIds.push(`${flight.lfid}_${fareIndex}`);
}
```

**Key Point:** Loop through all segments to build booking IDs array.

---

### 7. **PNR Creation - Segment Array**

#### One-Way:
```javascript
const segments = [
  {
    pax: 1,
    fareID: outboundFareOption.fareId,
    extra: {
      baggage: baggageExtras,
      meal: mealExtras,
      seat: seatExtras
    }
  }
];
```

#### Round-Trip:
```javascript
const segments = [
  {
    pax: 1,
    fareID: outboundFareOption.fareId,
    extra: { ... }
  },
  {
    pax: 1,
    fareID: returnFareOption.fareId,
    extra: { ... }
  }
];
```

#### Multi-City:
```javascript
const segments = [];
for (let i = 0; i < selectedMultiCityFlights.length; i++) {
  const flight = selectedMultiCityFlights[i];
  const fareOption = selectedMultiCityFareOptions[i];
  
  // ⭐ CRITICAL: Filter extras by segment LFID
  const segmentLfid = flight.flightSegment.lfid.toString();
  const filteredBaggage = filterExtrasBySegment(
    selectedBaggage, 
    segmentLfid
  );
  const filteredMeals = filterExtrasByLegForSegment(
    selectedMeals, 
    segmentLfid, 
    flight
  );
  const filteredSeats = filterExtrasByLegForSegment(
    selectedSeats, 
    segmentLfid, 
    flight
  );
  
  segments.push({
    pax: 1,
    fareID: fareOption.fareId,
    extra: {
      baggage: buildBaggageExtras(filteredBaggage, segmentMeta),
      meal: buildMealExtras(filteredMeals, segmentMeta, flight),
      seat: buildSeatExtras(filteredSeats, segmentMeta, flight)
    }
  });
}
```

**Key Point:** 
- Build **one segment per flight** in the array
- **Filter extras by segment LFID** - each segment has its own extras
- Use **sequential FareInformationID** (1, 2, 3...) in PNR request

---

### 8. **Extras (Baggage, Meals, Seats) Handling**

#### One-Way / Round-Trip:
```javascript
// Extras are stored with simple keys
selectedBaggage = {
  "seg17540479|p0": baggageData  // segment LFID
}
selectedMeals = {
  "legseg17540479_leg184332|p0": mealData  // leg code
}
```

#### Multi-City:
```javascript
// Extras MUST include segment identifier in key
selectedBaggage = {
  "seg17540479|p0": baggageData,  // Segment 0
  "seg17105832|p0": baggageData   // Segment 1
}
selectedMeals = {
  "legseg17540479_leg184332|p0": mealData,  // Segment 0, Leg 1
  "legseg17540479_leg189973|p0": mealData,  // Segment 0, Leg 2 (if multi-leg)
  "legseg17105832_leg184539|p0": mealData   // Segment 1, Leg 1
}
```

**Key Point:** 
- **Baggage keys:** `seg{segmentLfid}|p{passengerId}`
- **Meal/Seat keys:** `legseg{segmentLfid}_leg{pfid}|p{passengerId}`
- **Filter extras by segment** when building PNR segments

---

### 9. **Special Rules for Multi-City**

#### A. **Meals on Multi-Leg Segments**
```javascript
// ⚠️ IMPORTANT: API only allows meals on FIRST leg of a segment
// If segment has multiple legs (e.g., LYP → DXB → JED):
// - Meals can ONLY be on first leg (PFID 184332)
// - Meals on connecting legs (PFID 189973) will be REJECTED

if (legCount > 1 && pfid !== firstLegPfid) {
  // Skip this meal - it's on a connecting leg
  continue;
}
```

#### B. **Baggage PFID for Multi-Leg Segments**
```javascript
// For segments with multiple legs, use PFID = 0
// For single-leg segments, use the segment's physicalFlightId
const baggagePfid = legCount > 1 ? 0 : segmentMeta.physicalFlightId;
```

#### C. **FareInformationID Sequencing**
```javascript
// PNR request requires sequential FareInformationID (1, 2, 3...)
// NOT the actual fareId from API response
let fareInformationId = 1;
for (const segment of segments) {
  segment.FareInformationID = fareInformationId++;
}
```

---

## 📋 Implementation Checklist

### Frontend (UI/UX)
- [ ] Multi-city search form with dynamic segment inputs
- [ ] Sequential flight selection UI (show current segment number)
- [ ] Progress indicator (Segment 1 of 3, Segment 2 of 3, etc.)
- [ ] Disable "Continue" until current segment is complete
- [ ] Display all selected segments in summary before booking
- [ ] Extras selection UI that shows segment/leg context

### Backend (API Integration)
- [ ] Build `multiCitySegments` array from user input
- [ ] Send `type: 2` in search request
- [ ] Parse multi-segment response correctly
- [ ] Store flights in arrays: `selectedMultiCityFlights[]`
- [ ] Store fares in arrays: `selectedMultiCityFareOptions[]`
- [ ] Build booking IDs array for all segments
- [ ] Filter extras by segment LFID when building PNR
- [ ] Apply meal restrictions (first leg only for multi-leg segments)
- [ ] Use sequential FareInformationID (1, 2, 3...)

### Data Validation
- [ ] Ensure all segments have flights selected
- [ ] Ensure all segments have fare options selected
- [ ] Validate extras keys match segment LFIDs
- [ ] Check meal PFID is first leg for multi-leg segments

---

## 🔄 Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│ 1. USER INPUT: Multi-City Search                        │
│    - Segment 1: LYP → JED, 2026-01-10                  │
│    - Segment 2: MED → LHE, 2026-01-15                   │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 2. BUILD API REQUEST                                     │
│    type: 2                                              │
│    multiCitySegments: [                                  │
│      {from: "LYP", to: "JED", date: "2026-01-10"},     │
│      {from: "MED", to: "LHE", date: "2026-01-15"}      │
│    ]                                                     │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 3. API RESPONSE: Flights for ALL segments               │
│    - Parse and group by segment                         │
│    - Display Segment 0 flights first                   │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 4. USER SELECTS: Segment 0                              │
│    - Flight selected → selectedMultiCityFlights[0]      │
│    - Fare selected → selectedMultiCityFareOptions[0]   │
│    - Move to Segment 1                                  │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 5. USER SELECTS: Segment 1                              │
│    - Flight selected → selectedMultiCityFlights[1]      │
│    - Fare selected → selectedMultiCityFareOptions[1]   │
│    - All segments complete                              │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 6. ADD TO CART                                          │
│    - Build bookingIds: [lfid1_fare1, lfid2_fare2]       │
│    - Call addToCart with all booking IDs                │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 7. EXTRAS SELECTION                                     │
│    - Show segments/legs in UI                           │
│    - Store with segment keys:                           │
│      "seg17540479|p0", "seg17105832|p0"                │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 8. BUILD PNR SEGMENTS                                  │
│    for each segment:                                    │
│      - Filter extras by segment LFID                    │
│      - Build baggage/meal/seat extras                    │
│      - Add to segments array                            │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 9. CREATE PNR                                           │
│    - Segments array with FareInformationID: 1, 2, 3...  │
│    - Each segment has its own extras                    │
│    - Submit to API                                      │
└─────────────────────────────────────────────────────────┘
```

---

## 💡 Code Examples

### Example 1: Building Multi-City Search Request
```javascript
function buildMultiCitySearchRequest(segments, passengers, cabin) {
  return {
    type: 2,  // Multi-city
    origin: segments[0].from,  // First segment origin
    destination: segments[segments.length - 1].to,  // Last segment destination
    depDate: segments.map(s => s.date).join(','),
    adult: passengers,
    child: 0,
    infant: 0,
    cabin: cabin,
    multiCitySegments: segments.map(s => ({
      from: s.from,
      to: s.to,
      date: s.date
    }))
  };
}
```

### Example 2: Storing Multi-City Selection
```javascript
function handleMultiCityFlightSelection(flight, segmentIndex) {
  // Store flight
  selectedMultiCityFlights[segmentIndex] = flight;
  
  // Store fare option
  selectedMultiCityFareOptions[segmentIndex] = selectedFare;
  
  // Move to next segment if not last
  if (segmentIndex < totalSegments - 1) {
    currentMultiCitySegment = segmentIndex + 1;
    showSegmentFlights(segmentIndex + 1);
  } else {
    // All segments selected, proceed to extras
    proceedToExtras();
  }
}
```

### Example 3: Filtering Extras by Segment
```javascript
function filterExtrasBySegment(allExtras, segmentLfid) {
  const filtered = {};
  const prefix = `seg${segmentLfid}|`;
  
  for (const [key, value] of Object.entries(allExtras)) {
    if (key.startsWith(prefix)) {
      filtered[key] = value;
    }
  }
  
  return filtered;
}
```

### Example 4: Building PNR Segments Array
```javascript
function buildSegmentArray(selectedFlights, selectedFares, extrasController) {
  const segments = [];
  
  for (let i = 0; i < selectedFlights.length; i++) {
    const flight = selectedFlights[i];
    const fareOption = selectedFares[i];
    const segmentLfid = flight.flightSegment.lfid.toString();
    
    // Filter extras for this segment
    const filteredBaggage = filterExtrasBySegment(
      extrasController.selectedBaggage,
      segmentLfid
    );
    const filteredMeals = filterExtrasByLegForSegment(
      extrasController.selectedMeals,
      segmentLfid,
      flight
    );
    
    // Build extras strings
    const baggageExtras = buildBaggageExtras(filteredBaggage, flight);
    const mealExtras = buildMealExtras(filteredMeals, flight);
    
    segments.push({
      pax: 1,
      fareID: fareOption.fareId,
      extra: {
        baggage: baggageExtras,
        meal: mealExtras,
        seat: []
      }
    });
  }
  
  return segments;
}
```

---

## ⚠️ Common Pitfalls to Avoid

1. **❌ Using single flight variables instead of arrays**
   ```javascript
   // WRONG
   selectedOutboundFlight = flight;
   
   // CORRECT
   selectedMultiCityFlights[segmentIndex] = flight;
   ```

2. **❌ Not filtering extras by segment**
   ```javascript
   // WRONG - uses all extras for all segments
   segments[0].extra.baggage = allBaggage;
   segments[1].extra.baggage = allBaggage;  // Same data!
   
   // CORRECT - filter by segment LFID
   segments[0].extra.baggage = filterBySegment(allBaggage, lfid0);
   segments[1].extra.baggage = filterBySegment(allBaggage, lfid1);
   ```

3. **❌ Using actual fareId instead of sequential FareInformationID**
   ```javascript
   // WRONG
   segment.FareInformationID = fareOption.fareId;  // Could be 1, 74, 123...
   
   // CORRECT
   segment.FareInformationID = index + 1;  // 1, 2, 3...
   ```

4. **❌ Allowing meals on connecting legs**
   ```javascript
   // WRONG - allows meals on any leg
   if (meal.pfid) addMeal(meal);
   
   // CORRECT - only first leg
   if (legCount > 1 && meal.pfid === firstLegPfid) {
     addMeal(meal);
   }
   ```

5. **❌ Not tracking current segment**
   ```javascript
   // WRONG - user doesn't know which segment they're selecting
   showFlights(allFlights);
   
   // CORRECT - show current segment
   const currentSegment = currentMultiCitySegment;
   showFlights(flightsBySegment[currentSegment]);
   ```

---

## 📞 Support & Questions

If web developers have questions, they should reference:
1. This guide
2. Mobile app implementation in `flydubai_controller.dart`
3. API service implementation in `api_service_flydubai.dart`
4. PNR creation logic in `buildSegmentArray` method

---

**Last Updated:** Based on working mobile implementation
**Status:** ✅ Tested and working

