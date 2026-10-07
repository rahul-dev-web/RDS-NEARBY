import { notFound } from 'next/navigation';
import { createClient } from '../../../lib/supabase/server';

export default async function CategoryPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const supabase = await createClient();
  const { data: category } = await supabase.from('categories').select('id,name,slug').eq('slug', slug).eq('status','active').maybeSingle();
  if (!category) notFound();
  const { data: businesses } = await supabase.from('businesses').select('id,name,slug,description,address,is_open,accepting_requests').eq('category_id', category.id).eq('status','active').eq('verification_status','verified').order('name');
  return <main className="container"><p className="muted">RDS Nearby · Organic Listing</p><h1>{category.name} near you</h1><p className="muted">Nearby businesses in {category.name}.</p><div className="grid">{(businesses ?? []).map((b: any) => <a className="card" key={b.id} href={`/shop/${b.slug}`}><h2>{b.name}</h2><p className="muted">{b.description || b.address || 'Local business'}</p><span className={b.is_open ? 'badge open' : 'badge'}>{b.is_open ? 'Open now' : 'Closed'}</span>{b.accepting_requests && <span className="badge open" style={{marginLeft:6}}>Accepting Requests</span>}</a>)}</div></main>;
}
