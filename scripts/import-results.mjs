import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const arena = process.env.ARENA_REPO || path.resolve(root, '../../avis3-arena');
const prefix = 'evaluations/Evaluation-1108/extensions/';
const fable = ['a64741a', 'official-016-20261117'];
const nov18 = ['1e359f2', 'official-013-017-20261118'];
function snapshot([commit, dir], file) {
  return JSON.parse(execFileSync('git', ['-C', arena, 'show', commit + ':' + prefix + dir + '/' + file], {encoding:'utf8'}));
}
const board = snapshot(nov18, 'leaderboard-17.json');
const fCheck = snapshot(fable, 'verification.json');
const nCheck = snapshot(nov18, 'verification.json');
assert(fCheck.same_private_scenes_and_config && nCheck.same_private_scenes_and_config && nCheck.prior_15_results_unchanged);
assert.equal(board.length, 17);
const standings = board.map((r, i) => {
  assert.equal(r.rank, i + 1);
  assert(!r.stale && r.failed_rounds === 0 && (i === 0 || board[i-1].mean >= r.mean));
  return {number:Number(r.competitor_id.slice(-3)), rank:r.rank, name:r.name, mean:r.mean};
});
assert.equal(new Set(standings.map(r=>r.number)).size, 17);
const participants = [snapshot(fable,'manifest.json').participant, ...snapshot(nov18,'manifest.json').participants];
function equal(a,b) { assert(Math.abs(a-b)<1e-8, a + ' differs from ' + b); }
const entries = participants.map(p => {
  const result = p.number === 16 ? snapshot(fable,'result.json') : snapshot(nov18,'results/' + p.id + '.json');
  const audit = p.number === 16 ? fCheck : nCheck.participants.find(r=>r.number===p.number);
  const row = standings.find(r=>r.number===p.number);
  assert.equal(result.id,audit.run_id);
  assert.equal(result.name,p.name);
  assert.equal(row.name,p.name);
  assert.equal(result.rounds.length,20);
  const scores = result.rounds.map((r,i) => {
    assert(r.index===i+1 && r.status==='completed' && r.valid_samples===10000000 && Number.isFinite(r.score));
    return r.score;
  });
  const mean=scores.reduce((a,b)=>a+b,0)/scores.length;
  const std=Math.sqrt(scores.reduce((s,v)=>s+(v-mean)**2,0)/(scores.length-1));
  for (const [k,v] of Object.entries({mean,std,min:Math.min(...scores),max:Math.max(...scores)})) {
    equal(v,result[k]); equal(v,audit[k]);
  }
  equal(mean,row.mean);
  assert(result.failed_rounds===0 && audit.completed_rounds===20);
  return {number:p.number, name:p.name, platform:p.harness, date:result.completed_at.slice(0,10), rank:row.rank,
    mean:result.mean,std:result.std,min:result.min,max:result.max,failed:result.failed_rounds,scores};
});
const a=entries.find(r=>r.number===13), f=entries.find(r=>r.number===16), s=entries.find(r=>r.number===17);
const delta=a.scores.map((v,i)=>v-f.scores[i]);
const paired={delta,mean:delta.reduce((x,y)=>x+y,0)/20,astraWins:delta.filter(v=>v>0).length,fableWins:delta.filter(v=>v<0).length};
const spread={below100:s.scores.filter(v=>v<100).length,above700:s.scores.filter(v=>v>700).length};
const frozen=JSON.parse(execFileSync('git',['-C',arena,'show','1e359f2:evaluations/Evaluation-1108/website/evaluation-1108.json'],{encoding:'utf8',maxBuffer:8e6}));
const base=frozen.summary ?? frozen;
const baseRounds=base.total_rounds ?? (Array.isArray(frozen.participants) ? frozen.participants.reduce((n,p)=>n+(p.rounds?.length||p.scores?.length||0),0) : undefined);
assert.equal(baseRounds,280, 'original published round count');
const film={batch:'Evaluation-1108',asOf:'2026-11-18',totalRounds:baseRounds+entries.reduce((n,e)=>n+e.scores.length,0),
  totalFailures:board.reduce((n,e)=>n+e.failed_rounds,0),entries,standings,paired,spread};
fs.mkdirSync(path.join(root,'data'),{recursive:true});
fs.writeFileSync(path.join(root,'data/results.json'),JSON.stringify(film,null,2)+'\n');
console.log(entries.map(r=>r.number+' '+r.name+' #'+r.rank+' '+r.mean.toFixed(6)).join('\n'),paired.astraWins,paired.fableWins,spread);
