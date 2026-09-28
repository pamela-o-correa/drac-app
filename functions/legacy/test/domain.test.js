const {test}=require('node:test');
const assert=require('node:assert/strict');
const {doseDecision,slotKey,validateState}=require('../domain');
test('same slot identity survives offline retries',()=>assert.equal(slotKey(4,'27/09/2026','08:00'),'4_27-09-2026_08-00'));
test('invalid dates and times rejected',()=>{assert.throws(()=>slotKey(1,'31/02/2026','08:00'));assert.throws(()=>slotKey(1,'27/09/2026','24:00'));});
test('concurrent second administration requires review',()=>assert.equal(doseDecision({version:1,administrado:1},{expected:0,action:'administer'}),'duplicate'));
test('explicit confirmation tied to exact version',()=>{assert.equal(doseDecision({version:2,administrado:1},{expected:2,confirmedVersion:1,action:'administer'}),'duplicate');assert.equal(doseDecision({version:2,administrado:1},{expected:2,confirmedVersion:2,action:'administer'}),'ok');});
test('stale correction cannot erase another administration',()=>assert.equal(doseDecision({version:2,administrado:1},{expected:1,action:'undo'}),'conflict'));
test('new slot permits initial administration',()=>assert.equal(doseDecision(null,{expected:0,action:'administer'}),'ok'));
test('migration rejects dangling schedules and duplicate ids',()=>{
 const state={drac:[],tratamentos:[],medicamentos:[{id:1,nome:'Exemplo',dose:'1',ativo:1}],horarios_medicamentos:[{id:1,medicamento_id:2,horario:'08:00'}]};
 assert.throws(()=>validateState(state));
 state.horarios_medicamentos=[];state.medicamentos.push({...state.medicamentos[0]});assert.throws(()=>validateState(state));
});
