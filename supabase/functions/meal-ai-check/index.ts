// Supabase Edge Function: Meal Snap fallback after 3 hours without an admin
// decision. Called by the app (the caller's own photos) and the admin page
// (every photo). Secrets: GEMINI_API_KEY (required), GEMINI_MODEL
// (optional). SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY
// are provided by Supabase. The key never reaches the app. Deploy this one
// file; it has no local imports.
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';
import { encodeBase64 } from 'jsr:@std/encoding@1.0.5/base64';

// --- gemini: start (tested by scripts/check-meal-ai.mts; keep free of Deno APIs) ---
// One file, so the function can be pasted into the Supabase dashboard as is.
// The answer is constrained to one word: YA or TIDAK.

export const prompt =
  'Apakah foto ini menunjukkan makanan atau minuman yang akan atau sedang ' +
  'dikonsumsi? Jawab hanya dengan satu kata: YA atau TIDAK.';

/** The generateContent body for one PNG photo, as base64. */
export function geminiRequest(photoBase64: string) {
  return {
    contents: [
      {
        role: 'user',
        parts: [
          { text: prompt },
          { inline_data: { mime_type: 'image/png', data: photoBase64 } },
        ],
      },
    ],
    generationConfig: {
      temperature: 0,
      // No maxOutputTokens: Gemini 3 spends tokens thinking first, and a tiny
      // cap returned an empty answer. Enum output keeps it to one word.
      responseMimeType: 'text/x.enum',
      responseSchema: { type: 'STRING', enum: ['YA', 'TIDAK'] },
    },
  };
}

/** 'approved' for YA, 'rejected' for TIDAK, null for anything else. */
export function readVerdict(response: unknown): 'approved' | 'rejected' | null {
  const text = (response as {
    candidates?: { content?: { parts?: { text?: string }[] } }[];
  })?.candidates?.[0]?.content?.parts
    ?.map((part) => part.text ?? '')
    .join('')
    .trim()
    .toUpperCase()
    .replace(/[^A-Z]/g, '');
  if (text === 'YA') return 'approved';
  if (text === 'TIDAK') return 'rejected';
  return null;
}
// --- gemini: end ---

const waitHours = 3;
const batch = 10;
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const apiKey = Deno.env.get('GEMINI_API_KEY');
  const model = Deno.env.get('GEMINI_MODEL') ?? 'gemini-3.8-flash';
  const url = Deno.env.get('SUPABASE_URL')!;
  const jwt = request.headers.get('Authorization') ?? '';
  if (!apiKey) return reply({ error: 'GEMINI_API_KEY is not set' }, 500);

  // Who is asking: a participant checks their own photos, an MFA admin all.
  const asCaller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: jwt } },
  });
  const { data: user } = await asCaller.auth.getUser();
  if (!user?.user) return reply({ error: 'Not signed in' }, 401);
  const { data: access } = await asCaller.rpc('youwell_admin_access');
  const admin = access === 'allowed';

  const service = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  let query = service
    .from('youwell_meal_checks')
    .select('id, image_path')
    .eq('status', 'pending')
    .not('image_path', 'is', null)
    .lt('created_at', new Date(Date.now() - waitHours * 3600e3).toISOString())
    .order('created_at')
    .limit(batch);
  if (!admin) query = query.eq('author', user.user.id);
  const { data: rows, error } = await query;
  if (error) return reply({ error: error.message }, 500);

  let decided = 0;
  for (const row of rows ?? []) {
    const file = await service.storage.from('meals').download(row.image_path);
    if (file.error || !file.data) continue;
    const photo = encodeBase64(new Uint8Array(await file.data.arrayBuffer()));
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
        body: JSON.stringify(geminiRequest(photo)),
      },
    );
    if (!response.ok) continue;
    const verdict = readVerdict(await response.json());
    // Anything but YA/TIDAK stays pending and is tried again later.
    if (!verdict) continue;
    const { error: updateError } = await service
      .from('youwell_meal_checks')
      .update({
        status: verdict,
        reviewer: 'ai',
        reviewed_at: new Date().toISOString(),
        image_path: null,
      })
      .eq('id', row.id)
      .eq('status', 'pending');
    if (updateError) continue;
    await service.storage.from('meals').remove([row.image_path]);
    decided++;
  }
  return reply({ checked: rows?.length ?? 0, decided });
});
