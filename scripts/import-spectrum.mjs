import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const arena=process.env.ARENA_REPO || path.resolve(root,'../../avis3-arena');
const host=process.env.ARENA_ARCHIVE_HOST;
const archive=process.env.ARENA_ARCHIVE_EXTENSIONS;
if(!host||!archive)throw Error('Set ARENA_ARCHIVE_HOST and ARENA_ARCHIVE_EXTENSIONS for an archive refresh. The included data is ready to render.');
const dir=archive.replace(/\/+$/, '')+'/';
const sshArgs=['-o','BatchMode=yes','-o','ConnectTimeout=12'];
if(process.env.ARENA_ARCHIVE_KEY)sshArgs.push('-i',process.env.ARENA_ARCHIVE_KEY);
const remoteQuote=value=>"'"+value.split("'").join("'\"'\"'")+"'";
const website='1e359f2:evaluations/Evaluation-1108/website/spectra/';
const load=name=>JSON.parse(execFileSync('git',['-C',arena,'show',website+name],{encoding:'utf8',maxBuffer:5e6}));
const frequency=load('frequency.json').values;
const baseline=load('baseline-round-01.json');
assert(baseline.selection==='round_01' && baseline.unit==='m/sqrt(Hz)' && frequency.length===10000);
const raw={baseline:baseline.asd_by_channel};
const exporter=fs.readFileSync(path.join(root,'scripts/export-truth.pl'));
for(const id of [13,16,17]){
  const id3=String(id).padStart(3,'0');
  const run=id===16?'official-016-20261117/archive/run':'official-013-017-20261118/archive/runs/official-'+id3;
  const file=dir+run+'/rounds/round_01/spectra.json';
  const stdout=execFileSync('ssh',[...sshArgs,'--',host,'LC_ALL=C perl - '+remoteQuote(file)],{input:exporter,encoding:'utf8',maxBuffer:5e6,env:{...process.env,LC_ALL:'C'}});
  const {frequency:freq,asd}=JSON.parse(stdout);
  assert.equal(freq.length,frequency.length);
  assert(freq.every((f,i)=>Math.abs(f-frequency[i])<1e-10));
  raw['n'+id]=[0,1,2].map(ch=>asd.map(row=>row[ch]));
}
for(const channels of Object.values(raw))assert(channels.every(ch=>ch.length===frequency.length&&ch.every(x=>Number.isFinite(x)&&x>0)));
assert(frequency[0]===0.01 && Math.abs(frequency.at(-1)-100)<1e-10);
const bins=new Map();
frequency.forEach((f,i)=>{
  const k=i===0?-1:i===frequency.length-1?160:Math.min(159,Math.floor((Math.log10(f)+2)*40));
  if(!bins.has(k))bins.set(k,[]);
  bins.get(k).push(i);
});
const groups=[...bins.values()];
const rms=(ch,indices)=>Math.sqrt(indices.reduce((n,i)=>n+ch[i]**2,0)/indices.length);
const diagnostic=frequency.map((f,i)=>f>=0.8-1e-10&&f<=1.2+1e-10?i:-1).filter(i=>i>=0);
assert.equal(diagnostic.length,41);
const series=Object.fromEntries(Object.entries(raw).map(([key,channels])=>[key,channels.map(ch=>groups.map(g=>rms(ch,g)))]));
const band=Object.fromEntries(Object.entries(raw).map(([key,channels])=>[key,channels.map(ch=>rms(ch,diagnostic))]));
const out={selection:'round_01',channels:['y1','y2','y3'],units:'m/sqrt(Hz)',binning:'40 log bands per decade, quadratic mean per band; endpoints kept',
  frequency:groups.map(g=>Math.exp(g.reduce((n,i)=>n+Math.log(frequency[i]),0)/g.length)),series,band08to12:band};
fs.mkdirSync(path.join(root,'data'),{recursive:true});
fs.writeFileSync(path.join(root,'data/spectrum.json'),JSON.stringify(out)+'\n');
console.log('Round 01, 0.01–100 Hz:',groups.length,'plotted points. RMS ASD for 0.8–1.2 Hz',band);
for(let ch=0;ch<3;ch++){const all=Object.values(series).flatMap(row=>row[ch]);console.log('channel',ch+1,'range',Math.log10(Math.min(...all)),Math.log10(Math.max(...all)));}
