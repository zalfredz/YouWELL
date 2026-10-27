// node scripts/check-meal-ai.mts — checks the Gemini request and the YA/TIDAK parsing.
// The code lives in the Edge Function itself (one file for the dashboard), so
// its Deno-free block between the markers is extracted and imported here.
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const source = readFileSync(
  new URL('../supabase/functions/meal-ai-check/index.ts', import.meta.url),
  'utf8',
);
const block = source.match(/\/\/ --- gemini: start[^\n]*\n([\s\S]*?)\/\/ --- gemini: end/);
assert.ok(block, 'gemini block markers missing in index.ts');
const file = join(mkdtempSync(join(tmpdir(), 'meal-ai-')), 'gemini.mts');
writeFileSync(file, block[1]);
const { geminiRequest, readVerdict } = await import(file);

const body = geminiRequest('AAAA');
assert.equal(body.generationConfig.responseMimeType, 'text/x.enum');
assert.deepEqual(body.generationConfig.responseSchema.enum, ['YA', 'TIDAK']);
assert.equal(body.generationConfig.temperature, 0);
assert.equal(body.generationConfig.maxOutputTokens, undefined);
const reply = (text: string) => ({ candidates: [{ content: { parts: [{ text }] } }] });
assert.equal(readVerdict(reply('YA')), 'approved');
assert.equal(readVerdict(reply(' ya.\n')), 'approved');
assert.equal(readVerdict(reply('TIDAK')), 'rejected');
assert.equal(readVerdict(reply('Ya, ini makanan')), null);
assert.equal(readVerdict(reply('')), null);
assert.equal(readVerdict({}), null);
assert.ok(!/from '\.\//.test(source), 'index.ts must not import local files');
console.log('Gemini YA/TIDAK parsing passed.');
