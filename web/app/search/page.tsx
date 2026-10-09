import Link from 'next/link';
import { createClient } from '@supabase/supabase-js';

export default async function SearchPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  const { q = '' } = await searchParams;
  const query = q.trim();
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  let businesses: any[] = [];
  let offers: any[] = [];
  let products: any[] = [];
  let services: any[] = [];
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
    const baseRanked = [...unique.values()]
      .sort((a, b) => Number(b.is_open) - Number(a.is_open))
      .slice(0, 50);
    const { data: boosts } = await supabase
      .from('campaigns')
      .select('business_id')
      .eq('campaign_type', 'boost_shop')
      .eq('status', 'active')
      .lte('starts_at', new Date().toISOString())
      .gt('ends_at', new Date().toISOString());
    // If campaign lookup is temporarily unavailable, keep organic discovery usable.
    const boostedIds = new Set((boosts ?? []).map((campaign: any) => campaign.business_id));
    const organic = baseRanked.filter((business) => !boostedIds.has(business.id));
    const sponsored = baseRanked.filter((business) => boostedIds.has(business.id));
    // Moderate sponsored signal: at most one sponsored result per four slots.
    businesses = [];
    while (organic.length || sponsored.length) {
      businesses.push(...organic.splice(0, 3));
      if (sponsored.length) businesses.push(sponsored.shift());
    }
    businesses = businesses.map((business) => ({ ...business, is_sponsored: boostedIds.has(business.id) }));

    // Product and service inventory is searchable independently from merchant names.
    // RLS limits these results to active, available inventory at active verified businesses.
    const [productResult, serviceResult] = await Promise.all([
      supabase.from('business_products')
        .select('id,business_id,name,description,price,unit,businesses(name,slug,address)')
        .eq('status', 'active').eq('is_available', true)
        .or(`name.ilike.${pattern},description.ilike.${pattern}`).limit(30),
      supabase.from('business_services')
        .select('id,business_id,name,description,price,duration_minutes,businesses(name,slug,address)')
        .eq('status', 'active').eq('is_available', true)
        .or(`name.ilike.${pattern},description.ilike.${pattern}`).limit(30),
    ]);
    // Inventory search is supplementary and should not take down shop discovery.
    products = productResult.data ?? [];
    services = serviceResult.data ?? [];

    // Offers are independent search results: Promote Offer must never mark the whole shop sponsored.
    const [offerResult, offerCampaignResult] = await Promise.all([
      supabase.from('offers')
        .select('id,business_id,title,description,regular_price,offer_price,image_url,starts_at,ends_at,businesses(name,slug,address)')
        .eq('status', 'active')
        .lte('starts_at', new Date().toISOString())
        .gt('ends_at', new Date().toISOString())
        .or(`title.ilike.${pattern},description.ilike.${pattern}`)
        .limit(30),
      supabase.from('campaigns')
        .select('offer_id')
        .eq('campaign_type', 'promote_offer')
        .eq('status', 'active')
        .lte('starts_at', new Date().toISOString())
        .gt('ends_at', new Date().toISOString())
        .not('offer_id', 'is', null),
    ]);
    // Offers are optional supplementary results; don't blank valid shop results if this query fails.
    const promotedOfferIds = new Set(
      (offerCampaignResult.data ?? []).map((campaign: any) => campaign.offer_id).filter(Boolean),
    );
    offers = (offerResult.data ?? []).map((offer: any) => ({
      ...offer,
      is_sponsored: promotedOfferIds.has(offer.id),
    }));
  }
  return <main className="container section">
    <span className="eyebrow">SEARCH</span><h1 className="searchTitle">{query ? <>Results for “{query}”</> : 'Search nearby businesses'}</h1>
    <form className="searchBox" action="/search"><span>⌕</span><input name="q" defaultValue={query} placeholder="A4 sheet, tomato, haircut..."/><button>Search</button></form>
    <div style={{height:24}} />
    {!query ? <div className="notice">Start with a need — product, service or shop name.</div> : error ? <div className="notice">Search is temporarily unavailable.</div> : businesses.length === 0 && offers.length === 0 && products.length === 0 && services.length === 0 ? <div className="notice">No verified shop, product, service or active offer matched that search yet.</div> : <>
      {products.length > 0 && <><h2>Matching products</h2><div className="businessGrid">{products.map((product:any)=><Link className="businessCard" key={product.id} href={product.businesses?.slug ? `/shop/${product.businesses.slug}` : '/search'}><div className="businessTop"><span className="status open">Product</span><span className="status">{product.is_available === false ? 'Unavailable' : 'Available'}</span></div><h3>{product.name}</h3><p>{product.description ?? ''}</p><p>{product.price != null ? <>₹{product.price}{product.unit ? <small> / {product.unit}</small> : null}</> : 'Ask shop for price'}</p><small>{product.businesses?.name ?? 'Local shop'} · {product.businesses?.address ?? 'Nearby'}</small></Link>)}</div></>}
      {services.length > 0 && <><h2>Matching services</h2><div className="businessGrid">{services.map((service:any)=><Link className="businessCard" key={service.id} href={service.businesses?.slug ? `/shop/${service.businesses.slug}` : '/search'}><div className="businessTop"><span className="status open">Service</span></div><h3>{service.name}</h3><p>{service.description ?? ''}</p><p>{service.price != null ? `₹${service.price}` : 'Ask provider for price'}{service.duration_minutes ? <small> · {service.duration_minutes} min</small> : null}</p><small>{service.businesses?.name ?? 'Local provider'} · {service.businesses?.address ?? 'Nearby'}</small></Link>)}</div></>}
      {offers.length > 0 && <><h2>Matching offers</h2><div className="businessGrid">{offers.map((offer:any)=><Link className="businessCard" key={offer.id} href={offer.businesses?.slug ? `/shop/${offer.businesses.slug}` : '/search'}><div className="businessTop"><span className="status open">Offer</span>{offer.is_sponsored&&<span className="requestStatus">SPONSORED</span>}</div><h3>{offer.title}</h3><p>{offer.description ?? ''}</p><p>{offer.offer_price != null ? <>₹{offer.offer_price}{offer.regular_price != null && <small> · <s>₹{offer.regular_price}</s></small>}</> : 'Ask shop for price'}</p><small>{offer.businesses?.name ?? 'Local shop'} · {offer.businesses?.address ?? 'Nearby'}</small></Link>)}</div></>}
      {businesses.length > 0 && <><h2>Matching shops</h2><div className="businessGrid">{businesses.map((b:any)=><Link className="businessCard" key={b.id} href={`/shop/${b.slug}`}><div className="businessTop"><span className={b.is_open?'status open':'status'}>{b.is_open?'Open':'Closed'}</span>{b.is_sponsored&&<span className="requestStatus">SPONSORED</span>}{b.accepting_requests&&<span className="requestStatus">Accepting Requests</span>}</div><h3>{b.name}</h3><p>{b.categories?.name ?? 'Local business'}</p><small>{b.address ?? 'Nearby'}</small></Link>)}</div></>}
    </>}
  </main>;
}
