const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const {getFirestore}=require('firebase-admin/firestore');
const api=require('../index');
const db=getFirestore();
const auth=uid=>({uid,token:{email_verified:true,name:uid,email:`${uid}@example.test`}});
const call=(name,uid,data)=>api[name].run({auth:auth(uid),data});
const state=()=>({drac:[{id:1,nome:'Drác'}],tratamentos:[],medicamentos:[{id:1,nome:'Medicamento de teste',dose:'5',unidade:'mg',ativo:1}],horarios_medicamentos:[{id:1,medicamento_id:1,horario:'08:00'}]});
let g;
before(async()=>{
 g=(await call('createGroup','owner-test',{state:state()})).groupId;
 await call('finishMigration','owner-test',{groupId:g});
});
after(async()=>{await db.terminate();});
test('unauthenticated and unverified calls rejected',async()=>{
 await assert.rejects(api.createGroup.run({data:{state:state()}}),e=>e.code==='unauthenticated');
 await assert.rejects(api.createGroup.run({auth:{uid:'bad',token:{email_verified:false}},data:{state:state()}}),e=>e.code==='failed-precondition');
});
test('invitation is single-use and grants only target group',async()=>{
 const {code}=await call('createInvite','owner-test',{groupId:g});
 assert.equal((await call('acceptInvite','brother-test',{code})).groupId,g);
 await assert.rejects(call('acceptInvite','outsider-test',{code}),e=>e.code==='not-found');
 await assert.rejects(call('createInvite','outsider-test',{groupId:g}),e=>e.code==='permission-denied');
});
test('simultaneous administrations: one commit, one duplicate; retry is idempotent',async()=>{
 const c={action:'administer',medicationId:1,date:'27/09/2026',time:'08:00',expected:0,medicationVersion:1,clientAt:'2026-09-27T12:03:00.000Z'};
 const a={...c,operationId:'operation-owner-0000001'},b={...c,operationId:'operation-brother-00001'};
 const results=await Promise.all([call('mutate','owner-test',{groupId:g,command:a}),call('mutate','brother-test',{groupId:g,command:b})]);
 assert.equal(results.filter(r=>r.ok).length,1);assert.equal(results.filter(r=>r.status==='duplicate').length,1);
 const winner=results[0].ok?['owner-test',a]:['brother-test',b];
 await call('mutate',winner[0],{groupId:g,command:winner[1]});
 const events=await db.collection(`groups/${g}/events`).where('type','==','administer').get();assert.equal(events.size,1);
 const slot=(await db.doc(`groups/${g}/slots/1_27-09-2026_08-00`).get()).data();assert.equal(slot.version,1);
 const confirmed={...c,operationId:'confirmed-extra-0000001',expected:1,confirmedVersion:1};
 assert.equal((await call('mutate','owner-test',{groupId:g,command:confirmed})).ok,true);
 assert.equal((await db.collection(`groups/${g}/events`).where('type','==','administer').get()).size,2);
 const stale={...c,operationId:'stale-correction-000001',action:'undo',expected:1};
 assert.equal((await call('mutate','owner-test',{groupId:g,command:stale})).status,'conflict');
});
test('edits reject stale versions and deletion retains administrations and history',async()=>{
 const c={action:'save',table:'medicamentos',id:1,values:{dose:'2.5'},times:['09:00'],expected:1,operationId:'edit-medication-000001'};
 assert.equal((await call('mutate','owner-test',{groupId:g,command:c})).ok,true);
 assert.equal((await call('mutate','brother-test',{groupId:g,command:{...c,operationId:'edit-medication-000002'}})).status,'conflict');
 const event=(await db.doc(`groups/${g}/events/${c.operationId}`).get()).data();
 assert.equal(event.before.dose,'5');assert.equal(event.after.dose,'2.5');assert.deepEqual(event.previousTimes,['08:00']);
 await call('mutate','owner-test',{groupId:g,command:{action:'delete',table:'medicamentos',id:1,expected:2,operationId:'delete-medication-00001'}});
 assert.equal((await db.doc(`groups/${g}/slots/1_27-09-2026_08-00`).get()).exists,true);
 assert.equal((await db.doc(`groups/${g}/events/${c.operationId}`).get()).exists,true);
});
test('legacy import can resume without duplicating records',async()=>{
 const groupId=(await call('createGroup','migration-test',{state:state()})).groupId;
 const rows=[{id:3,medicamento_id:1,data:'26/09/2026',horario:'08:00',administrado:1,administrado_em:'2026-09-26T08:03:00'}];
 await call('importLegacy','migration-test',{groupId,rows});await call('importLegacy','migration-test',{groupId,rows});
 const events=await db.collection(`groups/${groupId}/events`).where('type','==','legacy').get();assert.equal(events.size,1);assert.equal(events.docs[0].data().actor.uid,null);
 await call('finishMigration','migration-test',{groupId});
 await assert.rejects(call('importLegacy','migration-test',{groupId,rows}),e=>e.code==='permission-denied');
});
