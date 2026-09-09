import { cp, mkdir, rm, writeFile } from 'node:fs/promises';

const files = [
  'index.html', 'app.js', 'styles.css',
  'favicon.ico', 'favicon.svg', 'favicon-16x16.png', 'favicon-32x32.png',
  'apple-touch-icon.png', 'icon-192.png', 'icon-512.png',
  'og-image.svg', 'og-image.png',
  'manifest.webmanifest', 'site.webmanifest',
  'robots.txt', 'sitemap.xml', '404.html', '.nojekyll'
];

await rm('dist', { recursive: true, force: true });
await mkdir('dist', { recursive: true });
for (const file of files) await cp(file, `dist/${file}`);
await writeFile('dist/.nojekyll', '');
console.log(`Built ${files.length} static files into dist/`);
