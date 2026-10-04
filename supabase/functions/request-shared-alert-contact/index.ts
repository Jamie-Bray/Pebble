// Sender-side completion-email contacts. Logic: ./handler.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createContactHandler } from './handler.ts';
import { senderEntrypoint } from '../_shared/shared_alert_runtime.ts';

serve(senderEntrypoint(createContactHandler));
