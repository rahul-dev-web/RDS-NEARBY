# Business Analytics — Phase 16

## North-star metric

**Local Need Solved**: a customer discovers a local business and completes a meaningful action such as calling, WhatsApp, making a Customer Request, or using a merchant-funded Local Points redemption.

## Event vocabulary

The backend accepts only this allowlist:

- `app_open`, `search`, `search_result_click`, `shop_view`, `offer_view`, `shop_saved`, `call_click`, `whatsapp_click`, `reserve`
- `request_created`, `request_accepted`, `request_declined`, `request_expired`
- `referral_created`, `referral_verified`, `referral_qualified`, `referral_rejected`
- `merchant_credit_awarded`, `merchant_credit_spent`, `customer_points_awarded`, `customer_points_redeemed`
- `campaign_created`, `campaign_impression`, `campaign_click`
- `membership_started`, `membership_renewed`, `membership_cancelled`

Authenticated clients record events through `public.record_analytics_event(event_name, business_id, metadata)`. The RPC rejects unknown event names, non-object/oversized metadata, sensitive metadata keys, and unavailable business IDs. Analytics failures must never block the customer action.

## Merchant dashboard

The Flutter Merchant menu includes **Business Analytics**, scoped to a business owned by the signed-in merchant. It supports 7-, 30-, and 90-day windows and displays:

- Shop views, search result clicks, offers viewed, offer claims, call clicks, WhatsApp clicks, saved shops
- Requests received/responded and qualified referral customers
- Marketing Credits earned/spent/current balance, Boost Shop and Promote Offer campaigns
- Approved Local Points redemptions and merchant-funded discount totals

The dashboard RPC returns aggregate counts only; it does not expose customer identities or raw event metadata. Transactional metrics come from requests, referrals, credit ledger, campaigns, wallet and redemption tables rather than client-supplied financial events.

## Implementation details and limitations

- Public shop-page views and offer exposures are recorded for authenticated visitors. Anonymous web visits are not counted yet because event recording currently requires authentication.
- Flutter records non-empty searches, call clicks, WhatsApp clicks and successfully created Customer Requests.
- There is no separate Offer Claim feature yet, so offer-claim counts remain zero until that flow exists and records an event.
- Shop saves and mobile shop/offer detail views are not fully wired in the current UI; corresponding counts may remain zero.
- Client event telemetry can be duplicated or spoofed and is **not** an authority for billing, rewards, fraud decisions or membership eligibility.
- No production traffic means metrics may legitimately be zero. Do not create fake production activity to make dashboards look populated.

## Merchant KPIs

- Active Businesses
- Requests Received and Responded
- Qualified Referral Customers
- Call / WhatsApp Clicks
- Credits Earned and Used
- Boost Shop / Promote Offer Usage
- Local Points Redemptions and Discounts

## Referral KPIs

- QR scans
- Signup conversion
- OTP verification
- Activation and qualification rate
- 48-hour qualification rate
- Average referrals per merchant
- Fraud rate

Analytics must support product utility and demonstrate real merchant value; it must not become a substitute for it.
