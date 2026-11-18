import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {readWav,writeWav,speechBounds,compactPauses} from './vo-audio.mjs';

const work=process.argv[2];
if(!work||!process.env.AVTOOLS_DIR)throw Error('Run scripts/render-voiced.sh from the project.');
const edit=JSON.parse(fs.readFileSync('src/edit.json','utf8'));
const script=JSON.parse(fs.readFileSync('voice/script.json','utf8'));
edit.voiceCredit='普通话合成旁白 · Breeze TTS 2';
const rate=48000, fps=edit.fps;
const frameAtBar=bar=>Math.round(bar*240/edit.bpm*fps);
const frameCount=frameAtBar(edit.endBar), frameSeconds=frameCount/fps;
const length=Math.round(rate*frameSeconds);
const dbToGain=db=>10**(db/20), gainToDB=x=>20*Math.log10(Math.max(1e-12,x));
const round=x=>Math.round(x*10000)/10000;
const pcm16=x=>Math.max(-32768,Math.min(32767,Math.round(x*32768)));
const ff=(args)=>{
  const bin=process.env.AVTOOLS_DIR;
  const proc=spawnSync(path.join(bin,'ffmpeg'),['-nostdin','-hide_banner',...args],{
    encoding:'utf8',maxBuffer:4000000,env:{...process.env,DYLD_LIBRARY_PATH:bin+(process.env.DYLD_LIBRARY_PATH?':'+process.env.DYLD_LIBRARY_PATH:'')}
  });
  if(proc.status!==0)throw Error((proc.stderr||proc.error||'ffmpeg failed').toString());
  return proc.stderr;
};
function levels(file){
  const s=ff(['-nostats','-i',file,'-af','loudnorm=I=-16:TP=-1.5:LRA=10:print_format=json','-f','null','-']);
  const v=JSON.parse(s.slice(s.lastIndexOf('{'),s.lastIndexOf('}')+1));
  return {integrated:Number(v.input_i),peak:Number(v.input_tp),lra:Number(v.input_lra)};
}
function soft(x){x=Math.min(1,Math.max(0,x));return x*x*(3-2*x);}
function stamp(frame){
  const t=Math.round(frame*1000/fps);
  return [Math.floor(t/3600000),Math.floor(t/60000)%60,Math.floor(t/1000)%60].map(x=>String(x).padStart(2,'0')).join(':')+','+String(t%1000).padStart(3,'0');
}

