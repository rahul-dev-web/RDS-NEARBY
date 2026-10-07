import Link from 'next/link';
import { createClient } from '@supabase/supabase-js';

export default async function SearchPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  const { q = '' } = await searchParams;
  const query = q.trim();
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  let businesses: any[] = [];
  let error = false;
  if (url && key && query) {
    const supabase = createClient(url, key);
    // Escape LIKE metacharacters before using user input in ilike patterns.
    const escaped = query.replace(/\\/g, '\\\\').replace(/%/g, '\\%').replace(/_/g, '\\_');
    const select = 'id,name,slug,description,address,is_open,accepting_requests,categories(name,slug)';
    const pattern = `%${escaped}%`;
    const [nameResult, descriptionResult, addressResult] = await Promise.all([
      supabase.from('businesses').select(select).eq('status','active').eq('verification_status','verified').ilike('name', pattern).limit(50),
      supabase.from('businesses').select(select).eq('status','active').eq('verification_status','verified').ilike('description', pattern).limit(50),
      supabase.from('businesses').select(select).eq('status','active').eq('verification_status','verified').ilike('address', pattern).limit(50),
    ]);
    error = Boolean(nameResult.error || descriptionResult.error || addressResult.error);
    const merged = [...(nameResult.data ?? []), ...(descriptionResult.data ?? []), ...(addressResult.data ?? [])];
    const unique = new Map(merged.map((business) => [business.id, business]));
    businesses = [...unique.values()]
      .sort((a, b) => Number(b.is_open) - Number(a.is_open))
      .slice(0, 50);
  }
  return <main className="container section">
    <span className="eyebrow">SEARCH</span><h1 className="searchTitle">{query ? <>Results for “{query}”</> : 'Search nearby businesses'}</h1>
    <form className="searchBox" action="/search"><span>⌕</span><input name="q" defaultValue={query} placeholder="A4 sheet, tomato, haircut..."/><button>Search</button></form>
    <div style={{height:24}} />
    {!query ? <div className="notice">Start with a need — product, service or shop name.</div> : error ? <div className="notice">Search is temporarily unavailable.</div> : businesses.length === 0 ? <div className="notice">No verified nearby business matched that search yet.</div> : <div className="businessGrid">{businesses.map((b:any)=><Link className="businessCard" key={b.id} href={`/shop/${b.slug}`}><div className="businessTop"><span className={b.is_open?'status open':'status'}>{b.is_open?'Open':'Closed'}</span>{b.accepting_requests&&<span className="requestStatus">Accepting Requests</span>}</div><h3>{b.name}</h3><p>{b.categories?.name ?? 'Local business'}</p><small>{b.address ?? 'Nearby'}</small></Link>)}</div>}
  </main>;
}
