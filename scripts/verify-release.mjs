import { readFile } from 'node:fs/promises';

const html = await readFile('index.html', 'utf8');
const app = await readFile('app.js', 'utf8');
const pkg = JSON.parse(await readFile('package.json', 'utf8'));

const build = html.match(/<meta\s+name=["']timetrail-build["']\s+content=["']([^"']+)["']/i)?.[1];
if (!build) throw new Error('Missing <meta name="timetrail-build"> in index.html');

const appBuild = app.match(/const\s+DATA_VERSION\s*=\s*["']([^"']+)["']/)?.[1];
if (!appBuild) throw new Error('Missing DATA_VERSION in app.js');
if (appBuild !== build) throw new Error(`Build mismatch: index.html=${build}, app.js=${appBuild}`);

const cssVersion = html.match(/styles\.css\?v=([^"']+)/)?.[1];
const jsVersion = html.match(/app\.js\?v=([^"']+)/)?.[1];
if (cssVersion !== build) throw new Error(`CSS cache version mismatch: expected ${build}, got ${cssVersion}`);
if (jsVersion !== build) throw new Error(`JS cache version mismatch: expected ${build}, got ${jsVersion}`);

console.log(`Release consistency OK: v${pkg.version} / build ${build}`);
