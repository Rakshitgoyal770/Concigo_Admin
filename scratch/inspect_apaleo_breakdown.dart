import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final configFile = File('lib/services/pms/apaleo_config.json');
  final config = jsonDecode(await configFile.readAsString());
  final token = config['access_token'];

  // 1. Fetch Unit Groups
  final ugRes = await http.get(
    Uri.parse('https://api.apaleo.com/inventory/v1/unit-groups?propertyId=BER&pageSize=100'),
    headers: {'Authorization': 'Bearer $token'},
  );
  print('=== UNIT GROUPS (BER) ===');
  final ugData = jsonDecode(ugRes.body);
  final List ugList = ugData['unitGroups'] ?? [];
  final ugMap = <String, String>{};
  for (final ug in ugList) {
    print('ID: ${ug['id']}, Code: ${ug['code']}, Name: ${ug['name']}, MaxPersons: ${ug['maxPersons']}');
    ugMap[ug['id']] = ug['name'] ?? ug['code'] ?? 'Standard';
  }

  // 2. Fetch Units
  final unitsRes = await http.get(
    Uri.parse('https://api.apaleo.com/inventory/v1/units?propertyId=BER&pageSize=150'),
    headers: {'Authorization': 'Bearer $token'},
  );
  final unitsData = jsonDecode(unitsRes.body);
  final List unitsList = unitsData['units'] ?? [];
  print('\n=== TOTAL UNITS FETCHED: ${unitsList.length} (Total Count: ${unitsData['count']}) ===');
  
  // Show breakdown by category
  final catCount = <String, int>{};
  for (final u in unitsList) {
    final ugId = u['unitGroup']?['id'] ?? 'NONE';
    final catName = ugMap[ugId] ?? ugId;
    catCount[catName] = (catCount[catName] ?? 0) + 1;
  }
  print('\nBreakdown by category: $catCount');
}
