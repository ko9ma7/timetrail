import * as maplibregl from 'https://unpkg.com/maplibre-gl@6.8.0/dist/maplibre-gl.mjs';

const DATA_VERSION='2026-09-10.2';
const labels={politics:'정치',war:'전쟁',culture:'문화',architecture:'건축',exploration:'탐험',science:'과학',technology:'기술',economy:'경제',religion:'종교',society:'사회'};
const sourceTierLabels={curated:'교육 큐레이션','editorial-backbone':'세계사 Backbone','wikidata-index':'Wikidata 자동 인덱스',imported:'사용자 가져오기'};
const normalizeRecord=(e,sourceTier='curated')=>({
  id:e.id||`record-${Math.random().toString(36).slice(2)}`, title:e.title||'제목 미상', year:Number(e.year)||0,
  place:e.place||e.country||'위치 미상', country:e.country||'', region:e.region||'', lat:Number(e.lat), lon:Number(e.lon),
  category:e.category||'society', summary:e.summary||e.description||'구조화된 역사 기록입니다.',
  significance:e.significance||'같은 시대의 주변 기록과 연결해 역사적 맥락을 비교해 보세요.',
  people:Array.isArray(e.people)?e.people:[], relatedPlaces:Array.isArray(e.relatedPlaces)?e.relatedPlaces:[e.place].filter(Boolean),
  keyPoints:Array.isArray(e.keyPoints)&&e.keyPoints.length?e.keyPoints:[e.summary||e.description||'원문 자료에서 자세한 내용을 확인하세요.','연도와 좌표를 이용해 주변의 동시대 기록과 비교할 수 있습니다.'],
  wikiQuery:e.wikiQuery||e.title||'', wikiQueryEn:e.wikiQueryEn||e.wikiQuery||e.title||'',
  wikidataId:e.wikidataId||'', wikipediaUrl:e.wikipediaUrl||'', sourceUrl:e.sourceUrl||'', recordType:e.recordType||'event',
  sourceTier:e.sourceTier||sourceTier, coordinatePrecision:e.coordinatePrecision||'unknown', reviewStatus:e.reviewStatus||'needs-review'
});
async function fetchOptionalJson(file,fallback=[]){
  try{const r=await fetch(`./data/${file}?v=${DATA_VERSION}`,{cache:'no-store'});if(!r.ok)return fallback;return await r.json()}catch{return fallback}
}
async function loadData(){
  try{
    const [curated,backbone,index,imported,routes,cities]=await Promise.all([
      fetchOptionalJson('history-events.json'),fetchOptionalJson('history-backbone.json'),fetchOptionalJson('history-events-index.json'),fetchOptionalJson('history-imported.json'),
      fetchOptionalJson('story-packs.json'),fetchOptionalJson('cities.json')
    ]);
    const byId=new Map();
    for(const e of curated) byId.set(e.id,normalizeRecord(e,'curated'));
    for(const e of backbone) if(!byId.has(e.id)) byId.set(e.id,normalizeRecord(e,'editorial-backbone'));
    for(const e of index) if(!byId.has(e.id)) byId.set(e.id,normalizeRecord(e,'wikidata-index'));
    for(const e of imported) byId.set(e.id,normalizeRecord(e,'imported'));
    const events=[...byId.values()].filter(e=>Number.isFinite(e.lat)&&Number.isFinite(e.lon)).sort((a,b)=>a.year-b.year);
    if(!events.length) throw new Error('No history records loaded');
    return {events,routes,cities,source:`json:${curated.length}+${backbone.length}+${index.length}+${imported.length}`,counts:{curated:curated.length,backbone:backbone.length,index:index.length,imported:imported.length}};
  }catch(error){
    console.warn('Fresh JSON data load failed; using bundled fallback.',error);
    const fallback=await import(`./data/history-data.js?v=${DATA_VERSION}`);
    return {events:fallback.events.map(e=>normalizeRecord(e,'curated')),routes:fallback.routes,cities:fallback.cities,source:'fallback',counts:{curated:fallback.events.length,backbone:0,index:0,imported:0}};
  }
}
const {events,routes,cities,source:dataSource,counts:dataCounts}=await loadData();

