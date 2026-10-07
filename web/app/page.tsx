import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export default async function Home() {
  let status = 'Supabase configuration pending.';

  if (supabaseUrl && supabaseAnonKey) {
    const supabase = createClient(supabaseUrl, supabaseAnonKey);
    const { error } = await supabase.from('categories').select('id').limit(1);
    status = error ? 'Supabase reachable; schema query needs review.' : 'Supabase connected.';
  }

  return (
    <main style={{ padding: 32, fontFamily: 'system-ui' }}>
      <h1>RDS Nearby</h1>
      <p>जो चाहिए, पहले अपने आस-पास देखो।</p>
      <p>Public shop and referral web foundation.</p>
      <small>{status}</small>
    </main>
  );
}
