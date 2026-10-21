// Edge functions run in the region nearest the CALLER by default. The database is in
// Tokyo (ap-northeast-1), so a function that runs in Mumbai pays a cross-region round
// trip for every query it makes (verify-payment / push-charges make dozens). Pinning
// them next to the database keeps those queries local.
//
// Passed as a URL query parameter (not the x-region header): a custom header would
// trigger a CORS preflight on web builds and be rejected by the functions.

/// Pin an edge-function call next to the database. Use as:
///   client.functions.invoke('verify-payment', queryParameters: kFunctionRegion, body: ...)
const Map<String, dynamic> kFunctionRegion = {'forceFunctionRegion': 'ap-northeast-1'};
