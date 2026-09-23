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
    final rawList = await _service.fetchReservations(
      propertyId: propertyCode,
      from: from,
      to: to,
      statuses: statuses ?? ['Confirmed', 'InHouse'],
    );

    return rawList.map((r) => _mapToCanonical(r, propertyCode)).toList();
  }

  @override
  Future<List<CanonicalRoomCategory>> fetchRoomCategories({
    required String propertyCode,
  }) async {
    try {
      final rawList = await _service.fetchUnitGroups(propertyId: propertyCode);
      return rawList.map((ug) {
        return CanonicalRoomCategory(
          categoryCode: ug['code']?.toString() ?? '',
          name: ug['name']?.toString() ?? ug['code']?.toString() ?? 'Standard Room',
          description: ug['description']?.toString(),
          maxOccupancy: (ug['maxPersons'] as num?)?.toInt() ?? 2,
        );
      }).toList();
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
    final rawList = await _service.fetchUnits(propertyId: propertyCode);
    return rawList.map((u) {
      return CanonicalPhysicalRoom(
        roomId: u['id']?.toString() ?? '',
        roomNumber: u['name']?.toString() ?? '',
        categoryCode: u['unitGroupId']?.toString() ?? '',
        status: u['status']?.toString() ?? 'Clean',
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
