import {Capacitor} from '@capacitor/core';
import {PRODUCT} from './product-config.js';
import {createNativeAuthCallbacks} from './native-callback.js';
import {createNativeHorsePhoto} from './native-photo.js';

/** Platform sessions are deliberately separate from account/domain data. */
export async function initializePlatform(){
 if(!Capacitor.isNativePlatform())return {apiBase:PRODUCT.apiBase,storage:globalThis.sessionStorage};
 let api;
 try{api=new URL(PRODUCT.apiBase);}catch{}
 if(!api||api.protocol!=='https:'||api.username||api.password||api.search||api.hash||api.pathname!=='/api')return {
  blocked:{code:'NATIVE_API_CONFIGURATION_REQUIRED',message:'Deze appbuild heeft nog geen beveiligde serververbinding. Gebruik de webapp totdat de native verbinding is ingesteld.'},apiBase:null,storage:null
 };
 const [{SecureStorage,KeychainAccess},{App},{Browser}]=await Promise.all([
  import('@aparajita/capacitor-secure-storage'),import('@capacitor/app'),import('@capacitor/browser')
 ]);
 await SecureStorage.setKeyPrefix('avaryn.session.');
 await SecureStorage.setSynchronize(false);
 await SecureStorage.setDefaultKeychainAccess(KeychainAccess.whenUnlockedThisDeviceOnly);
 const authCallbacks=await createNativeAuthCallbacks({App});
 const horsePhoto=createNativeHorsePhoto({platform:Capacitor.getPlatform()});
 const restoredPhoto=await App.addListener('appRestoredResult',event=>horsePhoto.handleRestoredResult(event));
 const storage={
  getItem:key=>SecureStorage.getItem(key),
  setItem:(key,value)=>SecureStorage.setItem(key,value),
  removeItem:key=>SecureStorage.removeItem(key)
 };
 document.documentElement.dataset.platform=Capacitor.getPlatform();
 const back=await App.addListener('backButton',({canGoBack})=>{
  const modal=document.querySelector('#modal');
  if(modal?.open){modal.dispatchEvent(new Event('cancel',{cancelable:true}));return;}
  if(canGoBack)history.back();else void App.minimizeApp();
 });
 const active=await App.addListener('appStateChange',({isActive})=>{if(isActive)window.dispatchEvent(new Event('focus'));});
 const externalLink=event=>{
  const link=event.target.closest?.('a[href]');if(!link)return;
  const url=new URL(link.href,location.href);
  if(url.protocol==='https:'&&url.origin!==location.origin){event.preventDefault();void Browser.open({url:url.href});}
 };
 document.addEventListener('click',externalLink);
 return {apiBase:PRODUCT.apiBase,storage,horsePhoto,...authCallbacks,async dispose(){horsePhoto.dispose();document.removeEventListener('click',externalLink);await Promise.all([authCallbacks.dispose(),restoredPhoto.remove(),back.remove(),active.remove()]);}};
}
