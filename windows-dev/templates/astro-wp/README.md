# __NAME__

Astro frontend for the WordPress site at `http://__NAME__-cms.test`.

- Write content: http://__NAME__-cms.test/wp-admin (admin / admin)
- Run the site: `npm run dev` → http://localhost:4321 (refresh to see new WordPress content)
- Build static HTML: `npm run build` → `dist/` (upload that folder to Netlify, Cloudflare Pages or GitHub Pages)

Code: `src/lib/wp.js` talks to WordPress, `src/layouts/Layout.astro` is the page frame and styles,
`src/pages/index.astro` lists posts, `src/pages/[slug].astro` shows one post or page.
