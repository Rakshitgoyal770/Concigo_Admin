import 'package:supabase_flutter/supabase_flutter.dart';
import 'adapters/apaleo_adapter.dart';
import 'pms_adapter.dart';

/// Factory that resolves the correct [PmsAdapter] and property code
/// for any hotel in the database.
class PmsFactory {
  PmsFactory._();

  static final Map<String, PmsAdapter> _adapterCache = {};

  /// Resolves the PMS configuration and returns an active [PmsConfigContext].
  static Future<PmsConfigContext> getContextForHotel({
    required SupabaseClient client,
    required String propertyId,
  }) async {
    try {
      final configResp = await client
          .from('hotel_pms_config')
          .select('pms_type, pms_hotel_code')
          .eq('property_id', propertyId)
          .maybeSingle();

      if (configResp != null) {
        final pmsType = (configResp['pms_type'] as String? ?? 'apaleo').toLowerCase();
        final propertyCode = configResp['pms_hotel_code'] as String? ?? 'BER';
        final adapter = _resolveAdapter(pmsType);

        return PmsConfigContext(
          adapter: adapter,
          propertyCode: propertyCode,
          propertyId: propertyId,
        );
      }
    } catch (_) {
      // Fallback if hotel_pms_config table does not exist or query fails
    }

    // Default fallback: Apaleo for Hotel Berlin
    return PmsConfigContext(
      adapter: _resolveAdapter('apaleo'),
      propertyCode: 'BER',
      propertyId: propertyId,
    );
  }

  static PmsAdapter _resolveAdapter(String pmsType) {
    if (_adapterCache.containsKey(pmsType)) {
      return _adapterCache[pmsType]!;
    }

    switch (pmsType) {
      case 'apaleo':
        final adapter = ApaleoAdapter();
        _adapterCache['apaleo'] = adapter;
        return adapter;

      // Future PMS integrations plug in right here:
      // case 'cloudbeds':
      //   return CloudbedsAdapter();
      // case 'opera':
      //   return OperaAdapter();

      default:
        // Default to Apaleo
        final adapter = ApaleoAdapter();
        _adapterCache['apaleo'] = adapter;
        return adapter;
    }
  }
}

/// Context pairing the resolved [PmsAdapter] with the hotel's PMS property code.
class PmsConfigContext {
  final PmsAdapter adapter;
  final String propertyCode; // e.g. 'BER', 'MUC'
  final String propertyId;   // Concigo UUID

  const PmsConfigContext({
    required this.adapter,
    required this.propertyCode,
    required this.propertyId,
  });
}
