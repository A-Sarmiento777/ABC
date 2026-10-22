// Tiny client for the WordPress REST API (http://<site>/wp-json/wp/v2/...).
const WP_URL = (import.meta.env.WP_URL || '').replace(/\/$/, '');

async function get(path) {
  if (!WP_URL) throw new Error('WP_URL is not set. Add it to .env');
  const res = await fetch(`${WP_URL}/wp-json/${path}`);
  if (!res.ok) throw new Error(`WordPress answered ${res.status} for /wp-json/${path}`);
  return res.json();
}

export const getSite  = () => get('');                                   // name, description
export const getPosts = () => get('wp/v2/posts?per_page=100&_embed=wp:featuredmedia');
export const getPages = () => get('wp/v2/pages?per_page=100&orderby=menu_order&order=asc');

// Strip tags and decode the few entities WordPress puts in titles, for <title>.
export const plain = (html = '') =>
  html.replace(/<[^>]+>/g, '')
      .replace(/&#8217;|&rsquo;/g, '’').replace(/&#8211;/g, '–').replace(/&amp;/g, '&')
      .replace(/&quot;|&#8220;|&#8221;/g, '"');
