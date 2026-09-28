'use strict';
const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {onDocumentCreated}=require('firebase-functions/v2/firestore');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore,FieldValue,Timestamp}=require('firebase-admin/firestore');
const {getMessaging}=require('firebase-admin/messaging');
const crypto=require('node:crypto');
const d=require('./domain');
initializeApp();
const db=getFirestore();
const region='southamerica-east1';
function requireUser(req) {
 if(!req.auth) throw new HttpsError('unauthenticated','Entre na sua conta.');
 if(!req.auth.token.email_verified) throw new HttpsError('failed-precondition','Confirme seu e-mail antes de compartilhar.');
 return req.auth.uid;
}
function gid(value) {if(!/^[a-zA-Z0-9_-]{1,128}$/.test(value || '')) throw new HttpsError('invalid-argument','Grupo inválido.'); return value;}
function actor(req) {return {uid:req.auth.uid,name:String(req.auth.token.name || req.auth.token.email || 'Usuário').slice(0,100)};}
function callable(fn) {return onCall({region,maxInstances:10},async req=>{requireUser(req); try{return await fn(req);}catch(e){if(e instanceof HttpsError)throw e; if(e.code==='invalid-argument')throw new HttpsError(e.code,e.message); console.error(e); throw new HttpsError('internal','Não foi possível concluir. Tente novamente.');}});}
async function member(tx,group,uid) {
 const ref=db.doc(`groups/${group}`), snap=await tx.get(ref);
 if(!snap.exists || !snap.data().members.includes(uid)) throw new HttpsError('permission-denied','Você não pertence a este grupo.');
 return snap.data();
}
const stateRef=g=>db.doc(`groups/${g}/pets/drac`);
function event(tx,g,key,req,data) {tx.create(db.doc(`groups/${g}/events/${key}`),{...data,actor:actor(req),serverAt:FieldValue.serverTimestamp()});}
exports.createGroup=callable(async req=>{
 const uid=req.auth.uid, user=db.doc(`users/${uid}`), group=db.collection('groups').doc();
 const state=d.validateState({...req.data.state,version:1});
 return db.runTransaction(async tx=>{
  const old=await tx.get(user);
  if(old.data()?.groupId) return {groupId:old.data().groupId};
  tx.create(group,{owner:uid,members:[uid],createdAt:FieldValue.serverTimestamp(),migrationOpen:true});
  tx.create(stateRef(group.id),state);
  tx.set(user,{groupId:group.id,name:actor(req).name},{merge:true});
  event(tx,group.id,'created',req,{type:'migration',summary:'Criou o grupo e importou os cadastros locais.',before:null,after:state});
  return {groupId:group.id};
 });
});
exports.importLegacy=callable(async req=>{
 const g=gid(req.data.groupId), rows=req.data.rows;
 if(!Array.isArray(rows)||rows.length>100) throw new HttpsError('invalid-argument','Envie até 100 registros.');
 return db.runTransaction(async tx=>{
  const group=await member(tx,g,req.auth.uid);
  if(group.owner!==req.auth.uid || !group.migrationOpen) throw new HttpsError('permission-denied','Importação encerrada.');
  const importedState=(await tx.get(stateRef(g))).data();
  const refs=rows.map(r=>db.doc(`groups/${g}/events/legacy-${d.id(r.id)}`));
  const existing=refs.length?await tx.getAll(...refs):[];
  const slotRefs=rows.map(r=>db.doc(`groups/${g}/slots/${d.slotKey(r.medicamento_id,r.data,r.horario)}`));
  const slots=slotRefs.length?await tx.getAll(...slotRefs):[];
  const written=new Map();
  rows.forEach((r,i)=>{
   if(existing[i].exists)return;
   const medication=importedState.medicamentos.find(m=>m.id===r.medicamento_id);
   const values={medicationName:medication?.nome || `Medicamento ${r.medicamento_id}`,dose:'não registrada no histórico antigo',unidade:'',medicamento_id:d.id(r.medicamento_id),data:d.date(r.data),horario:d.time(r.horario),administrado:r.administrado===1?1:0,administrado_em:r.administrado_em || null,observacao:r.observacao || null,actorName:'Registro local anterior — responsável desconhecido',actorUid:null,version:1};
   tx.create(refs[i],{type:'legacy',summary:`${values.administrado===1?'Administração':'Registro não marcado'} importado: ${values.medicationName} — ${values.data} às ${values.horario}`,actor:{uid:null,name:values.actorName},clientAt:values.administrado_em,before:null,after:values,serverAt:FieldValue.serverTimestamp()});
   // Importação preserva todos os eventos, sem repetir o estado da mesma dose.
   const previous=written.get(slotRefs[i].path) || slots[i].data();
   if(!previous || (values.administrado===1 && previous.administrado!==1)) {tx.set(slotRefs[i],values);written.set(slotRefs[i].path,values);}
  });
  return {ok:true};
 });
});
exports.finishMigration=callable(async req=>{
 const g=gid(req.data.groupId);
 return db.runTransaction(async tx=>{const group=await member(tx,g,req.auth.uid);if(group.owner!==req.auth.uid)throw new HttpsError('permission-denied','Somente quem criou o grupo.');tx.update(db.doc(`groups/${g}`),{migrationOpen:false});return {ok:true};});
});
exports.createInvite=callable(async req=>{
 const g=gid(req.data.groupId), code=crypto.randomBytes(16).toString('hex');
 await db.runTransaction(async tx=>{
  const group=await member(tx,g,req.auth.uid);
  if(group.owner!==req.auth.uid || group.migrationOpen)throw new HttpsError('failed-precondition','Conclua a importação; somente o responsável pode convidar.');
  const previous=group.inviteHash;
  if(previous)tx.delete(db.doc(`invites/${previous}`));
  tx.create(db.doc(`invites/${d.hash(code)}`),{groupId:g,expiresAt:Timestamp.fromMillis(Date.now()+86400000)});
  tx.update(db.doc(`groups/${g}`),{inviteHash:d.hash(code)});
 });
 return {code};
});
exports.acceptInvite=callable(async req=>{
 const code=d.text(req.data.code,64).toLowerCase();
 if(!/^[a-f0-9]{32}$/.test(code))throw new HttpsError('invalid-argument','Código inválido.');
 return db.runTransaction(async tx=>{
  const inviteRef=db.doc(`invites/${d.hash(code)}`), invite=await tx.get(inviteRef), userRef=db.doc(`users/${req.auth.uid}`), user=await tx.get(userRef);
  if(user.data()?.groupId)throw new HttpsError('failed-precondition','Sua conta já está vinculada a um grupo.');
  if(!invite.exists || invite.data().expiresAt.toMillis()<Date.now())throw new HttpsError('not-found','Convite inválido, usado ou expirado.');
  const g=invite.data().groupId, groupRef=db.doc(`groups/${g}`), group=await tx.get(groupRef);
  if(group.data().members.length>=20)throw new HttpsError('resource-exhausted','Grupo completo.');
  tx.update(groupRef,{members:FieldValue.arrayUnion(req.auth.uid)});
  tx.set(userRef,{groupId:g,name:actor(req).name},{merge:true});
  tx.delete(inviteRef);
  event(tx,g,`joined-${req.auth.uid}`,req,{type:'member',summary:'Entrou no grupo.',before:null,after:null});
  return {groupId:g};
 });
});
exports.mutate=callable(async req=>{
 const g=gid(req.data.groupId), c=req.data.command, key=d.text(c.operationId,80);
 if(!/^[a-zA-Z0-9_-]{16,80}$/.test(key))throw new HttpsError('invalid-argument','Operação inválida.');
 return db.runTransaction(async tx=>{
  const group=await member(tx,g,req.auth.uid);
  if(group.migrationOpen)throw new HttpsError('failed-precondition','Conclua a importação primeiro.');
  const eventRef=db.doc(`groups/${g}/events/${key}`), prev=await tx.get(eventRef);
  if(prev.exists) {if(prev.data().actor.uid!==req.auth.uid)throw new HttpsError('permission-denied','Operação de outro usuário.');return {ok:true};}
  const stateSnap=await tx.get(stateRef(g)), state=stateSnap.data();
  if(['administer','undo'].includes(c.action)) {
   const ref=db.doc(`groups/${g}/slots/${d.slotKey(c.medicationId,c.date,c.time)}`), snap=await tx.get(ref), before=snap.data() || null;
   const med=state.medicamentos.find(m=>m.id===c.medicationId);
   if(!med)throw new HttpsError('not-found','Medicamento excluído.');
   const decision=d.doseDecision(before,c);
   if(decision!=='ok')return {status:decision,slot:before};
   if(c.medicationVersion!==state.version) return {status:'conflict',message:'O tratamento ou medicamento mudou. Confira os dados antes de registrar.'};
   const after={medicamento_id:c.medicationId,data:c.date,horario:c.time,administrado:c.action==='administer'?1:0,administrado_em:c.clientAt,actorName:actor(req).name,actorUid:req.auth.uid,version:(before?.version||0)+1,medicationName:med.nome,dose:med.dose,unidade:med.unidade||'',serverAt:FieldValue.serverTimestamp()};
   if(typeof c.clientAt!=='string'||!Number.isFinite(Date.parse(c.clientAt)))throw new HttpsError('invalid-argument','Data da ação inválida.');
   tx.set(ref,after);
   event(tx,g,key,req,{type:c.action,summary:`${c.action==='administer'?'Administrou':'Corrigiu o registro de'} ${med.nome} (${med.dose} ${med.unidade||''}) — ${c.date} às ${c.time}`,clientAt:c.clientAt,before,after});
   return {ok:true};
  }
  if(c.expected!==state.version)return {status:'conflict',message:'Outra pessoa alterou os dados. Reabra a tela e confira antes de salvar.'};
  const table=c.table;
  if(!['drac','tratamentos','medicamentos'].includes(table))throw new HttpsError('invalid-argument','Tabela inválida.');
  const before=state[table].find(r=>r.id===c.id)||null;
  if(c.id && !before)throw new HttpsError('not-found','Registro não encontrado.');
  let after=null;
  if(c.action==='delete') {
   if(table!=='medicamentos')throw new HttpsError('invalid-argument','Exclusão inválida.');
   state[table]=state[table].filter(r=>r.id!==c.id);
   state.horarios_medicamentos=state.horarios_medicamentos.filter(h=>h.medicamento_id!==c.id);
  } else if(c.action==='save') {
   const nextId=c.id || (state.nextId || Math.max(0,...d.tables.flatMap(t=>state[t].map(r=>r.id)))+1);
   after={...before,...d.clean(table,c.values),id:nextId};
   if(table!=='drac' && after.ativo==null)after.ativo=1;
   state[table]=[...state[table].filter(r=>r.id!==nextId),after];
   state.nextId=Math.max(state.nextId||1,nextId+1);
   if(table==='medicamentos' && c.times) {
    if(!Array.isArray(c.times)||!c.times.length||c.times.length>48)throw new HttpsError('invalid-argument','Horários inválidos.');
    state.horarios_medicamentos=state.horarios_medicamentos.filter(h=>h.medicamento_id!==nextId);
    for(const time of new Set(c.times))state.horarios_medicamentos.push({id:state.nextId++,medicamento_id:nextId,horario:d.time(time)});
   }
  } else throw new HttpsError('invalid-argument','Ação inválida.');
  const oldTimes=stateSnap.data().horarios_medicamentos.filter(h=>h.medicamento_id===c.id).map(h=>h.horario);
  state.version++;
  d.validateState(state);
  tx.set(stateRef(g),state);
  const labels={dose:'dose',unidade:'unidade',instrucoes:'instruções/observações',nome:'nome',data_inicio:'início',data_fim:'fim',ativo:'situação',orientacoes:'orientações',observacoes:'observações',veterinario:'veterinário',peso:'peso',nascimento:'nascimento',titulo:'título',foto:'foto'};
  const changed=before && after ? Object.keys(labels).filter(k=>before[k]!==after[k]) : [];
  const timesChanged=c.times && JSON.stringify(oldTimes)!==JSON.stringify(c.times);
  const detail=[...changed.map(k=>labels[k]),...(timesChanged?['horários/frequência']:[])].join(', ');
  event(tx,g,key,req,{type:c.action,notify:c.action==='delete'||!before||changed.length>0||!!timesChanged,summary:`${c.action==='delete'?'Excluiu':before?'Alterou':'Adicionou'} ${after?.nome||before?.nome||after?.titulo||'perfil/tratamento'}${detail?' — '+detail:''}`,before,after,previousTimes:oldTimes,newTimes:c.times||null});
  return {ok:true,id:after?.id||c.id};
 });
});
exports.registerDevice=callable(async req=>{
 const token=d.text(req.data.token,4096), uid=req.auth.uid;
 await db.doc(`users/${uid}/devices/${d.hash(token)}`).set({token,updatedAt:FieldValue.serverTimestamp()});return {ok:true};
});
exports.unregisterDevice=callable(async req=>{await db.doc(`users/${req.auth.uid}/devices/${d.hash(d.text(req.data.token,4096))}`).delete();return {ok:true};});
exports.notifyChange=onDocumentCreated({document:'groups/{groupId}/events/{eventId}',region,retry:true},async ev=>{
 const data=ev.data.data(); if(['legacy','migration'].includes(data.type)||data.notify===false)return;
 const group=(await db.doc(`groups/${ev.params.groupId}`).get()).data(); if(!group)return;
 const devices=[];
 for(const uid of group.members.filter(uid=>uid!==data.actor.uid)) {
  const list=await db.collection(`users/${uid}/devices`).get();list.forEach(doc=>devices.push(doc));
 }
 if(!devices.length)return;
 // FCM is at-least-once; a stable Android tag replaces repeated delivery of one event.
 const result=await getMessaging().sendEachForMulticast({tokens:devices.map(x=>x.data().token),notification:{title:'Drác • cuidado compartilhado',body:`${data.actor.name}: ${data.summary}`.slice(0,900)},data:{groupId:ev.params.groupId,eventId:ev.params.eventId},android:{priority:'high',notification:{tag:ev.params.eventId,channelId:'compartilhamento',icon:'ic_stat_drac'}}});
 let transient=false;
 await Promise.all(result.responses.map(async(r,i)=>{if(r.success)return;if(['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(r.error.code))await devices[i].ref.delete();else transient=true;}));
 if(transient)throw new Error('Falha temporária no envio FCM');
});
