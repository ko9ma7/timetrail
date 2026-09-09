import { readFile, writeFile, mkdir } from 'node:fs/promises';

const config = JSON.parse(await readFile(new URL('../data/harvest-config.json', import.meta.url), 'utf8'));
const endpoint = process.env.WIKIDATA_ENDPOINT || config.endpoint;
const maxRecords = Number(process.env.MAX_HISTORY_RECORDS || config.maxRecords || 45000);
const pageSize = Math.min(1000, Number(process.env.HISTORY_PAGE_SIZE || config.pageSize || 500));
const outPath = new URL('../data/history-events-index.json', import.meta.url);
const metaPath = new URL('../data/history-events-index.meta.json', import.meta.url);
const userAgent = process.env.WIKIDATA_USER_AGENT || 'TimeTrail/1.2 (GitHub Pages educational historical map; contact via repository issues)';

const sleep = ms => new Promise(r => setTimeout(r, ms));
const yearFromDate = value => {
  if (!value) return null;
  const m = String(value).match(/^([+-]?\d{1,6})-/);
  if (!m) return null;
  return Number(m[1]);
};
const point = value => {
  const m = String(value || '').match(/Point\(([-\d.]+) ([-\d.]+)\)/);
  return m ? { lon: Number(m[1]), lat: Number(m[2]) } : null;
};
const qidFromUri = uri => String(uri || '').split('/').pop();
const normalize = (b, spec) => {
  const p = point(b.coord?.value);
  const year = yearFromDate(b.date?.value || b.inception?.value);
  if (!p || !Number.isFinite(year) || year < -10000 || year > 2100) return null;
  const qid = qidFromUri(b.item?.value);
  const title = b.itemLabel?.value || qid;
  const place = b.placeLabel?.value || b.countryLabel?.value || title;
  const description = b.itemDescription?.value || `${spec.label} · Wikidata structured record`;
  return {
    id: `wd-${qid}`,
    title,
    year,
    place,
    country: b.countryLabel?.value || '',
    region: '',
    lat: p.lat,
    lon: p.lon,
    category: spec.category,
    recordType: spec.recordType,
    summary: description,
    significance: 'Wikidata 구조화 데이터에서 자동 수집한 항목입니다. 상세 학습 내용은 연결된 Wikipedia/Wikidata 원문에서 확인하세요.',
    people: [],
    relatedPlaces: [place].filter(Boolean),
    keyPoints: [description, `Wikidata 항목: ${qid}`, '좌표와 연도를 기준으로 같은 시기·주변 지역의 다른 기록과 비교해 보세요.'],
    wikiQuery: title,
    wikiQueryEn: title,
    wikidataId: qid,
    wikipediaUrl: b.article?.value || '',
    sourceUrl: b.item?.value || `https://www.wikidata.org/wiki/${qid}`,
    sourceTier: 'wikidata-index',
    coordinatePrecision: spec.recordType === 'place' ? 'site' : 'unknown',
    reviewStatus: 'machine-imported'
  };
};

function buildQuery(spec, limit, offset) {
  return `SELECT ?item ?itemLabel ?itemDescription ?coord ?date ?inception ?countryLabel ?placeLabel ?article WHERE {
    ?item wdt:P31 wd:${spec.qid}; wdt:P625 ?coord.
    OPTIONAL { ?item wdt:P585 ?date. }
    OPTIONAL { ?item wdt:P571 ?inception. }
    FILTER(BOUND(?date) || BOUND(?inception))
    OPTIONAL { ?item wdt:P17 ?country. }
    OPTIONAL { ?item wdt:P276 ?place. }
    OPTIONAL { ?article schema:about ?item; schema:isPartOf <https://en.wikipedia.org/>. }
    SERVICE wikibase:label { bd:serviceParam wikibase:language "ko,en". }
  } LIMIT ${limit} OFFSET ${offset}`;
}

async function requestSparql(query, attempt = 1) {
  const url = `${endpoint}?format=json&query=${encodeURIComponent(query)}`;
  const res = await fetch(url, { headers: { 'accept': 'application/sparql-results+json', 'user-agent': userAgent } });
  if ((res.status === 429 || res.status >= 500) && attempt <= 5) {
    const wait = Math.min(60000, 1500 * (2 ** (attempt - 1)));
    console.warn(`[retry] HTTP ${res.status}; waiting ${wait}ms`);
    await sleep(wait);
    return requestSparql(query, attempt + 1);
  }
  if (!res.ok) throw new Error(`WDQS HTTP ${res.status}: ${await res.text().catch(()=>'')}`);
  return res.json();
}

const all = new Map();
const stats = [];
for (const spec of config.queries) {
  let count = 0;
  const typeLimit = Math.min(spec.limit || maxRecords, maxRecords);
  console.log(`\n[harvest] ${spec.label} (${spec.qid})`);
  for (let offset = 0; offset < typeLimit && all.size < maxRecords; offset += pageSize) {
    const take = Math.min(pageSize, typeLimit - offset, maxRecords - all.size);
    let data;
    try {
      data = await requestSparql(buildQuery(spec, take, offset));
    } catch (error) {
      console.warn(`[skip] ${spec.label} page offset=${offset}: ${error.message}`);
      break;
    }
    const rows = data?.results?.bindings || [];
    for (const row of rows) {
      const record = normalize(row, spec);
      if (record) all.set(record.id, record);
    }
    count += rows.length;
    console.log(`[page] ${spec.label}: raw=${count}, unique-total=${all.size}`);
    if (rows.length < take) break;
    await sleep(350);
  }
  stats.push({ qid: spec.qid, label: spec.label, rawRows: count });
}

const records = [...all.values()].sort((a,b)=>a.year-b.year || a.title.localeCompare(b.title));
await mkdir(new URL('../data/', import.meta.url), { recursive: true });
await writeFile(outPath, JSON.stringify(records, null, 2) + '\n', 'utf8');
await writeFile(metaPath, JSON.stringify({
  generatedAt: new Date().toISOString(), endpoint, maxRecords, recordCount: records.length, stats,
  note: 'Machine-generated from Wikidata Query Service. Review individual records through sourceUrl/wikidataId before high-stakes use.'
}, null, 2) + '\n', 'utf8');
console.log(`\n[done] wrote ${records.length} records to data/history-events-index.json`);
