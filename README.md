# ABC-lek

A Swedish ABC learning game (installable PWA).

Live: https://a-sarmiento777.github.io/ABC/

Deployed automatically to GitHub Pages by `.github/workflows/pages.yml` on every push to `main`.

## Voices (ElevenLabs)

The app only uses the ElevenLabs clips in `voices/` (no device voice). Speed and pauses are set at the top of `tools/make-voices.mjs`.

To generate them:

1. Add the repository secret `ELEVENLABS_API_KEY` (Settings → Secrets and variables → Actions).
2. Actions → **Generate voices** → **Run workflow**. Optionally paste a voice ID.

It creates the clips, commits them to `voices/` and redeploys the site. Only new or changed phrases are generated; tick *Regenerate every clip* after changing the voice.

Locally: `ELEVENLABS_API_KEY=... ELEVENLABS_VOICE_ID=... node tools/make-voices.mjs`

If you add phrases to `index.html`, add them to the list in `tools/make-voices.mjs` too.

## Räkna och tryck

Count the animals and tap the right number (1–5, then 1–10 after 5 first-try answers in a row).
Its sound comes from `audio/numbers/1.mp3` … `10.mp3`; replace those files to change the voice.
A missing file just means no sound.
