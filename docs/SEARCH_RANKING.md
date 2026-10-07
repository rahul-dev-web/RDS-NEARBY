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
