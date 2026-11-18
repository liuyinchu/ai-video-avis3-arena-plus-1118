import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const edit=JSON.parse(fs.readFileSync(path.join(root,'src/edit.json')));
const base=bar=>Math.round(bar*240/edit.bpm*edit.fps);
const time=n=>{
  const ms=Math.round(n*1000/edit.fps);
  return [Math.floor(ms/3600000),Math.floor(ms/60000)%60,Math.floor(ms/1000)%60].map(i=>String(i).padStart(2,'0')).join(':')+','+String(ms%1000).padStart(3,'0');
};
let srt='',idx=1;
for (const [i,s] of edit.scenes.entries()){
  for (const [j,c] of s.cues.entries()){
    const start=base(s.bar)+Math.ceil(c.at*edit.fps-1e-8);
    const end=j+1<s.cues.length ? base(s.bar)+Math.ceil(s.cues[j+1].at*edit.fps-1e-8) : base(edit.scenes[i+1]?.bar??edit.endBar);
    srt+=idx+++'\n'+time(start)+' --> '+time(end)+'\n'+c.text+'\n\n';
  }
}
fs.mkdirSync(path.join(root,'out'),{recursive:true});
fs.writeFileSync(path.join(root,'out/AVIS3-Plus-1118.zh-Hans.srt'),srt);
console.log(idx-1,'caption cues');
