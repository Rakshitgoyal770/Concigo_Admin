import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  final client = SupabaseClient(
    'https://nscxukbdfgqdtteepkcr.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5zY3h1a2JkZmdxZHR0ZWVwa2NyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDMxODAyOTEsImV4cCI6MjA1ODc1NjI5MX0.Qx7y95zXoPzF_Y-tI3s5oU3sD97hQ7uX4m56qA6qI7w',
  );

  try {
    final rows = await client.from('hotel_property').select().limit(2);
    print('Found ${rows.length} rows in hotel_property:');
    for (final r in rows) {
      print(r);
    }
  } catch (e) {
    print('Error: $e');
  }
}
