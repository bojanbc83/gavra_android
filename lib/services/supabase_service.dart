import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class SupabaseService {
  static SupabaseClient? _instance;

  static SupabaseClient get instance {
    _instance ??= SupabaseClient(supabaseUrl, supabaseAnonKey);
    return _instance!;
  }

  // Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // Get client
  static SupabaseClient get client => Supabase.instance.client;
}