const mono=new Int16Array(length), activity=new Float32Array(length);
const timings=[], scenes=[], segments=[];
for(const [i,sc] of edit.scenes.entries()){
  const startFrame=frameAtBar(sc.bar),nextFrame=frameAtBar(edit.scenes[i+1]?.bar??edit.endBar);
  const begin=startFrame/fps,end=nextFrame/fps;
  const rows=script.lines.filter(l=>l.scene===sc.id);
  if(rows.length!==sc.cues.length)throw Error('Expected matching source captions in '+sc.id);
  const clips=rows.map(row=>{
    const file='voice/takes/'+row.id+'.wav',w=readWav(file);
    if(w.rate!==24000||w.channels!==1)throw Error('Unexpected source format '+file);
    return {row,file,bounds:speechBounds(w)};
  });
  const lead=sc.id==='open'?0.50:0.24, tail=sc.id==='board'?0.86:0.28, gap=0.29;
  const available=end-begin-lead-tail-(rows.length-1)*gap-0.06;
  const natural=clips.reduce((s,c)=>s+c.bounds.seconds,0);
  let pauseCut=0;
  if(natural/available>1.05){
    for(const clip of clips){
      const w=readWav(clip.file), trimmed=compactPauses(w,clip.bounds.start,clip.bounds.end);
      if(!trimmed)continue;
      clip.file=path.join(work,clip.row.id+"-timed.wav");
      writeWav(clip.file,trimmed.pcm,w.rate,1);
      clip.bounds={start:0,end:trimmed.pcm.length,seconds:trimmed.pcm.length/w.rate};
      clip.pauseCut=trimmed.removed;pauseCut+=trimmed.removed;
    }
  }
  // Preserve performance and pitch. Small whole-scene timing corrections avoid abrupt pace changes.
  const tempo=Math.max(1,(natural-pauseCut)/available);
  scenes.push({scene:sc.id,tempo:round(tempo),natural:round(natural),silenceShortened:round(pauseCut),available:round(available)});
  const prepared=clips.map(c=>{
    const output=path.join(work,c.row.id+'.wav');
    const filters=['atrim=start_sample='+c.bounds.start+':end_sample='+c.bounds.end,'asetpts=PTS-STARTPTS'];
    if(tempo>1.0001)filters.push('atempo='+tempo.toFixed(6));
    filters.push('aresample='+rate);
    ff(['-loglevel','error','-y','-i',c.file,'-af',filters.join(','),'-c:a','pcm_s16le',output]);
    const wav=readWav(output),l=levels(output);
    if(!Number.isFinite(l.integrated)||!Number.isFinite(l.peak))throw Error('Invalid voice levels in '+c.row.id);
    const gain=Math.min(-19.5-l.integrated,-2.8-l.peak);
    return {...c,wav,levels:l,gain,duration:wav.frames/rate};
  });
  const originalCues=sc.cues;
  sc.cues=[];
  let previousEnd=begin;
  for(const [j,c] of prepared.entries()){
    const remaining=prepared.slice(j).reduce((n,v)=>n+v.duration,0)+(prepared.length-j-1)*gap;
    const latest=end-tail-remaining;
    const minStart=j===0?begin+lead:previousEnd+gap;
    const desired=begin+originalCues[j].at+(j===0?lead:0.07);
    const s=Math.round(Math.max(minStart,Math.min(latest,desired))*rate);
    const e=s+c.wav.frames;
    if(e>Math.round(end*rate)||s<0)throw Error('Voice exceeds shot '+c.row.id);
    const g=dbToGain(c.gain);
    // The input is uncompressed speech. Tiny edge ramps suppress file-boundary clicks.
    for(let k=0;k<c.wav.frames;k++){
      const edge=Math.min(1,(k+1)/(rate*0.002),(c.wav.frames-k)/(rate*0.007));
      mono[s+k]=pcm16(c.wav.pcm[k]/32768*g*edge);
    }
    const attack=Math.round(0.34*rate),hold=Math.round(0.16*rate),release=Math.round(0.62*rate);
    for(let k=Math.max(0,s-attack);k<Math.min(length,e+hold+release);k++){
      const value=k<s?soft((k-s+attack)/attack):k<e+hold?1:1-soft((k-e-hold)/release);
      if(value>activity[k])activity[k]=value;
    }
    const on=Math.max(startFrame,Math.round(s/rate*fps)-1);
    const off=Math.min(nextFrame,Math.ceil(e/rate*fps)+7);
    const cue={at:(on-startFrame)/fps,until:(off-startFrame)/fps,kind:originalCues[j].kind,text:c.row.caption};
    const prev=sc.cues.at(-1);
    if(prev && prev.until>cue.at)prev.until=cue.at;
    sc.cues.push(cue);
    const item={id:c.row.id,scene:sc.id,caption:c.row.caption,startSample:s,endSample:e,startSeconds:round(s/rate),endSeconds:round(e/rate),
      subtitleStart:on,subtitleEnd:off,silenceShortened:round(c.pauseCut||0),tempo:round(tempo),voiceGainDB:round(c.gain),rawLUFS:c.levels.integrated};
    if(timings.at(-1)?.subtitleEnd>on)timings.at(-1).subtitleEnd=on;
    timings.push(item);
    segments.push([s,e,item]);
    previousEnd=e/rate;
  }
}
if(timings.length!==script.lines.length)throw Error('Some voice lines were not placed');
const voiceOut=path.join(work,'voice.wav');
writeWav(voiceOut,mono,rate,1);
const bedFile=path.join(work,'music-48k.wav');
ff(['-loglevel','error','-y','-i','assets/score.wav','-ac','2','-ar',String(rate),'-c:a','pcm_s16le',bedFile]);
const bed=readWav(bedFile);
if(bed.channels!==2||Math.abs(bed.frames-length)>2)throw Error('Music duration does not match video');
const mix=new Int16Array(length*2);
let peak=0;
for(let i=0;i<length;i++){
  const bg=dbToGain(-3.5-14.5*activity[i]);
  for(let ch=0;ch<2;ch++){
    const sample=mono[i]/32768+(bed.pcm[2*i+ch]||0)/32768*bg;
    peak=Math.max(peak,Math.abs(sample));mix[2*i+ch]=pcm16(sample);
  }
}
if(peak>=1)throw Error('Premix clip detected');
for(const [s,e,item] of segments){
  let vv=0,bb=0;
  for(let j=s;j<e;j++){
    const v=mono[j]/32768, l=bed.pcm[2*j]/32768*dbToGain(-18),r=bed.pcm[2*j+1]/32768*dbToGain(-18);
    vv+=v*v;bb+=(l*l+r*r)/2;
  }
  item.voiceOverBedDB=round(10*Math.log10(vv/Math.max(bb,1e-16)));
}
const pre=path.join(work,'premix.wav');writeWav(pre,mix,rate,2);
const preLevels=levels(pre),masterGain=Math.min(-16.5-preLevels.integrated,-2-preLevels.peak);
ff(['-loglevel','error','-y','-i',pre,'-af','volume='+masterGain.toFixed(5)+'dB','-c:a','pcm_s16le',path.join(work,'mix.wav')]);
const captions=timings.map((x,i)=>[i+1,stamp(x.subtitleStart)+' --> '+stamp(x.subtitleEnd),x.caption,''].join('\n')).join('\n');
fs.writeFileSync(path.join(work,'captions.srt'),captions+'\n');
fs.writeFileSync(path.join(work,'edit.json'),JSON.stringify(edit,null,2)+'\n');
fs.writeFileSync(path.join(work,'placement.json'),JSON.stringify({model:script.model,sampleRate:rate,frameCount,fps,duration:frameSeconds,
  musicBetweenDB:-3.5,musicUnderSpeechDB:-18,masterGainDB:round(masterGain),premixPeakDBFS:round(gainToDB(peak)),master:levels(path.join(work,'mix.wav')),scenes,timings},null,2)+'\n');
console.log(scenes.map(s=>s.scene+' '+s.tempo+'×').join(' | '));
console.log('Placed '+timings.length+' lines in '+frameSeconds+' s');
