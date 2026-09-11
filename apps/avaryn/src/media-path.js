const uuid='[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}';
const path=new RegExp(`^/storage/v1/object/(upload/sign|sign)/horse-media/(canonical|${uuid})/${uuid}/${uuid}/(original|thumbnail)$`,'i');
/** Rebase only this bucket's signed capability onto the pinned same-origin BFF. */
export function horseMediaPath(value,operation){
 if(typeof value!=='string'||!['upload','download'].includes(operation)||/[\\\\]|%2e|%2f|%5c/i.test(value)||/(?:^|\/)\.{1,2}(?:\/|\?|$)/.test(value))return null;
 let u;try{u=new URL(value,'https://avaryn.invalid');}catch{return null;}
 const m=u.pathname.match(path),keys=[...u.searchParams.keys()],token=u.searchParams.get('token');
 if(!['https:','http:'].includes(u.protocol)||u.username||u.password||u.hash||!m||m[1]!== (operation==='upload'?'upload/sign':'sign')||keys.length!==1||keys[0]!=='token'||!token||token.length>8192||!/^[A-Za-z0-9_.-]+$/.test(token))return null;
 return u.pathname+u.search;
}
