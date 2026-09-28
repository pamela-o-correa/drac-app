const {test,before,after}=require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc,collection,getDocs}=require('firebase/firestore');
let env;
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-drac',firestore:{rules:fs.readFileSync('../firestore.rules','utf8')}});
 await env.withSecurityRulesDisabled(async ctx=>{
  const db=ctx.firestore();
  await setDoc(doc(db,'groups/one'),{members:['pamela']});
  await setDoc(doc(db,'groups/one/pets/drac'),{version:1});
  await setDoc(doc(db,'groups/one/events/action'),{actor:{uid:'pamela'}});
  await setDoc(doc(db,'users/pamela'),{groupId:'one'});
  await setDoc(doc(db,'invites/secret'),{groupId:'one'});
 });
});
after(async()=>{await env.cleanup();});
test('member can stream shared data',async()=>{const db=env.authenticatedContext('pamela',{email_verified:true}).firestore();await assertSucceeds(getDoc(doc(db,'groups/one/pets/drac')));await assertSucceeds(getDocs(collection(db,'groups/one/events')));});
test('outsider and anonymous cannot read pet or history',async()=>{for(const ctx of [env.unauthenticatedContext(),env.authenticatedContext('stranger',{email_verified:true})]){await assertFails(getDoc(doc(ctx.firestore(),'groups/one/pets/drac')));await assertFails(getDocs(collection(ctx.firestore(),'groups/one/events')));}});
test('unverified member is denied',async()=>{await assertFails(getDoc(doc(env.authenticatedContext('pamela',{email_verified:false}).firestore(),'groups/one/pets/drac')));});
test('even members cannot forge history, doses, invitations or membership',async()=>{
 const db=env.authenticatedContext('pamela',{email_verified:true}).firestore();
 for(const p of ['groups/one','groups/one/pets/drac','groups/one/events/fake','groups/one/slots/fake','invites/secret','users/pamela'])await assertFails(setDoc(doc(db,p),{fake:true}));
 await assertFails(getDoc(doc(db,'invites/secret')));
});
test('private user profile is isolated',async()=>{await assertFails(getDoc(doc(env.authenticatedContext('stranger',{email_verified:true}).firestore(),'users/pamela')));});
