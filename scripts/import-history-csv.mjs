import { readFile, writeFile } from 'node:fs/promises';
import { basename } from 'node:path';
const input=process.argv[2];
if(!input){console.error('Usage: node scripts/import-history-csv.mjs path/to/file.csv [output.json]');process.exit(1)}
const output=process.argv[3]||'data/history-imported.json';
const text=(await readFile(input,'utf8')).replace(/^\uFEFF/,'');
function parseCsv(s){const rows=[];let row=[],cell='',q=false;for(let i=0;i<s.length;i++){const c=s[i],n=s[i+1];if(c==='"'){if(q&&n==='"'){cell+='"';i++}else q=!q}else if(c===','&&!q){row.push(cell);cell=''}else if((c==='\n'||c==='\r')&&!q){if(c==='\r'&&n==='\n')i++;row.push(cell);cell='';if(row.some(v=>v.trim()))rows.push(row);row=[]}else cell+=c}if(cell||row.length){row.push(cell);rows.push(row)}return rows}
const rows=parseCsv(text);const headers=rows.shift().map(h=>h.trim());
const required=['id','title','year','place','lat','lon','category'];
for(const key of required)if(!headers.includes(key))throw new Error(`Missing required column: ${key}`);
const records=rows.map((r,i)=>Object.fromEntries(headers.map((h,j)=>[h,(r[j]??'').trim()]))).map((x,i)=>{
  const year=Number(x.year),lat=Number(x.lat),lon=Number(x.lon);
  if(!Number.isFinite(year)||!Number.isFinite(lat)||!Number.isFinite(lon))throw new Error(`Invalid numeric field at row ${i+2}`);
  if(lat < -90 || lat > 90 || lon < -180 || lon > 180)throw new Error(`Invalid coordinates at row ${i+2}`);
  return {id:x.id,title:x.title,year,place:x.place,country:x.country||'',region:x.region||'',lat,lon,category:x.category,
    summary:x.summary||'사용자가 가져온 역사 기록입니다.',significance:x.significance||'원문 출처와 동시대 기록을 함께 확인하세요.',
    people:[],relatedPlaces:[x.place],keyPoints:[x.summary||x.title,'같은 시기의 주변 사건과 비교해 보세요.'],
    wikiQuery:x.wikiQuery||x.title,wikiQueryEn:x.wikiQueryEn||x.wikiQuery||x.title,sourceUrl:x.sourceUrl||'',
    sourceTier:'imported',coordinatePrecision:x.coordinatePrecision||'unknown',reviewStatus:'needs-review',recordType:'event'}
});
await writeFile(output,JSON.stringify(records,null,2)+'\n','utf8');
console.log(`Imported ${records.length} records from ${basename(input)} -> ${output}`);
