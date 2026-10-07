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
    const result = await supabase.from('businesses').select('id,name,slug,description,address,is_open,accepting_requests,categories(name,slug)').eq('status','active').eq('verification_status','verified').or(`name.ilike.%${query}%,description.ilike.%${query}%,address.ilike.%${query}%`).order('is_open',{ascending:false}).limit(50);
    businesses = result.data ?? []; error = Boolean(result.error);
  }
  return <main className="container section">
    <span className="eyebrow">SEARCH</span><h1 className="searchTitle">{query ? <>Results for “{query}”</> : 'Search nearby businesses'}</h1>
    <form className="searchBox" action="/search"><span>⌕</span><input name="q" defaultValue={query} placeholder="A4 sheet, tomato, haircut..."/><button>Search</button></form>
    <div style={{height:24}} />
    {!query ? <div className="notice">Start with a need — product, service or shop name.</div> : error ? <div className="notice">Search is temporarily unavailable.</div> : businesses.length === 0 ? <div className="notice">No verified nearby business matched that search yet.</div> : <div className="businessGrid">{businesses.map((b:any)=><Link className="businessCard" key={b.id} href={`/shop/${b.slug}`}><div className="businessTop"><span className={b.is_open?'status open':'status'}>{b.is_open?'Open':'Closed'}</span>{b.accepting_requests&&<span className="requestStatus">Accepting Requests</span>}</div><h3>{b.name}</h3><p>{b.categories?.name ?? 'Local business'}</p><small>{b.address ?? 'Nearby'}</small></Link>)}</div>}
  </main>;
}
