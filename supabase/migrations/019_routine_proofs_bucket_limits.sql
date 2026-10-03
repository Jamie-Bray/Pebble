-- Per-object limits for the private routine-proofs bucket (both were null).
--
-- What the app uploads (lib/features/routines/execution/data/services/
-- routine_session_proof_storage.dart and the step voice-prompt backup):
--   * proof photos, always re-encoded on device to WebP (quality 70), falling
--     back to JPEG (quality 72) when WebP encoding fails. image/png is kept for
--     proofs stored by older builds (the content-type map still emits it).
--   * step voice prompts under users/<uid>/guidance_audio/: WAV, mono,
--     44.1 kHz, at most 10 s, so roughly 0.9 MB. Some platforms label WAV as
--     audio/x-wav, so both spellings are allowed.
--
-- file_size_limit is per object and applies to every type in the bucket.
-- 5 MB is well above a re-encoded photo (typically < 1 MB) or a 10 s clip and
-- far below the 1 GB per-user quota enforced by guard_proof_asset_usage_quota.
-- Existing objects are not affected; limits apply to new uploads only.

update storage.buckets
set file_size_limit = 5242880,
    allowed_mime_types = array[
      'image/webp',
      'image/jpeg',
      'image/png',
      'audio/wav',
      'audio/x-wav'
    ]
where id = 'routine-proofs';
