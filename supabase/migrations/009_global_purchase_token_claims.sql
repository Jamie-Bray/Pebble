-- A currently active store purchase token must only unlock one Pebble account.
-- Expired rows are left claimable so RevenueCat transfer events can expire the
-- old owner before the new owner receives the entitlement.

create unique index if not exists personal_entitlements_unique_active_store_purchase
  on public.personal_entitlements(store, product_id, purchase_token_hash)
  where status in ('active', 'grace', 'cancelled_active');
