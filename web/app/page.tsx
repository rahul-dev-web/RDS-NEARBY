import Link from 'next/link';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

async function getHomeData() {
  if (!supabaseUrl || !supabaseAnonKey) return { categories: [], businesses: [], configured: false };
  const supabase = createClient(supabaseUrl, supabaseAnonKey);
  const [{ data: categories }, { data: businesses }] = await Promise.all([
    supabase.from('categories').select('id,name,slug,icon').eq('status', 'active').order('sort_order').limit(8),
    supabase.from('businesses').select('id,name,slug,description,address,is_open,accepting_requests,category_id,categories(name,slug)').eq('status', 'active').eq('verification_status', 'verified').order('is_open', { ascending: false }).limit(12),
  ]);
  return { categories: categories ?? [], businesses: businesses ?? [], configured: true };
}

export default async function Home() {
  const { categories, businesses, configured } = await getHomeData();
  return (
    <main>
      <section className="hero">
        <div className="container">
          <span className="eyebrow">LOCAL DISCOVERY</span>
          <h1>जो चाहिए, पहले अपने <span>आस-पास देखो।</span></h1>
          <p>Nearby shops, products, services and offers — बिना unnecessary marketplace complexity के.</p>
          <form action="/search" className="searchBox">
            <span>⌕</span><input name="q" placeholder="A4 sheet, tomato, haircut, charger..." /><button>Search</button>
          </form>
          <div className="quickSearches"><span>Try:</span> A4 sheet · tomato · haircut · stationery · mobile repair</div>
        </div>
      </section>

      <section className="container section">
        <div className="sectionHead"><div><span className="eyebrow">EXPLORE</span><h2>Nearby categories</h2></div><span className="muted">Search by what you need</span></div>
        <div className="categoryGrid">
          {categories.map((category: any) => <Link className="categoryCard" key={category.id} href={`/category/${category.slug}`}><strong>{category.name}</strong><span>Explore nearby →</span></Link>)}
        </div>
      </section>

      <section className="container section">
        <div className="sectionHead"><div><span className="eyebrow">NEAR YOU</span><h2>Local businesses</h2></div><span className="muted">Organic Listing</span></div>
        {!configured ? <div className="notice">Web configuration is pending.</div> : businesses.length === 0 ? <div className="notice">No verified businesses are live yet.</div> : <div className="businessGrid">
          {businesses.map((business: any) => <Link className="businessCard" key={business.id} href={`/shop/${business.slug}`}>
            <div className="businessTop"><span className={business.is_open ? 'status open' : 'status'}>{business.is_open ? 'Open' : 'Closed'}</span>{business.accepting_requests && <span className="requestStatus">Accepting Requests</span>}</div>
            <h3>{business.name}</h3><p>{business.categories?.name ?? 'Local business'}</p><small>{business.address ?? 'Nearby'}</small>
          </Link>)}
        </div>}
      </section>

      <section className="growth"><div className="container growthInner"><div><span className="eyebrow">FOR LOCAL BUSINESSES</span><h2>Bring customers. Earn Marketing Credits.</h2><p>Join, share your QR, earn credits from qualified customers, then use them to Boost Shop or Promote Offer.</p></div><Link href="/merchant">Grow your local business →</Link></div></section>
    </main>
  );
}
