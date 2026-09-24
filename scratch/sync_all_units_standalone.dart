import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';

  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  const propertyId = 'b0000001-0000-0000-0000-000000000001';

  final configFile = File('lib/services/pms/apaleo_config.json');
  final config = jsonDecode(await configFile.readAsString());
  final token = config['access_token'];

  // 1. Fetch Categories
  final ugRes = await http.get(
    Uri.parse('https://api.apaleo.com/inventory/v1/unit-groups?propertyId=BER&pageSize=100'),
    headers: {'Authorization': 'Bearer $token'},
  );
  final ugData = jsonDecode(ugRes.body);
  final ugList = (ugData['unitGroups'] as List?) ?? [];
  final ugMap = <String, String>{};
  for (final ug in ugList) {
    final id = ug['id']?.toString() ?? '';
    final code = ug['code']?.toString() ?? '';
    final name = ug['name']?.toString() ?? code;
    if (id.isNotEmpty) ugMap[id] = name;
    if (code.isNotEmpty) ugMap[code] = name;
  }

  // 2. Fetch All Physical Units dynamically
  final List<Map<String, dynamic>> allUnits = [];
  int pageNumber = 1;
  const pageSize = 100;
  int totalCount = 0;

  do {
    final uri = Uri.parse(
      'https://api.apaleo.com/inventory/v1/units?propertyId=BER&pageNumber=$pageNumber&pageSize=$pageSize',
    );
    final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final list = (data['units'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      allUnits.addAll(list);
      totalCount = (data['count'] as num?)?.toInt() ?? allUnits.length;
      if (list.length < pageSize || allUnits.length >= totalCount) break;
      pageNumber++;
    } else {
      throw Exception('Failed to fetch units: ${resp.statusCode}');
    }
  } while (allUnits.length < totalCount);

  print('Fetched ${allUnits.length} physical units from Apaleo.');

  // 3. Query existing rooms in Supabase
  final existingRows = await client
      .from('rooms')
      .select('room_id, room_number')
      .eq('property_id', propertyId);

  final Map<String, String> existingMap = {
    for (final r in (existingRows as List))
      r['room_number']?.toString() ?? '': r['room_id']?.toString() ?? '',
  };
  print('Existing rooms in Supabase before sync: ${existingMap.length}');

  // 4. Upsert into Supabase rooms table
  int insertedCount = 0;
  int updatedCount = 0;

  for (final u in allUnits) {
    final roomNum = u['name']?.toString() ?? '';
    if (roomNum.isEmpty) continue;

    final unitGroup = u['unitGroup'] is Map ? (u['unitGroup'] as Map<String, dynamic>) : null;
    final ugId = unitGroup?['id']?.toString() ?? u['unitGroupId']?.toString() ?? '';

    // Floor calculation
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

    // Category Name
    String roomType = ugMap[ugId] ?? 'Standard';
    if (u['description'] != null && u['description'].toString().toLowerCase().contains('penthouse')) {
      roomType = 'Penthouse';
    } else if (ugId.isEmpty && u['description'] != null && u['description'].toString().isNotEmpty) {
      roomType = u['description'].toString();
    }

    final roomId = existingMap[roomNum];
    if (roomId != null) {
      await client.from('rooms').update({
        'type': roomType,
        if (floor != null) 'floor': floor,
        'is_active': true,
      }).eq('room_id', roomId);
      updatedCount++;
    } else {
      final isOccupied = u['status'] is Map && u['status']['isOccupied'] == true;
      final inserted = await client.from('rooms').insert({
        'property_id': propertyId,
        'room_number': roomNum,
        'type': roomType,
        'floor': floor,
        'is_active': true,
        'is_booked': isOccupied,
      }).select('room_id').single();
      existingMap[roomNum] = inserted['room_id'] as String;
      insertedCount++;
    }
  }

  print('Sync completed: $insertedCount newly inserted, $updatedCount updated.');

  // 5. Verify total rooms in Supabase
  final finalRows = await client
      .from('rooms')
      .select('room_number, floor, type, is_booked')
      .eq('property_id', propertyId);

  print('Total rooms in Supabase now: ${finalRows.length}');
  
  // Floor breakdown
  final floorCounts = <String, int>{};
  for (final r in finalRows) {
    final fl = 'Floor ${r['floor']}';
    floorCounts[fl] = (floorCounts[fl] ?? 0) + 1;
  }
  print('Rooms by floor in Supabase: $floorCounts');
}
