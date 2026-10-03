import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { secretsMatch } from '../_shared/secrets.ts';
import {
  isGuidanceAudioKey,
  planCleanup,
  retentionDays,
  type StorageObject,
  type UsageRow,
} from './plan.ts';

const bucketName = 'routine-proofs';
const pageSize = 1000;

// deno-lint-ignore no-explicit-any
type SupabaseClient = any;
// deno-lint-ignore no-explicit-any
type StorageBucket = any;

export async function handler(req: Request): Promise<Response> {
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  // Fail closed: this endpoint has verify_jwt = false and deletes storage, so
  // it must never run without its scheduler secret configured.
  const schedulerSecret = Deno.env.get('CLEANUP_PROOF_RETENTION_SECRET')?.trim();
  if (!schedulerSecret) {
    console.error(JSON.stringify({
      scope: 'cleanup-proof-retention',
      message: 'refused_secret_not_configured',
    }));
    return json({ error: 'Cleanup is not configured' }, 503);
  }
  const provided = req.headers.get('x-cleanup-secret');
  if (!(await secretsMatch(provided, schedulerSecret))) {
    return json({ error: 'Unauthorized' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: 'Supabase environment is not configured' }, 500);
  }

  const client = createClient(supabaseUrl, serviceRoleKey);

  try {
    const usageRows = await fetchAllUsageRows(client);
    const storageObjects = await listAllObjects(client.storage.from(bucketName), 'users');
    const plan = planCleanup(usageRows, storageObjects);

    await removeStorageObjects(client, plan.keysToRemove);
    await deleteUsageRows(client, plan.metadataIdsToDelete);

    return json({
      retentionDays,
      deletedStorageObjects: plan.keysToRemove.length,
      deletedProofMetadataRows: plan.metadataIdsToDelete.length,
      orphanStorageObjectsDeleted: plan.orphanStorageObjects,
      missingStorageMetadataRowsDeleted: plan.missingStorageRows,
      skippedGuidanceAudio: plan.skippedGuidanceAudio,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown cleanup failure';
    return json({ error: message }, 500);
  }
}

async function fetchAllUsageRows(client: SupabaseClient): Promise<UsageRow[]> {
  const rows: UsageRow[] = [];
  let from = 0;

  while (true) {
    const to = from + pageSize - 1;
    const { data, error } = await client
      .from('proof_asset_usage')
      .select('id, object_key, entity_type, created_at, expires_at, deleted_at')
      .order('id', { ascending: true })
      .range(from, to);

    if (error) {
      throw new Error(`Could not fetch proof metadata: ${error.message}`);
    }

    rows.push(...((data ?? []) as UsageRow[]));
    if (!data || data.length < pageSize) break;
    from += pageSize;
  }

  return rows;
}

async function listAllObjects(
  bucket: StorageBucket,
  path: string,
): Promise<StorageObject[]> {
  const objects: StorageObject[] = [];
  let offset = 0;

  while (true) {
    const { data, error } = await bucket.list(path, {
      limit: 100,
      offset,
      sortBy: { column: 'name', order: 'asc' },
    });

    if (error) {
      throw new Error(`Could not list routine proof files: ${error.message}`);
    }

    if (!data || data.length === 0) break;

    for (const entry of data) {
      if (!entry.name) continue;
      const childPath = `${path}/${entry.name}`;
      if (entry.id === null) {
        // Never descend into voice-prompt folders (users/<uid>/guidance_audio).
        if (isGuidanceAudioKey(`${childPath}/x`)) continue;
        objects.push(...await listAllObjects(bucket, childPath));
        continue;
      }
      objects.push({
        key: childPath,
        createdAt: entry.created_at ?? null,
        updatedAt: entry.updated_at ?? null,
      });
    }

    if (data.length < 100) break;
    offset += data.length;
  }

  return objects;
}

async function removeStorageObjects(client: SupabaseClient, objectKeys: string[]) {
  const bucket = client.storage.from(bucketName);
  for (const chunk of chunks(objectKeys, 100)) {
    if (chunk.length === 0) continue;
    const { error } = await bucket.remove(chunk);
    if (error) {
      throw new Error(`Could not delete proof storage objects: ${error.message}`);
    }
  }
}

async function deleteUsageRows(client: SupabaseClient, ids: string[]) {
  for (const chunk of chunks(ids, 100)) {
    if (chunk.length === 0) continue;
    const { error } = await client
      .from('proof_asset_usage')
      .delete()
      .in('id', chunk)
      // Belt and braces: never delete voice-prompt metadata from this job.
      .or('entity_type.is.null,entity_type.neq.guidance_audio');
    if (error) {
      throw new Error(`Could not delete proof metadata rows: ${error.message}`);
    }
  }
}

function chunks<T>(values: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let index = 0; index < values.length; index += size) {
    result.push(values.slice(index, index + size));
  }
  return result;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

if (import.meta.main) {
  serve(handler);
}
