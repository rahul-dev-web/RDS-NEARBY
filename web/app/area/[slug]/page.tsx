import { notFound } from 'next/navigation';
import { createClient } from '../../../lib/supabase/server';

export default async function AreaPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const supabase = await createClient();
  const locality = slug.replace(/-/g, ' ');
  const { data: businesses } = await supabase.from('businesses').select('id,name,slug,description,address,is_open,accepting_requests,categories(name)').eq('locality_id', locality).eq('status','active').eq('verification_status','verified').order('name');
  if (!businesses) notFound();
  return <main className="container"><p className="muted">RDS Nearby · Organic Listing</p><h1>Shops in {locality}</h1><p className="muted">Find local businesses around {locality}.</p><div className="grid">{businesses.map((b: any) => <a className="card" key={b.id} href={`/shop/${b.slug}`}><h2>{b.name}</h2><p className="muted">{b.categories?.name || 'Local business'} · {b.description || b.address || 'Nearby'}</p><span className={b.is_open ? 'badge open' : 'badge'}>{b.is_open ? 'Open now' : 'Closed'}</span></a>)}</div></main>;
}
