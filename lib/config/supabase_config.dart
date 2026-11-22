// Local development Supabase config
// Copy this file and replace with your credentials for local testing
// In CI/CD, this file is OVERWRITTEN by GitHub Actions with secrets

class SupabaseConfig {
  // Replace with your Supabase project URL (from Project Settings > API)
  static const String supabaseUrl = 'https://your-project.supabase.co';

  // Replace with your Supabase anon/public key (from Project Settings > API)
  static const String supabaseAnonKey = 'your-anon-key-here';
}