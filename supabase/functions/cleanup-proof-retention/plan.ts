// Pure retention planning for cleanup-proof-retention (no remote imports, so
// it can be unit tested offline).

export const retentionDays = 21;

/** Entity type of step voice-prompt backups (kept for the life of the routine). */
export const guidanceAudioEntityType = 'guidance_audio';

export type UsageRow = {
  id: string;
  object_key: string;
  entity_type: string | null;
  created_at: string;
  expires_at: string;
  deleted_at: string | null;
};

export type StorageObject = {
  key: string;
  createdAt: string | null;
  updatedAt: string | null;
};

export type CleanupPlan = {
  keysToRemove: string[];
  metadataIdsToDelete: string[];
  orphanStorageObjects: number;
  missingStorageRows: number;
  skippedGuidanceAudio: number;
};

/**
 * Voice-prompt clips live in the same bucket under
 * `users/<uid>/guidance_audio/<file>`. They are not proof photos and must never
 * be swept by the 21-day proof retention, so both the object key and the
 * metadata row type are checked.
 */
export function isGuidanceAudioKey(key: string): boolean {
  const parts = key.split('/');
  return parts.length >= 4 && parts[0] === 'users' &&
    parts[2] === guidanceAudioEntityType;
}

export function isGuidanceAudioRow(row: UsageRow): boolean {
  return row.entity_type === guidanceAudioEntityType ||
    isGuidanceAudioKey(row.object_key);
}

export function planCleanup(
  usageRows: UsageRow[],
  storageObjects: StorageObject[],
  nowMs = Date.now(),
): CleanupPlan {
  const cutoff = new Date(nowMs - retentionDays * 24 * 60 * 60 * 1000);
  const now = new Date(nowMs);

  const guidanceRows = usageRows.filter(isGuidanceAudioRow);
  const guidanceKeys = new Set(guidanceRows.map((row) => row.object_key));
  const proofRows = usageRows.filter((row) => !isGuidanceAudioRow(row));
  const proofObjects = storageObjects.filter((object) =>
    !isGuidanceAudioKey(object.key) && !guidanceKeys.has(object.key)
  );
  const skippedGuidanceAudio = guidanceRows.length +
    (storageObjects.length - proofObjects.length);

  const storageKeys = new Set(storageObjects.map((object) => object.key));
  const usageKeys = new Set(usageRows.map((row) => row.object_key));

  const expiredUsageRows = proofRows.filter((row) => {
    if (row.deleted_at) return true;
    return new Date(row.expires_at) <= now || new Date(row.created_at) <= cutoff;
  });
  const missingStorageRows = proofRows.filter((row) =>
    !storageKeys.has(row.object_key)
  );
  const orphanStorageObjects = proofObjects.filter((object) => {
    if (usageKeys.has(object.key)) return false;
    const timestamp = object.updatedAt ?? object.createdAt;
    if (!timestamp) return false;
    return new Date(timestamp) <= cutoff;
  });

  return {
    keysToRemove: unique([
      ...expiredUsageRows.map((row) => row.object_key),
      ...orphanStorageObjects.map((object) => object.key),
    ]).filter((key) => !isGuidanceAudioKey(key) && !guidanceKeys.has(key)),
    metadataIdsToDelete: unique([
      ...expiredUsageRows.map((row) => row.id),
      ...missingStorageRows.map((row) => row.id),
    ]),
    orphanStorageObjects: orphanStorageObjects.length,
    missingStorageRows: missingStorageRows.length,
    skippedGuidanceAudio,
  };
}

function unique(values: string[]): string[] {
  return [...new Set(values.filter((value) => value.length > 0))];
}
