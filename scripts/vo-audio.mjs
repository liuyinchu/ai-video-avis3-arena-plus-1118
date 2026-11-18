import fs from 'node:fs';
export function readWav(path){
  const b=fs.readFileSync(path);
  if(b.toString('ascii',0,4)!=='RIFF'||b.toString('ascii',8,12)!=='WAVE')throw Error('Invalid WAV '+path);
  let rate=0,channels=0;
  for(let p=12;p+8<=b.length;){
    const k=b.toString('ascii',p,p+4),n=b.readUInt32LE(p+4);
    if(p+8+n>b.length)throw Error('Truncated WAV '+path);
    if(k==='fmt '){
      if(b.readUInt16LE(p+8)!==1||b.readUInt16LE(p+22)!==16)throw Error('Expected PCM16 '+path);
      channels=b.readUInt16LE(p+10);rate=b.readUInt32LE(p+12);
    }
    if(k==='data'){
      const pcm=new Int16Array(b.buffer,b.byteOffset+p+8,n/2);
      if(!rate||!channels||pcm.length%channels!==0)throw Error('Invalid sample dimensions '+path);
      return {pcm,rate,channels,frames:pcm.length/channels};
    }
    p+=8+n+n%2;
  }
  throw Error('Missing PCM '+path);
}
export function writeWav(path,pcm,rate,channels){
  const b=Buffer.alloc(44+pcm.length*2);
  b.write('RIFF',0);b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);
  b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(channels,22);
  b.writeUInt32LE(rate,24);b.writeUInt32LE(rate*channels*2,28);b.writeUInt16LE(channels*2,32);
  b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(pcm.length*2,40);
  Buffer.from(pcm.buffer,pcm.byteOffset,pcm.length*2).copy(b,44);fs.writeFileSync(path,b);
}
export function speechBounds(w){
  if(w.channels!==1)throw Error('Expected mono voice');
  const hop=Math.round(w.rate*0.01),levels=[];
  for(let i=0;i<w.frames;i+=hop){
    const end=Math.min(i+hop,w.frames);let energy=0;
    for(let k=i;k<end;k++)energy+=(w.pcm[k]/32768)**2;
    levels.push(10*Math.log10(energy/(end-i)+1e-15));
  }
  const sorted=levels.slice().sort((a,b)=>a-b);
  const threshold=Math.max(-55,sorted[Math.floor(sorted.length*0.88)]-39);
  const first=levels.findIndex(v=>v>threshold),last=levels.findLastIndex(v=>v>threshold);
  if(first<0||last<=first)throw Error('Silent voice segment');
  const start=Math.max(0,first*hop-Math.round(w.rate*0.075));
  const end=Math.min(w.frames,(last+1)*hop+Math.round(w.rate*0.115));
  return {start,end,seconds:(end-start)/w.rate,threshold};
}

// Shorten long, quiet internal pauses on time-constrained shots. Keep both breaths and word edges.
export function compactPauses(w,start,end) {
  const hop=Math.round(w.rate*.01),keep=Math.round(w.rate*.38),minimum=Math.round(w.rate*.50);
  const cuts=[];let begin=null;
  for(let p=start;p<=end;p+=hop){
    const bound=Math.min(p+hop,end);let energy=0,peak=0;
    for(let k=p;k<bound;k++){const v=w.pcm[k]/32768;energy+=v*v;peak=Math.max(peak,Math.abs(v));}
    const quiet=bound>p&&energy/(bound-p)<10**(-48/10)&&peak<10**(-36/20);
    if(quiet&&begin===null)begin=p;
    if((!quiet||bound===end)&&begin!==null){
      const stop=quiet?bound:p;
      if(begin>start&&stop<end&&stop-begin>=minimum){
        cuts.push([begin+Math.round(keep/2),stop-Math.floor(keep/2)]);
      }
      begin=null;
    }
  }
  if(!cuts.length)return null;
  const removed=cuts.reduce((n,[a,b])=>n+b-a,0);
  const pcm=new Int16Array(end-start-removed);
  let from=start,to=0;
  for(const [a,b] of cuts){pcm.set(w.pcm.subarray(from,a),to);to+=a-from;from=b;}
  pcm.set(w.pcm.subarray(from,end),to);
  return {pcm,removed:removed/w.rate};
}
