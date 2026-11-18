import fs from 'node:fs';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const rows=read('data/results.json');
const spectra=read('data/spectrum.json');
const edit=read('src/edit.json');
const qa='build/review/';
const streams=read(qa+'streams.json');
const [v,a]=streams.streams;
const expected=Math.round(edit.endBar*240/edit.bpm*edit.fps);
assert(v.codec_name==='h264'&&v.width===1920&&v.height===1080&&v.avg_frame_rate===edit.fps+'/1'&&v.pix_fmt==='yuv420p');
assert.equal(+v.nb_read_frames,expected);
assert.equal(+v.nb_frames,expected);
assert(a.codec_name==='aac'&&a.channels===2&&a.sample_rate==='48000');
assert(+a.start_time===0&&+v.start_time===0&&Math.abs(+a.duration-+v.duration)<0.025);
assert(Math.abs(+streams.format.duration-expected/edit.fps)<0.025);
assert.equal(fs.statSync(qa+'decode.log').size,0);
assert.equal(rows.standings.length,17);
assert.equal(rows.totalRounds,340);
assert.equal(rows.totalFailures,0);
const close=(a,b)=>assert(Math.abs(a-b)<1e-8);
for(const e of rows.entries){
  const m=e.scores.reduce((a,b)=>a+b,0)/e.scores.length;
  close(m,e.mean);close(e.std,Math.sqrt(e.scores.reduce((a,b)=>a+(b-m)**2,0)/19));
  close(Math.min(...e.scores),e.min);close(Math.max(...e.scores),e.max);
  const ranked=rows.standings.find(r=>r.number===e.number);
  close(ranked.mean,e.mean);assert.equal(ranked.rank,e.rank);assert.equal(e.scores.length,20);
}
assert(rows.paired.astraWins===10&&rows.paired.fableWins===10);
assert(rows.spread.below100===8&&rows.spread.above700===6);
assert(spectra.selection==='round_01'&&spectra.units==='m/sqrt(Hz)');
close(spectra.frequency[0],0.01);close(spectra.frequency.at(-1),100);
const relative=Object.fromEntries(['n13','n16','n17'].map(k=>[k,spectra.band08to12[k][0]/spectra.band08to12.baseline[0]]));
assert(relative.n13<0.01&&relative.n16<0.01&&Math.round(relative.n17)===49);
const subs=fs.readFileSync('out/AVIS3-Plus-1118.zh-Hans.srt','utf8').trim().split(/\r?\n\r?\n/);
assert.deepEqual(subs.map(s=>s.split('\n').slice(2).join(' ')),edit.scenes.flatMap(s=>s.cues.map(c=>c.text)));
const time=s=>s.split(/[:,]/).map(Number).reduce((n,v,i)=>n*(i===3?1000:60)+v,0);
let previous=0;
for(const sub of subs){
  const [start,end]=sub.split('\n')[1].split(' --> ').map(time);
  assert(start>=previous&&end>start);previous=end;
}
assert(Math.abs(previous-expected/edit.fps*1000)<34);
const loudnessText=fs.readFileSync(qa+'loudness.log','utf8');
const loud=JSON.parse(loudnessText.slice(loudnessText.lastIndexOf('{'),loudnessText.lastIndexOf('}')+1));
assert(+loud.input_tp<0&&Number.isFinite(+loud.input_i));
const silence=fs.readFileSync(qa+'silence.log','utf8').split('\n').filter(l=>l.includes('silence_start:'));
function wav(file){
  const b=fs.readFileSync(file);
  assert(b.toString('ascii',0,4)==='RIFF'&&b.toString('ascii',8,12)==='WAVE');
  for(let p=12;p+8<=b.length;){
    const key=b.toString('ascii',p,p+4),len=b.readUInt32LE(p+4);
    if(key==='fmt '){assert(b.readUInt16LE(p+10)===2&&b.readUInt32LE(p+12)===44100&&b.readUInt16LE(p+22)===16);}
    if(key==='data')return new Int16Array(b.buffer,b.byteOffset+p+8,Math.floor(len/2));
    p+=8+len+(len%2);
  }
  throw Error('Missing PCM data in '+file);
}
const stem=wav('assets/score.wav'), encoded=wav(qa+'decoded-mix.wav');
function correlation(sec,ch){
  const first=Math.round(sec*44100);let dot=0,xx=0,yy=0;
  for(let j=0;j<22050;j++){const i=(first+j)*2+ch, x=stem[i],y=encoded[i];dot+=x*y;xx+=x*x;yy+=y*y;}
  return dot/Math.sqrt(xx*yy);
}
const alignment=edit.scenes.map(s=>{
  const t=s.bar*240/edit.bpm+2;
  return {scene:s.id,left:correlation(t,0),right:correlation(t,1)};
});
assert(alignment.every(r=>r.left>0.96&&r.right>0.96),'The AAC mix should correlate with the aligned edit stem in every scene.');
const movie=fs.readFileSync('out/AVIS3-Plus-1118.mp4');
const tags=[];
for(let p=0;p+8<=movie.length;){
  const n=movie.readUInt32BE(p);
  tags.push(movie.toString('ascii',p+4,p+8));
  if(n===0)break;
  assert(n>7);
  p+=n;
}
assert(tags.indexOf('moov')>=0&&tags.indexOf('moov')<tags.indexOf('mdat'));
const summary={title:edit.title,sha256:crypto.createHash('sha256').update(movie).digest('hex'),bytes:movie.length,durationSeconds:+v.duration,
  frames:expected,decodedVideoFrames:+v.nb_read_frames,video:v.codec_name+' 1920x1080 '+v.avg_frame_rate,audio:a.codec_name+' 48000 Hz stereo',
  integratedLUFS:+loud.input_i,truePeakDBTP:+loud.input_tp,loudnessRangeLU:+loud.input_lra,detectedSilencesOver06s:silence.length,
  captionCues:subs.length,sceneAlignedAudio:alignment,relativeBandRms:relative,totalRounds:rows.totalRounds};
fs.writeFileSync(qa+'delivery.json',JSON.stringify(summary,null,2)+'\n');
console.log(JSON.stringify(summary,null,2));
