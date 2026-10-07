# RDS Nearby — Roles & Access

## Roles
- customer: discover local businesses, save shops, create Customer Requests, earn/redeem Local Points.
- merchant: own one or more businesses, manage public business data, products/services/offers, referrals, requests and Marketing Credits according to membership/eligibility.
- admin: moderation, fraud review, business verification, reward corrections and audited operational controls.

## Authorization rules
Role is server-controlled. Flutter must not elevate itself from customer to merchant/admin.
Business ownership is enforced by RLS and server-side workflows.
Wallet, ledger, referral qualification, reward, campaign spend, redemption and privileged moderation operations are backend-controlled.

## Public access
Only active + verified business discovery data and valid public offers are exposed publicly. Private customer information and merchant-owned operational data remain protected.
