const fail=(code,message)=>Object.assign(new Error(message),{code,userMessage:message});
const stale=()=>fail('STALE_CONTEXT','Open het fotoformulier opnieuw om een foto te kiezen.');
const unavailable=()=>fail('NATIVE_PHOTO_UNAVAILABLE','De camera kon niet worden geopend. Probeer opnieuw of kies een bestaande foto.');
const recovery='Open het fotoformulier opnieuw om een foto te kiezen. Er is niets opgeslagen.';

/** Only Capacitor's local file bridge may supply a captured image. */
export function nativePhotoUrl(raw,platform){
 const prefix=platform==='ios'?'capacitor://localhost/_capacitor_file_/':platform==='android'?'https://localhost/_capacitor_file_/':null;
 if(!prefix||typeof raw!=='string'||!raw.startsWith(prefix)||raw.length>8192||/[?#\\\s]/.test(raw))return null;
 try{
  const uri=new URL(raw),path=decodeURIComponent(raw.slice(prefix.length));
  if(!path||uri.username||uri.password||uri.port||/[\\\u0000-\u001f\u007f%]/.test(path)||path.split('/').some(part=>part==='.'||part==='..'))return null;
  return uri.href;
 }catch{return null;}
}

/** Camera bytes stay in the caller's owned form; no account or server state here. */
export function createNativeHorsePhoto({platform,loadCamera=()=>import('@capacitor/camera'),fetchLocal=(...args)=>fetch(...args)}){
 let restored=false,disposed=false;
 const requireCurrent=isCurrent=>{if(disposed||typeof isCurrent!=='function'||!isCurrent())throw stale();};
 async function takePhoto({isCurrent}={}){
  requireCurrent(isCurrent);
  try{
   const {Camera,EncodingType}=await loadCamera();requireCurrent(isCurrent);
   const result=await Camera.takePhoto({encodingType:EncodingType.JPEG,quality:90,correctOrientation:true,saveToGallery:false,editable:'no'});requireCurrent(isCurrent);
   const url=result?.type===0?nativePhotoUrl(result.webPath,platform):null;
   if(!url)throw unavailable();
   const response=await fetchLocal(url,{credentials:'omit',redirect:'error',cache:'no-store'});requireCurrent(isCurrent);
   if(!response.ok||response.redirected)throw unavailable();
   const blob=await response.blob();requireCurrent(isCurrent);
   if(blob.type!=='image/jpeg'||blob.size<=0||blob.size>10*1024*1024)throw fail('PHOTO_INPUT_INVALID','Kies een JPG-foto van maximaal 10 MB.');
   return new File([blob],'paardenfoto.jpg',{type:blob.type});
  }catch(e){
   requireCurrent(isCurrent);
   if(e?.code==='OS-PLUG-CAMR-0006')return null;
   if(e?.code==='OS-PLUG-CAMR-0003')throw fail('CAMERA_PERMISSION_REQUIRED','Je hebt geen cameratoegang gegeven. Je kunt een bestaande foto kiezen of cameratoegang toestaan in de instellingen van je toestel.');
   if(e?.code==='PHOTO_INPUT_INVALID')throw e;
   throw unavailable();
  }
 }
 return {takePhoto,getRecoveryNotice:()=>restored?recovery:'',handleRestoredResult(event){
  // Android may deliver a result from a former process/account. Discard its data.
  if(!disposed&&event?.pluginId==='Camera'&&event?.methodName==='takePhoto')restored=true;
 },dispose(){disposed=true;restored=false;}};
}
