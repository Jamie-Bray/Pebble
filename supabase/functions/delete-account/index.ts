import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json({ error: 'Supabase environment is not configured' }, 500);
  }

  const authorization = req.headers.get('authorization') ?? '';
  const jwt = authorization.replace(/^Bearer\s+/i, '').trim();
  if (!jwt) {
    return json({ error: 'Missing user authorization' }, 401);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(jwt);
  if (userError || !userData.user) {
    return json({ error: 'Invalid user authorization' }, 401);
  }

  const serviceClient = createClient(supabaseUrl, serviceRoleKey);
  const userId = userData.user.id;

  try {
    await deleteRoutineProofs(serviceClient, userId);

    const { error: deleteUserError } = await serviceClient.auth.admin.deleteUser(userId);
    if (deleteUserError) {
      return json({ error: deleteUserError.message }, 500);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown deletion failure';
    return json({ error: message }, 500);
  }

  return json({
    deletedUserId: userId,
    deletedCloudData: true,
  });
});

async function deleteRoutineProofs(
  serviceClient: ReturnType<typeof createClient>,
  userId: string,
) {
  const bucket = serviceClient.storage.from('routine-proofs');
  const prefix = `users/${userId}`;
  const objectKeys = await listAllObjects(bucket, prefix);

  if (objectKeys.length === 0) {
    return;
  }

  const { error } = await bucket.remove(objectKeys);
  if (error) {
    throw new Error(`Could not delete routine proof files: ${error.message}`);
  }
}

async function listAllObjects(
  bucket: ReturnType<ReturnType<typeof createClient>['storage']['from']>,
  path: string,
): Promise<string[]> {
  const objects: string[] = [];
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

    if (!data || data.length === 0) {
      break;
    }

    for (const entry of data) {
      if (!entry.name) {
        continue;
      }
      if (entry.id === null) {
        const childPath = `${path}/${entry.name}`;
        objects.push(...await listAllObjects(bucket, childPath));
        continue;
      }
      objects.push(`${path}/${entry.name}`);
    }

    if (data.length < 100) {
      break;
    }

    offset += data.length;
  }

  return objects;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'content-type': 'application/json',
    },
  });
}
