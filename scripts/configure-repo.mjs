import { readFile, writeFile } from 'node:fs/promises';

const [owner, repo] = process.argv.slice(2);
if (!owner || !repo) {
  console.error('Usage: node scripts/configure-repo.mjs <owner> <repo>');
  process.exit(1);
}

const baseUrl = `https://${owner}.github.io/${repo}/`;
const imageUrl = `${baseUrl}og-image.png`;

const htmlPath = 'index.html';
let html = await readFile(htmlPath, 'utf8');

function upsertMeta(attr, key, value) {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const re = new RegExp(`<meta\\s+${attr}=["']${escaped}["']\\s+content=["'][^"']*["']\\s*\\/?>`, 'i');
  const tag = `<meta ${attr}="${key}" content="${value}" />`;
  if (re.test(html)) html = html.replace(re, tag);
  else html = html.replace('</head>', `  ${tag}\n</head>`);
}

const canonicalRe = /<link\s+rel=["']canonical["']\s+href=["'][^"']*["']\s*\/?>/i;
const canonicalTag = `<link rel="canonical" href="${baseUrl}" />`;
if (canonicalRe.test(html)) html = html.replace(canonicalRe, canonicalTag);
else html = html.replace('</head>', `  ${canonicalTag}\n</head>`);

upsertMeta('property', 'og:url', baseUrl);
upsertMeta('property', 'og:image', imageUrl);
upsertMeta('name', 'twitter:image', imageUrl);
await writeFile(htmlPath, html);

const sitemap = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n  <url><loc>${baseUrl}</loc></url>\n</urlset>\n`;
await writeFile('sitemap.xml', sitemap);
await writeFile('robots.txt', `User-agent: *\nAllow: /\nSitemap: ${baseUrl}sitemap.xml\n`);
console.log(`Configured public URL: ${baseUrl}`);
