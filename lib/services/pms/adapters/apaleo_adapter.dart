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
      statuses: statuses ?? ['Confirmed', 'InHouse', 'Reserved', 'Canceled', 'CheckedOut'],
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
          chargeId: resp['id']?.toString() ?? resp['folioId']?.toString(),
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

  @override
  Future<CanonicalFolio?> fetchFolio({
    required String pmsReservationId,
  }) async {
    try {
      final rawFolio = await _service.fetchCompleteFolio(pmsReservationId);
      if (rawFolio == null) return null;
      return _mapToCanonicalFolio(rawFolio, pmsReservationId);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<FolioPaymentResult> recordFolioPayment({
    required String folioId,
    required double amount,
    required String currency,
    required String paymentMethod,
    String? receipt,
  }) async {
    try {
      final resp = await _service.recordFolioPayment(
        folioId: folioId,
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
        receipt: receipt,
      );
      if (resp != null) {
        return FolioPaymentResult(
          isSuccess: true,
          paymentId: resp['id']?.toString() ?? resp['folioId']?.toString(),
          rawResponse: resp,
        );
      }
      return const FolioPaymentResult(
        isSuccess: false,
        errorMessage: 'Failed to record payment in Apaleo folio.',
      );
    } catch (e) {
      return FolioPaymentResult(
        isSuccess: false,
        errorMessage: e.toString(),
      );
    }
  }

  CanonicalFolio _mapToCanonicalFolio(Map<String, dynamic> raw, String pmsReservationId) {
    final folioId = raw['id']?.toString() ?? '';
    final bookingId = raw['bookingId']?.toString();
    final status = raw['status']?.toString() ?? 'Open';
    final isMainFolio = raw['isMainFolio'] == true;

    // Balance in Apaleo: negative indicates money owed by guest (e.g. -166.00 means 166.00 due)
    final balMap = raw['balance'] as Map<String, dynamic>? ?? {};
    final rawBal = (balMap['amount'] as num?)?.toDouble() ?? 0.0;
    final currency = balMap['currency']?.toString() ?? 'EUR';
    // Positive balance represents amount payable/due by guest
    final double netBalanceDue = rawBal < 0 ? -rawBal : (rawBal == 0 ? 0.0 : rawBal);

    // Map charges
    final rawCharges = (raw['charges'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final List<CanonicalFolioCharge> charges = [];
    for (final c in rawCharges) {
      final amtMap = c['amount'] as Map<String, dynamic>? ?? {};
      final gross = (amtMap['grossAmount'] as num?)?.toDouble() ?? (amtMap['amount'] as num?)?.toDouble() ?? 0.0;
      final net = (amtMap['netAmount'] as num?)?.toDouble() ?? gross;
      final vatPct = (amtMap['vatPercent'] as num?)?.toDouble() ?? 0.0;
      final curr = amtMap['currency']?.toString() ?? currency;
      final sDateStr = c['serviceDate']?.toString();

      charges.add(CanonicalFolioCharge(
        id: c['id']?.toString() ?? '',
        name: c['name']?.toString() ?? 'Charge',
        serviceType: c['serviceType']?.toString() ?? 'Other',
        serviceDate: sDateStr != null ? DateTime.tryParse(sDateStr) : null,
        grossAmount: gross,
        netAmount: net,
        vatPercent: vatPct,
        currency: curr,
        quantity: (c['quantity'] as num?)?.toInt() ?? 1,
        isPosted: c['isPosted'] != false,
        rawMetadata: c,
      ));
    }

    // Map payments
    final rawPayments = (raw['payments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final List<CanonicalFolioPayment> payments = [];
    for (final p in rawPayments) {
      final amtMap = p['amount'] as Map<String, dynamic>? ?? {};
      final amt = (amtMap['amount'] as num?)?.toDouble() ?? 0.0;
      final curr = amtMap['currency']?.toString() ?? currency;
      final pDateStr = (p['paymentDate'] ?? p['created'])?.toString();

      payments.add(CanonicalFolioPayment(
        id: p['id']?.toString() ?? '',
        method: p['method']?.toString() ?? 'Payment',
        amount: amt,
        currency: curr,
        paymentDate: pDateStr != null ? DateTime.tryParse(pDateStr) : null,
        status: p['status']?.toString(),
        rawMetadata: p,
      ));
    }

    final allowed = (raw['allowedActions'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return CanonicalFolio(
      folioId: folioId,
      reservationId: pmsReservationId,
      bookingId: bookingId,
      status: status,
      currency: currency,
      balance: netBalanceDue,
      isMainFolio: isMainFolio,
      charges: charges,
      payments: payments,
      allowedActions: allowed,
      rawMetadata: raw,
    );
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
