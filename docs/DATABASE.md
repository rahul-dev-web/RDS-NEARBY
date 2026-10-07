# RDS Nearby — Database Baseline

Core tables:
profiles
categories
businesses
business_products
business_services
offers
saved_businesses
referrals
referral_events
merchant_wallets
merchant_credit_ledger
customer_wallets
customer_points_ledger
campaigns
customer_requests
request_responses
redemptions
memberships
fraud_flags
audit_logs
notification_preferences
device_tokens
notifications
analytics_events

All public tables have RLS enabled. Public discovery policies expose only active/verified business data. Owner policies isolate merchant resources. Wallet and ledger writes are reserved for backend workflows.
