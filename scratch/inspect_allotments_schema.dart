import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://nwtqrmxowhuxubyvyvuv.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53dHFybXhvd2h1eHVieXZ5dnV2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczODIxOTczMiwiZXhwIjoyMDUzNzk1NzMyfQ.iXw5X3JtC3_u714n8Y_Kz8cTqA6zF9y3o9d7G6tX_qg',
  );

  try {
    final sample = await client.from('order_allotments').select().limit(2);
    print('SAMPLE ALLOTMENTS: $sample');
  } catch (e) {
    print('ERROR: $e');
  }
}
