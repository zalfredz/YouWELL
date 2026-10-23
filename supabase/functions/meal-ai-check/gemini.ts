// Gemini call for the Meal Snap fallback, kept free of Deno APIs so it can be
// tested with Node. The answer is constrained to one word: YA or TIDAK.

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
