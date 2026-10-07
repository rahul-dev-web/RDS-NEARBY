const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');
bool get hasSupabaseConfig => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
