-- Lapsed-premium fix: proof_asset_usage_update_with_entitlement required an
-- active entitlement for every UPDATE, so users who lost premium could not
-- soft-delete their own usage rows. History pruning runs that soft-delete
-- inside the watchRuns stream, so the RLS denial (42501) surfaced as
-- "Could not load history" and permanently broke the History screen for
-- lapsed users. Owners may now always mark their own rows deleted; every
-- other update still requires an active entitlement.
alter policy proof_asset_usage_update_with_entitlement on public.proof_asset_usage
  to authenticated
  using ((select auth.uid()) = owner_user_id)
  with check (((select auth.uid()) = owner_user_id)
    and (public.has_personal_cloud_write_access((select auth.uid()))
      or deleted_at is not null));
