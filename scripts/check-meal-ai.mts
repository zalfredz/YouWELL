// node scripts/check-meal-ai.mts — checks the Gemini request and the YA/TIDAK parsing.
import assert from 'node:assert/strict';
import { geminiRequest, readVerdict } from '../supabase/functions/meal-ai-check/gemini.ts';

const body = geminiRequest('AAAA');
assert.equal(body.generationConfig.responseMimeType, 'text/x.enum');
assert.deepEqual(body.generationConfig.responseSchema.enum, ['YA', 'TIDAK']);
assert.equal(body.generationConfig.temperature, 0);
const reply = (text: string) => ({ candidates: [{ content: { parts: [{ text }] } }] });
assert.equal(readVerdict(reply('YA')), 'approved');
assert.equal(readVerdict(reply(' ya.\n')), 'approved');
assert.equal(readVerdict(reply('TIDAK')), 'rejected');
assert.equal(readVerdict(reply('Ya, ini makanan')), null);
assert.equal(readVerdict(reply('')), null);
assert.equal(readVerdict({}), null);
console.log('Gemini YA/TIDAK parsing passed.');
