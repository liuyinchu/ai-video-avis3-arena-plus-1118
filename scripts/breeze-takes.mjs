import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {setTimeout as wait} from 'node:timers/promises';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const story=JSON.parse(fs.readFileSync(path.join(root,'voice/script.json'),'utf8'));
const dir=path.join(root,'voice/takes'); fs.mkdirSync(dir,{recursive:true});
const api=new URL(process.env.BREEZE_API_BASE || 'http://127.0.0.1:7860');
if(!['127.0.0.1','localhost','[::1]'].includes(api.hostname)) throw Error('Use the loopback endpoint of the SSH tunnel.');
const token=(process.env.BREEZE_TOKEN || fs.readFileSync(0,'utf8')).trim();
if(!token) throw Error('Supply the Breeze token via stdin or BREEZE_TOKEN.');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const indexFile=path.join(dir,'index.json');
const index=fs.existsSync(indexFile)?JSON.parse(fs.readFileSync(indexFile)):{model:story.model,takes:{}};
function atomic(p,b){const tmp=p+'.part-'+process.pid;fs.writeFileSync(tmp,b);fs.renameSync(tmp,p);}
function inspect(b){
  if(b.toString('ascii',0,4)!=='RIFF'||b.toString('ascii',8,12)!=='WAVE'||b.readUInt32LE(4)+8!==b.length)throw Error('Incomplete WAV');
  let fmt=false;
  for(let p=12;p+8<=b.length;){const n=b.readUInt32LE(p+4),k=b.toString('ascii',p,p+4);if(p+n+8>b.length)throw Error('Truncated chunk');
    if(k==='fmt ')fmt=b.readUInt16LE(p+8)===1&&b.readUInt16LE(p+10)===1&&b.readUInt32LE(p+12)===24000&&b.readUInt16LE(p+22)===16;
    if(k==='data'&&fmt&&n>=24000&&n%2===0)return n/48000;
    p+=8+n+n%2;
  }throw Error('Expected 24 kHz mono 16-bit PCM');
}
const health=await fetch(new URL('/health',api)).then(r=>r.json());
if(health.status!=='ok'||health.sample_rate!==24000)throw Error('Service is not ready');
async function take(id,fields,ref){
  const filename=path.join(dir,id+'.wav');
  const fingerprint=hash(JSON.stringify({model:story.model,fields,reference:ref?hash(ref):null}));
  if(index.takes[id]?.fingerprint===fingerprint && fs.existsSync(filename)){
    const prev=fs.readFileSync(filename);
    if(index.takes[id].sha256===hash(prev)){inspect(prev);return prev;}
  }
  for(let attempt=0;attempt<20;attempt++){
    const form=new FormData();
    for(const [k,v] of Object.entries(fields)) form.set(k,String(v));
    if(ref)form.set('ref_audio',new Blob([ref],{type:'audio/wav'}),'reference.wav');
    const r=await fetch(new URL('/v1/audio/speech.wav',api),{method:'POST',body:form,headers:{Authorization:'Bearer '+token},signal:AbortSignal.timeout(150000)});
    if(r.status===409){await r.arrayBuffer();await wait(Math.min(15000,3000+attempt*1200));continue;}
    if(!r.ok)throw Error(id+' returned HTTP '+r.status+' '+(await r.text()).slice(0,300));
    const b=Buffer.from(await r.arrayBuffer());const duration=inspect(b);
    atomic(filename,b);
    index.takes[id]={fingerprint,sha256:hash(b),duration,seed:fields.seed,mode:ref?'reference':'design',job:process.env.BREEZE_JOB_ID||null};
    atomic(indexFile,JSON.stringify(index,null,2)+'\n');
    console.log(id,duration.toFixed(2)+' s');
    return b;
  }throw Error('Busy inference slot while generating '+id);
}
const ref=await take('reference',story.design);
const ids=process.argv.slice(2);
for(const l of story.lines.filter(l=>ids.length===0||ids.includes(l.id))){
  await take(l.id,{text:l.speech,ref_text:story.design.text,...story.clone,...(l.settings||{})},ref);
}
