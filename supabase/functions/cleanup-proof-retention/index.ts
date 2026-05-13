import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const bucketName = 'routine-proofs';
const retentionDays = 21;
const pageSize = 1000;

type SupabaseClient = ReturnType<typeof createClient>;
type StorageBucket = ReturnType<ReturnType<typeof createClient>['storage']['from']>;

type UsageRow = {
  id: string;
  object_key: string;
  created_at: string;
  expires_at: string;
  deleted_at: string | null;
};

type StorageObject = {
  key: string;
  createdAt: string | null;
  updatedAt: string | null;
};

serve(async (req) => {
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const schedulerSecret = Deno.env.get('CLEANUP_PROOF_RETENTION_SECRET');
  if (schedulerSecret) {
    const provided = req.headers.get('x-cleanup-secret') ?? '';
    if (provided !== schedulerSecret) {
      return json({ error: 'Unauthorized' }, 401);
    }
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: 'Supabase environment is not configured' }, 500);
  }

  const client = createClient(supabaseUrl, serviceRoleKey);
  const cutoff = new Date(Date.now() - retentionDays * 24 * 60 * 60 * 1000);

  try {
    const usageRows = await fetchAllUsageRows(client);
    const storageObjects = await listAllObjects(client.storage.from(bucketName), 'users');
    const storageKeys = new Set(storageObjects.map((object) => object.key));
    const usageByKey = new Map(usageRows.map((row) => [row.object_key, row]));

    const expiredUsageRows = usageRows.filter((row) => isExpiredUsage(row, cutoff));
    const missingStorageRows = usageRows.filter((row) => !storageKeys.has(row.object_key));
    const orphanStorageObjects = storageObjects.filter((object) => {
      if (usageByKey.has(object.key)) return false;
      return objectIsOlderThan(object, cutoff);
    });

    const keysToRemove = unique([
      ...expiredUsageRows.map((row) => row.object_key),
      ...orphanStorageObjects.map((object) => object.key),
    ]);
    await removeStorageObjects(client, keysToRemove);

    const metadataIdsToDelete = unique([
      ...expiredUsageRows.map((row) => row.id),
      ...missingStorageRows.map((row) => row.id),
    ]);
    await deleteUsageRows(client, metadataIdsToDelete);

    return json({
      retentionDays,
      deletedStorageObjects: keysToRemove.length,
      deletedProofMetadataRows: metadataIdsToDelete.length,
      orphanStorageObjectsDeleted: orphanStorageObjects.length,
      missingStorageMetadataRowsDeleted: missingStorageRows.length,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown cleanup failure';
    return json({ error: message }, 500);
  }
});

async function fetchAllUsageRows(client: SupabaseClient): Promise<UsageRow[]> {
  const rows: UsageRow[] = [];
  let from = 0;

  while (true) {
    const to = from + pageSize - 1;
    const { data, error } = await client
      .from('proof_asset_usage')
      .select('id, object_key, created_at, expires_at, deleted_at')
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

function isExpiredUsage(row: UsageRow, cutoff: Date): boolean {
  if (row.deleted_at) return true;
  const expiresAt = new Date(row.expires_at);
  const createdAt = new Date(row.created_at);
  return expiresAt <= new Date() || createdAt <= cutoff;
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

function objectIsOlderThan(object: StorageObject, cutoff: Date): boolean {
  const timestamp = object.updatedAt ?? object.createdAt;
  if (!timestamp) return false;
  return new Date(timestamp) <= cutoff;
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
    const { error } = await client.from('proof_asset_usage').delete().in('id', chunk);
    if (error) {
      throw new Error(`Could not delete proof metadata rows: ${error.message}`);
    }
  }
}

function unique(values: string[]): string[] {
  return [...new Set(values.filter((value) => value.length > 0))];
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
