import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://qmgrkogxqfqaimtcfvsp.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc',
  );

  print('--- Querying property_employees for 9876543210 ---');
  try {
    final emps = await supabase
        .from('property_employees')
        .select()
        .eq('emp_mobile', '9876543210');
    print('Employees: $emps');
  } catch (e) {
    print('Error fetching employees: $e');
  }

  print('\n--- Querying service_orders (all recent) ---');
  try {
    final orders = await supabase
        .from('service_orders')
        .select('so_id, stay_id, room_id, serv_id, status, created_at, user_id, guest_notes')
        .order('created_at', ascending: false)
        .limit(10);
    print('Recent service_orders count: ${orders.length}');
    for (var o in orders) {
      print(o);
    }
  } catch (e) {
    print('Error fetching service_orders: $e');
  }

  print('\n--- Querying users for Rakshit Goyal ---');
  try {
    final users = await supabase
        .from('users')
        .select('user_id, full_name, mobile_num')
        .ilike('full_name', '%Rakshit%');
    print('Users matching Rakshit: $users');
  } catch (e) {
    print('Error fetching users: $e');
  }

  print('\n--- Querying stays for users matching Rakshit ---');
  try {
    final users = await supabase
        .from('users')
        .select('user_id')
        .ilike('full_name', '%Rakshit%');
    for (var u in users) {
      final uid = u['user_id'];
      final stays = await supabase
          .from('stay')
          .select('stay_id, hotel_id, status, check_in, check_out, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(5);
      print('Stays for user $uid: $stays');
    }
  } catch (e) {
    print('Error fetching stays: $e');
  }
}
