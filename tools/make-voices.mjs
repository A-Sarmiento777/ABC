// Generates every phrase the app speaks with ElevenLabs and saves them in voices/.
// Usage: ELEVENLABS_API_KEY=... [ELEVENLABS_VOICE_ID=...] node tools/make-voices.mjs [--force]
// Already generated phrases are skipped unless --force is given.
import {readFileSync, writeFileSync, mkdirSync, existsSync} from 'node:fs';
import {createHash} from 'node:crypto';

const KEY = process.env.ELEVENLABS_API_KEY;
const VOICE = process.env.ELEVENLABS_VOICE_ID || 'EXAVITQu4vr4xnSDxMaL';
const MODEL = process.env.ELEVENLABS_MODEL || 'eleven_multilingual_v2';
const FORCE = process.argv.includes('--force');
if (!KEY) { console.error('Missing ELEVENLABS_API_KEY'); process.exit(1); }

// Read the word lists straight from index.html so the two never drift apart.
const html = readFileSync('index.html', 'utf8');
const grab = name => {
  const m = html.match(new RegExp(`const ${name}=(.*?);\\n`));
  if (!m) throw new Error(`${name} not found in index.html`);
  return Function(`return ${m[1]}`)();
};
const LETTERS = grab('LETTERS'), WORDS = grab('WORDS'), SOUND = grab('SOUND'),
  NUMW = grab('NUMW'), PRAISE = grab('PRAISE');

// Must match the strings passed to speak()/say() in index.html.
const phrases = new Set([
  'Hur många? Tryck på dem och räkna.',
  'Hej! A som i apa. Ett, två, tre.',
  ...PRAISE,
]);
for (const [ch, w] of LETTERS) {
  phrases.add(`${ch} som i ${w}.`);
  phrases.add(w);
  phrases.add(SOUND[ch] || ch);
  phrases.add(`Var är ${ch}? ${ch} som i ${w}.`);
  phrases.add(`Det där är ${ch}. Försök igen!`);
}
for (const [w] of WORDS) phrases.add(w.toLowerCase());
NUMW.forEach((n, i) => {
  phrases.add(n);
  phrases.add(`${n}!`);
  if (i) phrases.add(`${n}? Räkna en gång till!`);
});

mkdirSync('voices', {recursive: true});
const indexPath = 'voices/index.json';
const index = existsSync(indexPath) ? JSON.parse(readFileSync(indexPath, 'utf8')) : {};
let made = 0;
for (const text of phrases) {
  const file = createHash('sha1').update(`${VOICE}|${text}`).digest('hex').slice(0, 12) + '.mp3';
  if (!FORCE && index[text] === file && existsSync(`voices/${file}`)) continue;
  const res = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${VOICE}?output_format=mp3_44100_128`, {
    method: 'POST',
    headers: {'xi-api-key': KEY, 'Content-Type': 'application/json'},
    body: JSON.stringify({text, model_id: MODEL, language_code: 'sv',
      voice_settings: {stability: 0.6, similarity_boost: 0.8, speed: 0.9}}),
  });
  if (!res.ok) { console.error(`Failed "${text}": ${res.status} ${await res.text()}`); process.exit(1); }
  writeFileSync(`voices/${file}`, Buffer.from(await res.arrayBuffer()));
  index[text] = file;
  made++;
  console.log(`✓ ${text}`);
}
for (const t of Object.keys(index)) if (!phrases.has(t)) delete index[t];
writeFileSync(indexPath, JSON.stringify(index, null, 1) + '\n');
console.log(`${made} new clips, ${phrases.size} phrases total.`);
