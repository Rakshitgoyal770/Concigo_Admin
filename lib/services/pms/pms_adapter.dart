/// Universal PMS Interface & Canonical Data Models.
///
/// This contract decouples Concigo from any specific PMS vendor (Apaleo, Cloudbeds, Mews, Opera).
/// Any new PMS integration only needs to implement [PmsAdapter] without modifying
/// Concigo UI, check-in flows, or database structures.

abstract class PmsAdapter {
  /// Unique identifier of the PMS provider (e.g. 'apaleo', 'cloudbeds', 'opera').
  String get provider;

  /// 1. Fetch live reservations for a specific hotel property.
  Future<List<CanonicalReservation>> fetchReservations({
    required String propertyCode,
    DateTime? from,
    DateTime? to,
    List<String>? statuses,
  });

  /// 2. Fetch room categories (unit-groups in Apaleo, room_types in Cloudbeds).
  Future<List<CanonicalRoomCategory>> fetchRoomCategories({
    required String propertyCode,
  });

  /// 3. Fetch physical rooms (units).
  Future<List<CanonicalPhysicalRoom>> fetchPhysicalRooms({
    required String propertyCode,
  });

  /// 4. Perform digital check-in in the PMS.
  Future<bool> checkInReservation({
    required String pmsReservationId,
    String? assignedRoomNumber,
  });

  /// 5. Perform digital check-out in the PMS.
  Future<bool> checkOutReservation({
    required String pmsReservationId,
  });

  /// 6. Post an upsell or service charge directly to the guest's room folio bill.
  Future<FolioChargeResult> postFolioCharge({
    required String pmsReservationId,
    required double amount,
    required String currency,
    required String description,
    required String serviceType, // e.g. 'Extra', 'FoodAndBeverage', 'Other'
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CANONICAL DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class CanonicalReservation {
  final String pmsReservationId;
  final String bookingReference;
  final String propertyCode;
  final String status; // 'Confirmed', 'InHouse', 'Canceled', 'CheckedOut'
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final CanonicalGuest primaryGuest;
  final String roomCategory; // Normalized code, e.g. 'DBL', 'SGL', 'FAMILY'
  final String? assignedRoomNumber;
  final double totalAmount;
  final String currency;
  final Map<String, dynamic> rawMetadata;

  const CanonicalReservation({
    required this.pmsReservationId,
    required this.bookingReference,
    required this.propertyCode,
    required this.status,
    required this.checkInDate,
    required this.checkOutDate,
    required this.primaryGuest,
    required this.roomCategory,
    this.assignedRoomNumber,
    required this.totalAmount,
    required this.currency,
    this.rawMetadata = const {},
  });
}

class CanonicalGuest {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String? nationalityCountryCode;

  const CanonicalGuest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.nationalityCountryCode,
  });

  String get fullName => '$firstName $lastName'.trim();
}

class CanonicalRoomCategory {
  final String categoryCode; // e.g. 'DBL', 'SGL', 'FAMILY'
  final String name;         // e.g. 'Standard Double Room'
  final String? description;
  final int maxOccupancy;

  const CanonicalRoomCategory({
    required this.categoryCode,
    required this.name,
    this.description,
    this.maxOccupancy = 2,
  });
}

class CanonicalPhysicalRoom {
  final String roomId;      // PMS unit ID
  final String roomNumber;  // e.g. '101', '204', '1.001'
  final String categoryCode;
  final String? categoryName;
  final int? floor;
  final int? maxOccupancy;
  final String status;      // 'Clean', 'CleanToBeInspected', 'Dirty'
  final bool isOccupied;

  const CanonicalPhysicalRoom({
    required this.roomId,
    required this.roomNumber,
    required this.categoryCode,
    this.categoryName,
    this.floor,
    this.maxOccupancy,
    required this.status,
    this.isOccupied = false,
  });
}

class FolioChargeResult {
  final bool isSuccess;
  final String? chargeId;
  final String? errorMessage;
  final Map<String, dynamic>? rawResponse;

  const FolioChargeResult({
    required this.isSuccess,
    this.chargeId,
    this.errorMessage,
    this.rawResponse,
  });
}
