import fs from 'node:fs';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {readWav} from './vo-audio.mjs';
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const prefix='out/AVIS3-Plus-1118-Breeze';
const build='build/voiced/',qa=build+'review/';
const plan=read(build+'placement.json'), edit=read(build+'edit.json');
const script=read('voice/script.json'),takes=read('voice/takes/index.json');
const streams=read(qa+'streams.json'),movie=fs.readFileSync(prefix+'.mp4');
const v=streams.streams.find(x=>x.codec_type==='video'),a=streams.streams.find(x=>x.codec_type==='audio');
assert.equal(streams.streams.length,2);assert(v.width===1920&&v.height===1080&&v.codec_name==='h264'&&v.pix_fmt==='yuv420p');
assert.equal(+v.nb_frames,plan.frameCount);assert.equal(+v.nb_read_frames,plan.frameCount);assert.equal(v.avg_frame_rate,plan.fps+'/1');
assert(a.codec_name==='aac'&&a.channels===2&&a.sample_rate==='48000'&&a.tags.language==='zho');
assert.equal(+v.start_time,0);assert.equal(+a.start_time,0);
assert(Math.abs(+v.duration-plan.duration)<0.001&&Math.abs(+a.duration-plan.duration)<0.025);
for(const p of ['read-errors.log','decode.log'])assert.equal(fs.statSync(qa+p).size,0);
const sub=fs.readFileSync(prefix+'.zh-Hans.srt','utf8').trim().split(/\r?\n\r?\n/);
assert.equal(sub.length,script.lines.length);assert.equal(plan.timings.length,script.lines.length);
const ms=s=>s.split(/[:,]/).map(Number).reduce((total,n,i)=>total*(i===3?1000:60)+n,0);
const refHash=hash(fs.readFileSync('voice/takes/reference.wav'));
assert.equal(refHash,takes.takes.reference.sha256);
assert.equal(takes.takes.reference.fingerprint,hash(JSON.stringify({model:script.model,fields:script.design,reference:null})));
const pcm=readWav(qa+'decoded.wav'), master=readWav(build+'mix.wav'),voice=readWav(prefix+'-voice.wav');
assert(pcm.rate===48000&&pcm.channels===2&&master.rate===48000&&master.channels===2&&voice.rate===48000&&voice.channels===1);
assert.equal(voice.frames,Math.round(plan.duration*voice.rate));
assert.equal(master.frames,voice.frames);assert(Math.abs(pcm.frames-master.frames)<=1024);
const rows=[];
for(const [i,p] of plan.timings.entries()){
  const line=script.lines[i];const actual=fs.readFileSync('voice/takes/'+line.id+'.wav');
  const fields={text:line.speech,ref_text:script.design.text,...script.clone,...(line.settings||{})};
  assert.equal(takes.takes[line.id].fingerprint,hash(JSON.stringify({model:script.model,fields,reference:refHash})));
  assert.equal(takes.takes[line.id].sha256,hash(actual));assert.equal(p.id,line.id);
  const [num,interval,caption]=sub[i].split('\n');
  assert.equal(+num,i+1);assert.equal(caption,line.caption);
  const [on,off]=interval.split(' --> ').map(ms);
  assert(on===Math.round(p.subtitleStart*1000/plan.fps)&&off===Math.round(p.subtitleEnd*1000/plan.fps));
  const shot=edit.scenes.find(s=>s.id===line.scene),shotFrame=Math.round(shot.bar*240/edit.bpm*edit.fps);
  const burn=shot.cues.find(c=>c.text===caption);assert(burn);
  assert.equal(shotFrame+Math.round(burn.at*plan.fps),p.subtitleStart);assert.equal(shotFrame+Math.round(burn.until*plan.fps),p.subtitleEnd);
  assert(p.startSample>=0&&p.endSample<=voice.frames&&p.startSample<p.endSample);
  if(i>0)assert(p.startSample>=plan.timings[i-1].endSample&&p.subtitleStart>=plan.timings[i-1].subtitleEnd);
  assert(p.subtitleStart/plan.fps<=p.startSample/voice.rate+0.001);assert(p.subtitleEnd/plan.fps>=p.endSample/voice.rate-0.001);
  let aa=0,bb=0,ab=0,vv=0,yy=0,vy=0;
  for(let k=p.startSample;k<p.endSample;k+=3){
    const d=voice.pcm[k]/32768;
    const m=(pcm.pcm[2*k]+pcm.pcm[2*k+1])/65536; vv+=d*d;yy+=m*m;vy+=d*m;
    for(let ch=0;ch<2;ch++){
      const x=master.pcm[2*k+ch]/32768,y=pcm.pcm[2*k+ch]/32768;
      aa+=x*x;bb+=y*y;ab+=x*y;
    }
  }
  const corr=ab/Math.sqrt(aa*bb),speechCorr=vy/Math.sqrt(vv*yy);
  const speechEnergy=vy*vy/vv,residualDB=10*Math.log10(speechEnergy/Math.max(1e-12,yy-speechEnergy));
  assert(corr>0.98,'Unexpected AAC alignment at '+p.id);
  assert(speechCorr>0.93,'Voice does not dominate the center at '+p.id);
  rows.push({id:p.id,masterCorrelation:+corr.toFixed(5),drySpeechCorrelation:+speechCorr.toFixed(5),speechOverResidualDB:+residualDB.toFixed(2)});
}
const source=fs.readFileSync(qa+'loudness.log','utf8');const loud=JSON.parse(source.slice(source.lastIndexOf('{'),source.lastIndexOf('}')+1));
assert(Number.isFinite(+loud.input_i)&&+loud.input_tp<0);
const data={file:prefix+'.mp4',sha256:hash(movie),size:movie.length,seconds:+v.duration,frameCount:+v.nb_read_frames,format:'H.264, 1920x1080, 30 fps; AAC, 48 kHz stereo',
  model:script.model,slurmJobs:[...new Set(script.lines.map(l=>takes.takes[l.id].job))],scenes:plan.scenes.length,cues:rows.length,
  integratedLUFS:+loud.input_i,truePeakDBTP:+loud.input_tp,fastestTempo:Math.max(...plan.scenes.map(s=>s.tempo)),
  lowestVoiceOverMusicDB:Math.min(...plan.timings.map(r=>r.voiceOverBedDB)),checks:rows};
fs.writeFileSync(qa+'verification.json',JSON.stringify(data,null,2)+'\n');
console.log(JSON.stringify({...data,checks:undefined},null,2));