const $=s=>document.querySelector(s); const $$=s=>[...document.querySelectorAll(s)];
const initial=events.find(e=>e.id==='hansan-1592')||events.find(e=>e.year>=1400&&e.year<=1700)||events[Math.floor(events.length/2)]||events[0];
const state={mode:'explore',year:initial?.year??1592,selected:initial,route:null,routeStopIndex:0,search:'',duelA:'Seoul',duelB:'London',favorites:JSON.parse(localStorage.getItem('tt-favorites')||'[]'),markers:[]};
const wikiCache=new Map();
const fmt=y=>y<0?`기원전 ${Math.abs(y)}년`:`${y}년`; const safe=t=>String(t??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const enc=encodeURIComponent;
const dist=(a,b)=>Math.hypot((a.lat-b.lat)*1.2,a.lon-b.lon);
const lowerBound=year=>{let lo=0,hi=events.length;while(lo<hi){const m=(lo+hi)>>1;if(events[m].year<year)lo=m+1;else hi=m}return lo};
const yearWindow=(year,span=65)=>events.slice(lowerBound(year-span),lowerBound(year+span+1));
const nearest=(lat,lon,year)=>{let pool=yearWindow(year,120);if(!pool.length)pool=yearWindow(year,500);if(!pool.length)pool=events;let best=pool[0],score=Infinity;for(const e of pool){const s=Math.abs(e.year-year)/3+Math.hypot((e.lat-lat)*1.2,e.lon-lon);if(s<score){score=s;best=e}}return best};
const visible=()=>{const q=state.search.toLowerCase().trim();const pool=q?events:yearWindow(state.year,65);const base=pool.length?pool:(q?events:yearWindow(state.year,500));return base.filter(e=>!q||`${e.title} ${e.place} ${e.country} ${e.region} ${e.people.join(' ')} ${e.summary} ${e.significance}`.toLowerCase().includes(q)).sort((a,b)=>Math.abs(a.year-state.year)-Math.abs(b.year-state.year));};
const showToast=text=>{const t=$('#toast');t.querySelector('span').textContent=text;t.hidden=false;clearTimeout(showToast.timer);showToast.timer=setTimeout(()=>t.hidden=true,2300)};
const sourceLinks=e=>[
  ...(e.wikipediaUrl?[['연결된 Wikipedia 원문',e.wikipediaUrl]]:[]),
  ...(e.sourceUrl?[['구조화 원본 / 출처',e.sourceUrl]]:[]),
  ['한국어 Wikipedia',`https://ko.wikipedia.org/w/index.php?search=${enc(e.wikiQuery||e.title)}`],
  ['English Wikipedia',`https://en.wikipedia.org/w/index.php?search=${enc(e.wikiQueryEn||e.wikiQuery||e.title)}`],
  ['Wikidata',e.wikidataId?`https://www.wikidata.org/wiki/${enc(e.wikidataId)}`:`https://www.wikidata.org/w/index.php?search=${enc(e.wikiQueryEn||e.title)}`],
  ['나무위키 검색',`https://namu.wiki/Search?q=${enc(e.wikiQuery||e.title)}`],
  ['Wikimedia Commons 이미지',`https://commons.wikimedia.org/w/index.php?search=${enc(e.wikiQueryEn||e.title)}&title=Special:MediaSearch&type=image`]
];

async function fetchWiki(query,lang='ko'){
  const key=`${lang}:${query}`; if(wikiCache.has(key)) return wikiCache.get(key);
  const url=`https://${lang}.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=${enc(query)}&gsrlimit=1&prop=pageimages%7Cextracts%7Cinfo&inprop=url&exintro=1&explaintext=1&piprop=thumbnail&pithumbsize=900&format=json&origin=*`;
  try{const r=await fetch(url); if(!r.ok)throw new Error(r.status); const j=await r.json(); const p=Object.values(j.query?.pages||{})[0]; if(!p)return null; const data={title:p.title,extract:p.extract||'',image:p.thumbnail?.source||'',url:p.fullurl||`https://${lang}.wikipedia.org/wiki/${enc(p.title)}`,lang};wikiCache.set(key,data);return data}catch{return null}
}
async function hydrateWiki(e,targetId='wikiMedia'){
  const box=document.getElementById(targetId); if(!box)return;
  let data=await fetchWiki(e.wikiQuery||e.title,'ko'); if(!data?.image&&e.wikiQueryEn)data=await fetchWiki(e.wikiQueryEn,'en')||data;
  if(!document.getElementById(targetId))return;
  if(data?.image){box.innerHTML=`<a class="history-image" href="${data.url}" target="_blank" rel="noreferrer"><img src="${data.image}" alt="${safe(data.title)} 관련 Wikipedia 이미지" loading="lazy" referrerpolicy="no-referrer"><span>Wikipedia / Wikimedia · 이미지와 상세 설명 보기 ↗</span></a>${data.extract?`<details class="wiki-extract"><summary>Wikipedia 핵심 설명 펼치기</summary><p>${safe(data.extract.slice(0,700))}${data.extract.length>700?'…':''}</p></details>`:''}`}
  else box.innerHTML=`<div class="media-empty">관련 이미지를 자동으로 불러오지 못했습니다. 아래 Wikimedia Commons 이미지 검색을 이용하세요.</div>`;
}

const map=new maplibregl.Map({container:'map',style:{version:8,sources:{osm:{type:'raster',tiles:['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],tileSize:256,attribution:'© OpenStreetMap contributors'}},layers:[{id:'osm',type:'raster',source:'osm'}]},center:[45,30],zoom:1.25,minZoom:1,maxZoom:9});
map.addControl(new maplibregl.NavigationControl(),'bottom-right');
map.on('click',e=>{const hit=nearest(e.lngLat.lat,e.lngLat.lng,state.year);state.selected=hit;state.year=hit.year;state.route=null;state.mode='explore';showToast(`${hit.place} 주변에서 ${fmt(hit.year)}의 사건을 찾았습니다.`);render(true)});
function clearMarkers(){state.markers.forEach(m=>m.remove());state.markers=[]}
function renderMarkers(fly=false){clearMarkers();const list=state.mode==='duel'?[duelEvent(state.duelA),duelEvent(state.duelB)]:visible().slice(0,40);list.forEach(e=>{const el=document.createElement('button');el.className=`map-marker ${state.selected?.id===e.id&&state.mode==='explore'?'is-selected':''}`;el.ariaLabel=`${e.place}: ${e.title}`;el.title=`${e.place} · ${e.year} · ${e.title}`;el.onclick=ev=>{ev.stopPropagation();state.selected=e;state.year=e.year;state.mode='explore';state.route=null;render(true)};state.markers.push(new maplibregl.Marker({element:el}).setLngLat([e.lon,e.lat]).addTo(map))});
 if(state.route){const bounds=new maplibregl.LngLatBounds();state.route.stops.forEach((s,i)=>{const el=document.createElement('button');el.className=`route-marker ${state.routeStopIndex===i?'active':''}`;el.textContent=i+1;el.title=`${s.place} · ${s.year}`;el.onclick=ev=>{ev.stopPropagation();state.routeStopIndex=i;state.year=s.year;renderDetail();updateTimeline();map.flyTo({center:[s.lon,s.lat],zoom:5,duration:650})};state.markers.push(new maplibregl.Marker({element:el}).setLngLat([s.lon,s.lat]).addTo(map));bounds.extend([s.lon,s.lat])});map.fitBounds(bounds,{padding:80,duration:850,maxZoom:4})}
 else if(fly&&state.selected&&state.mode==='explore')map.flyTo({center:[state.selected.lon,state.selected.lat],zoom:5,duration:700});
}
function duelEvent(name){const c=cities.find(x=>x.name===name);return nearest(c.lat,c.lon,state.year)}

function renderSidebar(){let html='';if(state.mode==='explore'){const list=visible();const countries=new Set(events.map(e=>e.country)).size;html=`<div class="dataset-stat"><b>${events.length}</b>개 사건 · <b>${countries}</b>개 국가/지역</div><div class="section-title"><span>이 시기의 사건</span><span>${list.length}</span></div><div class="event-list">${list.length?list.slice(0,11).map(e=>`<button class="event-row ${state.selected.id===e.id?'active':''}" data-event="${e.id}"><span class="event-dot ${e.category}"></span><span class="event-copy"><b>${safe(e.title)}</b><small>${safe(e.place)} · ${fmt(e.year)} · ${safe(e.country)}</small></span><span>›</span></button>`).join(''):'<div class="empty">검색 결과가 없습니다. 다른 장소·국가·인물·사건을 입력해 보세요.</div>'}</div>`}
 if(state.mode==='stories'){html=`<div class="section-title"><span>교육용 Story Packs</span><span>${routes.length}</span></div><div class="story-list">${routes.map(r=>`<button class="story-card ${state.route?.id===r.id?'active':''}" data-route="${r.id}"><span class="story-icon">${r.icon}</span><span><b>${safe(r.title)}</b><small>${safe(r.subtitle)}</small></span><span>›</span></button>`).join('')}</div>`}
 if(state.mode==='duel'){html=`<div class="duel-controls"><div><label>장소 A</label><select id="duelA">${cities.map(c=>`<option value="${c.name}" ${c.name===state.duelA?'selected':''}>${c.label}</option>`).join('')}</select></div><div class="vs-chip">VS</div><div><label>장소 B</label><select id="duelB">${cities.map(c=>`<option value="${c.name}" ${c.name===state.duelB?'selected':''}>${c.label}</option>`).join('')}</select></div></div><p class="duel-help">타임슬라이더를 움직이면 두 도시의 가장 가까운 역사 사건이 동시에 바뀝니다.</p>`}
 $('#sidebarContent').innerHTML=html;
 $$('[data-event]').forEach(b=>b.onclick=()=>{state.selected=events.find(e=>e.id===b.dataset.event);state.year=state.selected.year;render(true)});
 $$('[data-route]').forEach(b=>b.onclick=()=>{state.route=routes.find(r=>r.id===b.dataset.route);state.routeStopIndex=0;state.year=state.route.stops[0].year;render()});
 if($('#duelA'))$('#duelA').onchange=e=>{state.duelA=e.target.value;render()}; if($('#duelB'))$('#duelB').onchange=e=>{state.duelB=e.target.value;render()};
}
function renderDetail(){const p=$('#detailPanel');if(state.mode==='duel'){const pair=[[cities.find(c=>c.name===state.duelA),duelEvent(state.duelA)],[cities.find(c=>c.name===state.duelB),duelEvent(state.duelB)]];p.innerHTML=`<div class="duel-view"><div class="panel-kicker">TIME DUEL · ${fmt(state.year)}</div><h2>같은 시대, 다른 세계</h2><p>두 도시가 같은 시기에 어떤 정치·사회·기술 변화를 겪었는지 비교해 보세요.</p>${pair.map(([c,e],i)=>`<article class="duel-card"><div class="duel-number">0${i+1}</div><small>${c.label} · ${e.country}</small><h3>${safe(e.title)}</h3><strong>${fmt(e.year)}</strong><p>${safe(e.summary)}</p><div class="duel-why"><b>왜 중요한가</b>${safe(e.significance)}</div><a href="https://ko.wikipedia.org/w/index.php?search=${enc(e.wikiQuery||e.title)}" target="_blank" rel="noreferrer">Wikipedia에서 더 읽기 ↗</a></article>`).join('')}</div>`;return}
 if(state.route){const r=state.route,s=r.stops[state.routeStopIndex];const pseudo={wikiQuery:`${r.title} ${s.place}`,wikiQueryEn:`${r.title} ${s.place}`};p.innerHTML=`<div class="route-view"><div class="panel-kicker">STORY PACK · ${safe(r.theme)}</div><h2>${safe(r.title)}</h2><p>${safe(r.intro)}</p><div id="routeWikiMedia" class="media-shell"><div class="media-loading">관련 이미지와 자료를 찾는 중…</div></div><section class="learning-section"><h3>이 스토리에서 배울 것</h3><p>${safe(r.question)}</p></section><div class="route-stops">${r.stops.map((x,i)=>`<button class="route-stop ${i===state.routeStopIndex?'active':''}" data-stop="${i}"><span>${i+1}</span><div><b>${safe(x.place)}</b><small>${fmt(x.year)} · ${safe(x.note)}</small>${x.lesson?`<em>${safe(x.lesson)}</em>`:''}</div></button>`).join('')}</div><div class="reading-row"><a href="https://ko.wikipedia.org/w/index.php?search=${enc(r.title)}" target="_blank" rel="noreferrer">Wikipedia 자세히 ↗</a><a href="https://namu.wiki/Search?q=${enc(r.title)}" target="_blank" rel="noreferrer">나무위키 검색 ↗</a></div></div>`;$$('[data-stop]').forEach(b=>b.onclick=()=>{state.routeStopIndex=+b.dataset.stop;const x=r.stops[state.routeStopIndex];state.year=x.year;renderDetail();updateTimeline();map.flyTo({center:[x.lon,x.lat],zoom:5,duration:700})});hydrateWiki(pseudo,'routeWikiMedia');return}
 const e=state.selected;const fav=state.favorites.includes(e.id);p.innerHTML=`<article class="history-detail"><div class="detail-hero"><div><span class="category-pill">${labels[e.category]||e.category}</span><div class="panel-kicker">${safe(e.region)} · ${safe(e.country)} · ${safe(e.place)} · ${fmt(e.year)}</div><h2>${safe(e.title)}</h2></div><button class="favorite ${fav?'active':''}" id="favBtn" aria-label="즐겨찾기">${fav?'♥':'♡'}</button></div><div id="wikiMedia" class="media-shell"><div class="media-loading">관련 Wikipedia/Wikimedia 이미지와 설명을 불러오는 중…</div></div><p class="summary">${safe(e.summary)}</p><section class="why-card"><small>왜 중요한가?</small><p>${safe(e.significance)}</p></section><section class="learning-section"><h3>핵심 학습 포인트</h3><ol>${e.keyPoints.map(k=>`<li>${safe(k)}</li>`).join('')}</ol></section><div class="fact-grid"><div><small>관련 인물</small><p>${e.people.length?e.people.map(safe).join(' · '):'특정 인물보다 구조적 변화가 중요한 사건'}</p></div><div><small>관련 장소</small><p>${e.relatedPlaces.map(safe).join(' · ')}</p></div></div><div class="provenance"><small>자료 계층</small><b>${safe(sourceTierLabels[e.sourceTier]||e.sourceTier)}</b><span>좌표 정확도: ${safe(e.coordinatePrecision||'unknown')} · 검토: ${safe(e.reviewStatus||'needs-review')}</span>${e.wikidataId?`<span>Wikidata: ${safe(e.wikidataId)}</span>`:''}</div><div class="source-section"><div class="section-title"><span>더 읽기 · 원문 · 이미지</span></div>${sourceLinks(e).map(s=>`<a class="source-link" href="${s[1]}" target="_blank" rel="noreferrer"><span>▣ ${safe(s[0])}</span><span>↗</span></a>`).join('')}</div><button class="primary-cta" id="agoBtn">⌁ 이 장소의 약 500년 전 보기</button></article>`;
 $('#favBtn').onclick=()=>{state.favorites=fav?state.favorites.filter(id=>id!==e.id):[...state.favorites,e.id];localStorage.setItem('tt-favorites',JSON.stringify(state.favorites));renderDetail()};
 $('#agoBtn').onclick=()=>{const target=Math.max(-3500,state.year-500);state.year=target;const hit=nearest(e.lat,e.lon,target);state.selected=hit;showToast(`${e.place} 기준 약 500년 전의 가까운 기록으로 이동했습니다.`);render(true)};hydrateWiki(e);
}
function updateTimeline(){ $('#yearSlider').value=state.year;$('#yearLabel').textContent=fmt(state.year);const same=events.filter(e=>Math.abs(e.year-state.year)<=20);$('#yearSubtitle').textContent=same.length?`${same.length}개의 가까운 세계사 기록`:'시간축을 움직여 보세요'}
function render(fly=false){$$('[data-mode]').forEach(b=>b.classList.toggle('active',b.dataset.mode===state.mode));$('#searchInput').value=state.search;const badge=$('#datasetBadge');if(badge){const countries=new Set(events.map(e=>e.country)).size;badge.innerHTML=`<b>UPDATE 2026.09</b><span>${(dataCounts.curated+dataCounts.backbone).toLocaleString()}개 내장 · 자동 Index ${dataCounts.index.toLocaleString()} · ${routes.length}개 Story Pack</span>`;badge.title=`큐레이션 ${dataCounts.curated} + Backbone ${dataCounts.backbone} + 자동 Index ${dataCounts.index} + 가져오기 ${dataCounts.imported||0} · ${dataSource}`;}updateTimeline();renderSidebar();renderDetail();renderMarkers(fly)}
$$('[data-mode]').forEach(b=>b.onclick=()=>{state.mode=b.dataset.mode;state.route=null;render()});
$('#homeBtn').onclick=()=>{state.mode='explore';state.route=null;render()};
$('#searchInput').oninput=e=>{state.search=e.target.value;renderSidebar();renderMarkers()};
$('#yearSlider').oninput=e=>{state.year=+e.target.value;state.route=null;updateTimeline();renderSidebar();renderDetail();renderMarkers()};
$('#themeBtn').onclick=()=>{const next=document.documentElement.dataset.theme==='light'?'dark':'light';document.documentElement.dataset.theme=next;localStorage.setItem('tt-theme',next);$('#themeBtn').textContent=next==='dark'?'☀':'☾'};
$('#toast button').onclick=()=>$('#toast').hidden=true;
const savedTheme=localStorage.getItem('tt-theme')||'dark';document.documentElement.dataset.theme=savedTheme;$('#themeBtn').textContent=savedTheme==='dark'?'☀':'☾';render();
