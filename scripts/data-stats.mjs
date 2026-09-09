import { readFile } from 'node:fs/promises';
const files=['history-events.json','history-backbone.json','history-events-index.json','story-packs.json','cities.json'];
for(const file of files){
  try{const data=JSON.parse(await readFile(new URL(`../data/${file}`,import.meta.url),'utf8'));console.log(`${file}: ${Array.isArray(data)?data.length:'object'}`)}
  catch{console.log(`${file}: not generated yet`)}
}
