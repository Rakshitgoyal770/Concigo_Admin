import '../apaleo_service.dart';
import '../pms_adapter.dart';

/// Concrete Apaleo PMS Adapter.
/// Translates Apaleo REST APIs into Concigo's [PmsAdapter] contract.
class ApaleoAdapter implements PmsAdapter {
  final ApaleoService _service;

  ApaleoAdapter({ApaleoService? service}) : _service = service ?? ApaleoService.instance;

  @override
  String get provider => 'apaleo';

  @override
  Future<List<CanonicalReservation>> fetchReservations({
    required String propertyCode,
    DateTime? from,
    DateTime? to,
    List<String>? statuses,
  }) async {
    // Fetch all live/upcoming reservation statuses. 'Reserved' is included so
    // new bookings sync immediately after creation in Apaleo.
    // 'CheckedOut' and 'NoShow' are intentionally excluded — processing historical
    // records every 30s causes unnecessary DB load, and the resurrection-prevention
    // logic handles Apaleo→Concigo status drift correctly.
    final rawList = await _service.fetchReservations(
      propertyId: propertyCode,
      from: from,
      to: to,
      statuses: statuses ?? ['Confirmed', 'InHouse', 'Reserved'],
    );

    return rawList.map((r) => _mapToCanonical(r, propertyCode)).toList();
  }

  @override
  Future<List<CanonicalRoomCategory>> fetchRoomCategories({
    required String propertyCode,
  }) async {
    try {
      final rawList = await _service.fetchUnitGroups(propertyId: propertyCode);
      final List<CanonicalRoomCategory> categories = [];
      for (final ug in rawList) {
        final id = ug['id']?.toString() ?? '';
        final code = ug['code']?.toString() ?? '';
        final name = ug['name']?.toString() ?? code;
        final desc = ug['description']?.toString();
        final maxPersons = (ug['maxPersons'] as num?)?.toInt() ?? 2;

        if (id.isNotEmpty) {
          categories.add(CanonicalRoomCategory(
            categoryCode: id,
            name: name,
            description: desc,
            maxOccupancy: maxPersons,
          ));
        }
        if (code.isNotEmpty && code != id) {
          categories.add(CanonicalRoomCategory(
            categoryCode: code,
            name: name,
            description: desc,
            maxOccupancy: maxPersons,
          ));
        }
      }
      return categories;
    } catch (_) {
      // Fallback: extract distinct room categories from active reservations
      try {
        final reservations = await fetchReservations(propertyCode: propertyCode);
        final distinctCodes = reservations.map((r) => r.roomCategory).toSet();
        return distinctCodes.map((code) {
          return CanonicalRoomCategory(
            categoryCode: code,
            name: code == 'DBL' ? 'Double Room' : (code == 'SGL' ? 'Single Room' : (code == 'FAMILY' ? 'Family Suite' : code)),
            maxOccupancy: code == 'FAMILY' ? 4 : (code == 'SGL' ? 1 : 2),
          );
        }).toList();
      } catch (_) {
        return const [
          CanonicalRoomCategory(categoryCode: 'DBL', name: 'Double Room', maxOccupancy: 2),
          CanonicalRoomCategory(categoryCode: 'SGL', name: 'Single Room', maxOccupancy: 1),
          CanonicalRoomCategory(categoryCode: 'FAMILY', name: 'Family Suite', maxOccupancy: 4),
        ];
      }
    }
  }

