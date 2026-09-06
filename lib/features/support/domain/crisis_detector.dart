/// Keyword-based preview signal, not a clinical risk assessment.
bool crisisSignal(String text) => RegExp(
  r'bunuh\s*diri|mengakhiri\s*hidup|akhiri\s*hidup|ingin\s*mati|mau\s*mati|menyakiti\s*diri|self.?harm|kill\s*myself|suicid',
  caseSensitive: false,
).hasMatch(text);
