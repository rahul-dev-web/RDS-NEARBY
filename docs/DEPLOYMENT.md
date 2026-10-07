# Deployment

## Environments

development
staging
production

## Mobile

Flutter uses public Supabase URL + publishable key only.

Never ship:
- service_role key
- secret key
- database password

## Supabase

Deploy database migrations in order.

Verify after every security-sensitive migration:
- Security Advisor
- relevant RLS policies
- foreign keys
- indexes
- Data API exposure/grants for tables that the client must access

## Edge Functions

JWT verification remains enabled for authenticated business workflows.

Critical functions must validate identity and authorization server-side.

## Web

Next.js handles:
- public shop pages
- referral landing pages
- SEO
- deep-link fallback

## Release checklist

- production secrets separated
- migrations verified
- RLS verified
- Edge Functions active
- deep links tested
- push delivery tested
- crash/error logging active
- privacy policy and terms available