  @override
  Future<List<CanonicalPhysicalRoom>> fetchPhysicalRooms({
    required String propertyCode,
  }) async {
    Map<String, String> categoryNames = {};
    try {
      final categories = await fetchRoomCategories(propertyCode: propertyCode);
      categoryNames = {for (final c in categories) c.categoryCode: c.name};
    } catch (_) {}

    final rawList = await _service.fetchUnits(propertyId: propertyCode);
    return rawList.map((u) {
      final unitGroup = u['unitGroup'] is Map ? (u['unitGroup'] as Map<String, dynamic>) : null;
      final rawCatCode = unitGroup?['id']?.toString() ?? u['unitGroupId']?.toString() ?? '';
      final roomNum = u['name']?.toString() ?? '';

      // Determine floor from room number
      int? floor;
      if (roomNum.startsWith('G.') || roomNum.toLowerCase().startsWith('ground')) {
        floor = 0;
      } else if (RegExp(r'^(\d+)\.').hasMatch(roomNum)) {
        final match = RegExp(r'^(\d+)\.').firstMatch(roomNum);
        floor = int.tryParse(match?.group(1) ?? '');
      } else {
        final numVal = int.tryParse(roomNum);
        if (numVal != null && numVal >= 100) {
          floor = numVal ~/ 100;
        }
      }

      // Determine human-readable category name
      String? categoryName;
      if (categoryNames.containsKey(rawCatCode)) {
        categoryName = categoryNames[rawCatCode];
      } else if (u['description'] != null && u['description'].toString().toLowerCase().contains('penthouse')) {
        categoryName = 'Penthouse';
      } else if (u['description'] != null && u['description'].toString().isNotEmpty) {
        categoryName = u['description'].toString();
      }

      // Determine condition & occupancy
      String statusStr = 'Clean';
      bool isOccupied = false;
      if (u['status'] is Map) {
        final stMap = u['status'] as Map<String, dynamic>;
        statusStr = stMap['condition']?.toString() ?? 'Clean';
        isOccupied = stMap['isOccupied'] == true;
      } else if (u['status'] != null) {
        statusStr = u['status'].toString();
      }

      return CanonicalPhysicalRoom(
        roomId: u['id']?.toString() ?? '',
        roomNumber: roomNum,
        categoryCode: rawCatCode,
        categoryName: categoryName,
        floor: floor,
        maxOccupancy: (u['maxPersons'] as num?)?.toInt(),
        status: statusStr,
        isOccupied: isOccupied,
      );
    }).toList();
  }

  @override
  Future<bool> checkInReservation({
    required String pmsReservationId,
    String? assignedRoomNumber,
  }) async {
    return await _service.checkInReservation(pmsReservationId);
  }

  @override
  Future<bool> checkOutReservation({
    required String pmsReservationId,
  }) async {
    return await _service.checkOutReservation(pmsReservationId);
  }

  @override
  Future<FolioChargeResult> postFolioCharge({
    required String pmsReservationId,
    required double amount,
    required String currency,
    required String description,
    required String serviceType,
  }) async {
    try {
      final resp = await _service.postChargeToFolio(
        reservationId: pmsReservationId,
        amount: amount,
        currency: currency,
        serviceType: serviceType,
        description: description,
      );

      if (resp != null) {
        return FolioChargeResult(
          isSuccess: true,
          chargeId: resp['id']?.toString(),
          rawResponse: resp,
        );
      }
      return const FolioChargeResult(
        isSuccess: false,
        errorMessage: 'Failed to post charge to Apaleo folio.',
      );
    } catch (e) {
      return FolioChargeResult(
        isSuccess: false,
        errorMessage: e.toString(),
      );
    }
  }

  // ─── Mapper ────────────────────────────────────────────────────────────────

  CanonicalReservation _mapToCanonical(Map<String, dynamic> raw, String propertyCode) {
    final guest = raw['primaryGuest'] as Map<String, dynamic>? ?? {};
    final unitGroup = raw['unitGroup'] as Map<String, dynamic>? ?? {};
    final unit = raw['unit'] as Map<String, dynamic>? ?? {};
    final total = raw['totalGrossAmount'] as Map<String, dynamic>? ?? {};

    // Normalise arrival and departure dates
    final arrivalStr = raw['arrival']?.toString() ?? DateTime.now().toIso8601String();
    final departureStr = raw['departure']?.toString() ?? DateTime.now().add(const Duration(days: 1)).toIso8601String();

    final checkIn = DateTime.tryParse(arrivalStr) ?? DateTime.now();
    final checkOut = DateTime.tryParse(departureStr) ?? DateTime.now().add(const Duration(days: 1));

    return CanonicalReservation(
      pmsReservationId: raw['id']?.toString() ?? '',
      bookingReference: raw['bookingId']?.toString() ?? raw['id']?.toString() ?? '',
      propertyCode: propertyCode,
      status: raw['status']?.toString() ?? 'Confirmed',
      checkInDate: checkIn,
      checkOutDate: checkOut,
      primaryGuest: CanonicalGuest(
        firstName: guest['firstName']?.toString().trim() ?? 'Guest',
        lastName: guest['lastName']?.toString().trim() ?? '',
        email: guest['email']?.toString().trim() ?? '',
        phone: guest['phone']?.toString().trim() ?? '',
        nationalityCountryCode: guest['nationalityCountryCode']?.toString(),
      ),
      roomCategory: unitGroup['code']?.toString() ?? 'Standard',
      assignedRoomNumber: unit['name']?.toString(),
      totalAmount: (total['amount'] as num?)?.toDouble() ?? 0.0,
      currency: total['currency']?.toString() ?? 'EUR',
      rawMetadata: raw,
    );
  }
}
