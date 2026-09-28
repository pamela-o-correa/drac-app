'use strict';
const crypto = require('node:crypto');
const tables = ['drac','tratamentos','medicamentos','horarios_medicamentos'];
function fail(message) { const e = new Error(message); e.code = 'invalid-argument'; throw e; }
function text(value, max = 4000) { if(typeof value !== 'string' || value.length > max) fail('Texto inválido.'); return value.trim(); }
function id(value) { if(!Number.isSafeInteger(value) || value < 1 || value > 2147483647) fail('Identificador inválido.'); return value; }
function date(value) {
  if (!/^\d{2}\/\d{2}\/\d{4}$/.test(value || '')) fail('Data inválida.');
  const [d,m,y] = value.split('/').map(Number), parsed = new Date(Date.UTC(y,m-1,d));
  if(parsed.getUTCFullYear()!==y || parsed.getUTCMonth()!==m-1 || parsed.getUTCDate()!==d) fail('Data inválida.');
  return value;
}
function time(value) { if(!/^([01]\d|2[0-3]):[0-5]\d$/.test(value || '')) fail('Horário inválido.'); return value; }
function slotKey(med,data,horario) { return `${id(med)}_${date(data).replaceAll('/','-')}_${time(horario).replace(':','-')}`; }
const fields = {
 drac: ['nome','foto','peso','nascimento','observacoes'],
 tratamentos:['titulo','veterinario','data_inicio','data_fim','orientacoes','observacoes','ativo'],
 medicamentos:['nome','dose','unidade','instrucoes','data_inicio','data_fim','cor','icone','ativo'],
 horarios_medicamentos:['medicamento_id','horario'],
};
function clean(table, value) {
 if(!fields[table] || !value || typeof value !== 'object') fail('Dados inválidos.');
 const result = {};
 for(const [key,val] of Object.entries(value)) {
   if(!fields[table].includes(key)) continue;
   if(val === null) {result[key]=null; continue;}
   if(['peso','cor','ativo','medicamento_id'].includes(key)) {
     if(typeof val !== 'number' || !Number.isFinite(val)) fail('Número inválido.');
     if(key==='ativo' && ![0,1].includes(val)) fail('Status inválido.');
     if(key==='medicamento_id') id(val);
     result[key]=val;
   } else { result[key]=text(val); }
 }
 for(const key of ['data_inicio','data_fim','nascimento']) if(result[key]) date(result[key]);
 if(result.horario) time(result.horario);
 return result;
}
function validateState(state) {
 for(const table of tables) {
   if(!Array.isArray(state[table]) || state[table].length>1000) fail('Limite de cadastros excedido.');
   const ids=new Set();
   state[table]=state[table].map(r=>{id(r.id); if(ids.has(r.id)) fail('ID repetido.'); ids.add(r.id); return {id:r.id,...clean(table,r)};});
 }
 for(const r of state.drac) if(!r.nome) fail('Nome do animal obrigatório.');
 for(const r of state.tratamentos) if(!r.titulo) fail('Título do tratamento obrigatório.');
 if(state.drac.length>1) fail('Este grupo suporta um perfil de animal.');
 for(const m of state.medicamentos) if(!m.nome || !m.dose) fail('Nome e dose são obrigatórios.');
 for(const h of state.horarios_medicamentos) {
   time(h.horario);
   if(!state.medicamentos.some(m=>m.id===h.medicamento_id)) fail('Horário sem medicamento.');
 }
 if(Buffer.byteLength(JSON.stringify(state))>600000) fail('Cadastros excedem o limite seguro. Exporte os dados antes de ampliar o grupo.');
 return state;
}
function doseDecision(slot, command) {
 const version=slot?.version || 0;
 if(command.expected !== version) return slot?.administrado===1 && command.action==='administer' ? 'duplicate' : 'conflict';
 if(command.action==='administer' && slot?.administrado===1 && command.confirmedVersion !== version) return 'duplicate';
 return 'ok';
}
function hash(value) { return crypto.createHash('sha256').update(value).digest('hex'); }
module.exports={tables,text,id,date,time,slotKey,clean,validateState,doseDecision,hash};
