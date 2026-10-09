import type { Metadata } from 'next';
import { notFound, redirect } from 'next/navigation';
import { createClient } from '../../../lib/supabase/server';

type Params = { slug: string };

async function submitCustomerRequest(formData: FormData) {
  'use server';

  const businessId = String(formData.get('business_id') ?? '');
  const slug = String(formData.get('slug') ?? '');
  const requestType = String(formData.get('request_type') ?? '');
  const title = String(formData.get('title') ?? '').trim();
  const description = String(formData.get('description') ?? '').trim();
  const safeSlug = /^[a-z0-9-]+$/.test(slug) ? slug : '';

  if (!safeSlug) redirect('/search?request=failed');
  if (!['contact', 'reserve', 'availability'].includes(requestType) || !title || title.length > 120 || description.length > 1000) {
    redirect(`/shop/${safeSlug}?request=invalid`);
  }

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/shop/${safeSlug}?request=login_required`);

  const { error } = await supabase.rpc('create_customer_request', {
    p_business_id: businessId,
    p_request_type: requestType,
    p_title: title,
    p_description: description || null,
  });

  if (error) {
    const code = error.code === '42501' ? 'not_allowed' : error.code === 'P0002' ? 'not_accepting' : 'failed';
    redirect(`/shop/${safeSlug}?request=${code}`);
  }

  redirect(`/shop/${safeSlug}?request=sent`);
}


async function getBusiness(slug: string) {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from('businesses')
    .select(`
      id, name, slug, description, phone, whatsapp, lat, lng, address,
      locality_id, opening_hours, is_open, accepting_requests,
      categories ( name, slug ),
      business_products ( id, name, description, price, unit, is_available, status ),
      business_services ( id, name, description, price, duration_minutes, is_available, status ),
      offers ( id, title, description, regular_price, offer_price, image_url, starts_at, ends_at, status )
    `)
    .eq('slug', slug)
    .eq('status', 'active')
    .eq('verification_status', 'verified')
    .maybeSingle();

  if (error || !data) return null;
  return data;
}

export async function generateMetadata({
  params,
}: {
  params: Promise<Params>;
}): Promise<Metadata> {
  const { slug } = await params;
  const business = await getBusiness(slug);

  if (!business) return { title: 'Shop not found · RDS Nearby' };

  return {
    title: `${business.name} · RDS Nearby`,
    description:
      business.description ||
      `${business.name} — nearby business on RDS Nearby.`,
    alternates: { canonical: `/shop/${business.slug}` },
  };
}

export default async function ShopPage({
  params,
  searchParams,
}: {
  params: Promise<Params>;
  searchParams: Promise<{ request?: string }>;
}) {
  const { slug } = await params;
  const { request: requestState } = await searchParams;
  const business = await getBusiness(slug);

  if (!business) notFound();

  const category = Array.isArray(business.categories)
    ? business.categories[0]
    : business.categories;

  const products = (business.business_products ?? []).filter(
    (item: { status: string; is_available: boolean }) =>
      item.status === 'active' && item.is_available
  );
  const services = (business.business_services ?? []).filter(
    (item: { status: string; is_available: boolean }) =>
      item.status === 'active' && item.is_available
  );
  const now = Date.now();
  const offers = (business.offers ?? []).filter((offer: {
    status: string;
    starts_at: string;
    ends_at: string;
  }) => {
    const start = new Date(offer.starts_at).getTime();
    const end = new Date(offer.ends_at).getTime();
    return offer.status === 'active' && start <= now && end >= now;
  });

  const mapUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
    `${business.lat},${business.lng}`
  )}`;
  const whatsappNumber = String(business.whatsapp ?? '').replace(/[^0-9]/g, '');
  const whatsappUrl = whatsappNumber ? `https://wa.me/${whatsappNumber}` : null;

  return (
    <main>
      <header style={{ background: '#111827', color: '#fff', padding: '28px 0' }}>
        <div className="container">
          <div className="muted" style={{ color: '#b7bec9' }}>
            RDS Nearby · Organic Listing
          </div>
          <h1 style={{ fontSize: 38, margin: '10px 0 6px' }}>{business.name}</h1>
          <p style={{ margin: 0, color: '#d4d9e1' }}>
            {category?.name ?? 'Local business'}
            {business.locality_id ? ` · ${business.locality_id}` : ''}
          </p>
        </div>
      </header>

      <div className="container" style={{ padding: '24px 0 48px' }}>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 18 }}>
          <span className={business.is_open ? 'badge open' : 'badge'}>
            {business.is_open ? 'Open now' : 'Closed'}
          </span>
          {business.accepting_requests && (
            <span className="badge open">Accepting Requests</span>
          )}
        </div>

        <section className="grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))' }}>
          <div className="card">
            <h2 style={{ marginTop: 0 }}>Contact & visit</h2>
            <p className="muted">{business.address || 'Address available in the app.'}</p>
            <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
              {business.phone && <a className="badge" href={`tel:${business.phone}`}>Call</a>}
              {whatsappUrl && <a className="badge" href={whatsappUrl}>WhatsApp</a>}
              <a className="badge" href={mapUrl} target="_blank" rel="noreferrer">Directions</a>
            </div>
          </div>
          <div className="card">
            <h2 style={{ marginTop: 0 }}>About</h2>
            <p className="muted">
              {business.description || 'Local business listed on RDS Nearby.'}
            </p>
            <p className="muted">Business hours are managed by the merchant.</p>
          </div>
        </section>

        {requestState && (
          <div role="status" className="card" style={{ marginTop: 16, borderColor: requestState === 'sent' ? '#16a34a' : '#d97706' }}>
            {requestState === 'sent' && 'Request sent. The shop has up to 10 minutes to respond.'}
            {requestState === 'login_required' && 'Sign in to send a Customer Request. Your request has not been sent.'}
            {requestState === 'not_accepting' && 'This shop is not accepting requests right now.'}
            {requestState === 'not_allowed' && 'You cannot send a request to this business from this account.'}
            {requestState === 'invalid' && 'Check the request type and make sure the title and description are within the allowed length.'}
            {requestState === 'failed' && 'The request could not be sent. Please try again.'}
          </div>
        )}

        {business.accepting_requests && (
          <section className="card" style={{ marginTop: 24 }}>
            <h2 style={{ marginTop: 0 }}>Send a Customer Request</h2>
            <p className="muted">Ask about availability, contact the shop, or request a reservation. The request expires after 10 minutes if the shop does not respond.</p>
            <form action={submitCustomerRequest} style={{ display: 'grid', gap: 12, maxWidth: 640 }}>
              <input type="hidden" name="business_id" value={business.id} />
              <input type="hidden" name="slug" value={business.slug} />
              <label style={{ display: 'grid', gap: 6 }}>
                Request type
                <select name="request_type" required defaultValue="availability" className="input">
                  <option value="availability">Check availability</option>
                  <option value="contact">Contact the shop</option>
                  <option value="reserve">Reservation request</option>
                </select>
              </label>
              <label style={{ display: 'grid', gap: 6 }}>
                What do you need?
                <input name="title" required maxLength={120} placeholder="e.g. Is this product available today?" className="input" />
              </label>
              <label style={{ display: 'grid', gap: 6 }}>
                Details (optional)
                <textarea name="description" maxLength={1000} rows={3} placeholder="Add quantity, preferred time, or other details." className="input" />
              </label>
              <button type="submit" className="badge" style={{ cursor: 'pointer', width: 'fit-content' }}>Send request</button>
            </form>
          </section>
        )}

        {offers.length > 0 && (
          <section style={{ marginTop: 28 }}>
            <h2>Offers</h2>
            <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))' }}>
              {offers.map((offer: {
                id: string;
                title: string;
                description: string | null;
                regular_price: number | null;
                offer_price: number | null;
              }) => (
                <article className="card" key={offer.id}>
                  <span className="badge">Offer</span>
                  <h3>{offer.title}</h3>
                  <p className="muted">{offer.description || 'Limited-time local offer.'}</p>
                  <strong>
                    {offer.offer_price != null ? `₹${offer.offer_price}` : 'Ask shop'}
                    {offer.regular_price != null && (
                      <span className="muted" style={{ marginLeft: 8, textDecoration: 'line-through' }}>
                        ₹{offer.regular_price}
                      </span>
                    )}
                  </strong>
                </article>
              ))}
            </div>
          </section>
        )}

        {products.length > 0 && (
          <section style={{ marginTop: 28 }}>
            <h2>Products</h2>
            <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))' }}>
              {products.map((product: {
                id: string;
                name: string;
                description: string | null;
                price: number | null;
                unit: string | null;
              }) => (
                <article className="card" key={product.id}>
                  <h3>{product.name}</h3>
                  <p className="muted">{product.description || 'Available at this shop.'}</p>
                  <strong>
                    {product.price != null
                      ? `₹${product.price}${product.unit ? ` /${product.unit}` : ''}`
                      : 'Price on request'}
                  </strong>
                </article>
              ))}
            </div>
          </section>
        )}

        {services.length > 0 && (
          <section style={{ marginTop: 28 }}>
            <h2>Services</h2>
            <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))' }}>
              {services.map((service: {
                id: string;
                name: string;
                description: string | null;
                price: number | null;
                duration_minutes: number | null;
              }) => (
                <article className="card" key={service.id}>
                  <h3>{service.name}</h3>
                  <p className="muted">
                    {service.description || 'Service available at this business.'}
                  </p>
                  <strong>
                    {service.price != null ? `₹${service.price}` : 'Price on request'}
                    {service.duration_minutes != null && (
                      <span className="muted"> · {service.duration_minutes} min</span>
                    )}
                  </strong>
                </article>
              ))}
            </div>
          </section>
        )}

        <section style={{ marginTop: 28 }} className="card">
          <h2 style={{ marginTop: 0 }}>RDS Nearby</h2>
          <p className="muted">
            जो चाहिए, पहले अपने आस-पास देखो। This public page is designed for sharing through
            WhatsApp, QR codes and search, then continuing into the app.
          </p>
        </section>
      </div>
    </main>
  );
}
