# Search & Ranking

## Product goal

Search solves a local need. It is not a social feed.

Examples:
- A4 sheet
- tomato
- haircut
- stationery
- charger
- school shoes
- mobile repair

## Filters

- Distance
- Open Now
- Available
- Price
- Offer
- Category

## Ranking inputs

Final ranking combines:
1. Relevance
2. Distance
3. Availability
4. Quality
5. Activity
6. Moderate sponsored signal

Sponsored results are labelled:
SPONSORED

Organic results remain meaningful.

## Discovery eligibility

A business must be active and verified for public discovery.

Products/services/offers must also be active and within their valid availability windows where applicable.

## Location

Customer location is transient:
- current location
- selected locality
- approximate area

Do not require permanent storage of precise customer GPS coordinates.

Business latitude/longitude is mandatory.

## Query evolution

Initial implementation should use PostgreSQL indexes and straightforward filtering. Add search/ranking indexes only after observing real query patterns; do not optimize speculative queries prematurely.


## Phase 11 implementation — moderate sponsored ranking

- Public web search and Flutter customer discovery read currently active `boost_shop` campaigns from the database.
- Only active, verified businesses already matching the user's query are eligible to receive the sponsored signal.
- Base order preserves the existing open-first ordering; boosted matches are interleaved after up to three organic matches.
- This caps sponsored placement at one result per four result slots when enough organic results exist. Sponsored businesses never replace unrelated query matches.
- Sponsored results are explicitly labelled `SPONSORED`; organic results remain the default.
- Campaign time windows are checked at query time (`starts_at <= now < ends_at`).
- Partial indexes support active Boost Shop and Promote Offer discovery lookups.

### Scope boundary

Current business search only surfaces business cards. `promote_offer` campaign indexing is prepared, but promoted offer placement is not shown until discovery returns offer cards; we must not label an entire shop as sponsored merely because one of its offers is promoted.

### Acceptance checks

1. No active Boost Shop campaign → all matching results remain organic.
2. Active Boost Shop campaign → matching business receives a `SPONSORED` label.
3. Multiple boosted matches with organic matches available → no more than one sponsored item is inserted per four-slot group.
4. Expired or future campaigns do not influence ranking.
5. Sponsored campaigns do not add businesses that failed the original query or public-discovery eligibility filters.
6. Promote Offer is only used to rank an offer card, not a generic business card.
