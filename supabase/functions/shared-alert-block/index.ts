// Completion-email "Block this sender" link (also the invitation's RFC 8058
// one-click unsubscribe target). Logic: ../_shared/shared_alert_links.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createLinkHandler } from '../_shared/shared_alert_links.ts';
import { linkEntrypoint } from '../_shared/shared_alert_runtime.ts';

serve(linkEntrypoint((deps) => createLinkHandler('block', deps)));
