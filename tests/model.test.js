import test from 'node:test';
import assert from 'node:assert/strict';
import {suffix,summary,status,esc} from '../model.js';
test('Accountkürzel überschreiten Z und ZZ ohne Duplikate',()=>{assert.equal(suffix(25),'Z');assert.equal(suffix(26),'AA');assert.equal(suffix(29),'AD');assert.equal(suffix(701),'ZZ');assert.equal(suffix(702),'AAA');assert.equal(new Set(Array.from({length:1000},(_,i)=>suffix(i))).size,1000);});
test('Wiederholungen zählen pro Person ab dem zweiten Abschluss',()=>{assert.deepEqual(summary([{}, {started_at:'x'}, {started_at:'x',completed_runs:1},{started_at:'x',completed_runs:3}]),{unstarted:1,started:1,complete:2,runs:4,repeats:2});assert.equal(status({started_at:'x',completed_runs:2}),'Vollständig bearbeitet');});
test('Accountnamen und Anwendungstitel werden als Text ausgegeben',()=>{assert.equal(esc('<script>"&\''),'&lt;script&gt;&quot;&amp;&#39;');});
