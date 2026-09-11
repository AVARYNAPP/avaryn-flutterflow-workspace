// Optional asset maintenance. Normal builds use the checked-in PNGs and need no renderer.
// Use sharp 0.35.4: node scripts/render-native-brand.mjs [absolute path to sharp package].
import {readFile,writeFile,readdir} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';

const root=fileURLToPath(new URL('../',import.meta.url));
const require=createRequire(import.meta.url);
const modulePath=process.argv[2];
if(modulePath&&!path.isAbsolute(modulePath))throw new Error('The optional sharp package path must be absolute.');
const sharpModule=modulePath?pathToFileURL(require.resolve(modulePath)).href:'sharp';
const sharp=(await import(sharpModule)).default;
const sharpVersion=JSON.parse(await readFile(modulePath?path.join(modulePath,'package.json'):require.resolve('sharp/package.json'),'utf8')).version;
if(sharpVersion!=='0.35.4')throw new Error('Use the documented sharp 0.35.4 renderer.');
const mark=await readFile(path.join(root,'src/assets/mark.svg'),'utf8');
const brand='#675074',paper='#fffaf4';
const symbol=mark.match(/<path\b[^>]*\/>/)?.[0];
if(!symbol||!mark.includes(`fill="${brand}"`)||!mark.includes(`stroke="${paper}"`))throw new Error('Review the accepted mark before regenerating native assets.');
const svg=(body,w=64,h=w)=>Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}">${body}</svg>`);
const icon=svg(`<rect width="64" height="64" fill="${brand}"/>${symbol}`);
const round=svg(`<circle cx="32" cy="32" r="32" fill="${brand}"/>${symbol}`);
const adaptive=svg(`<g transform="translate(9.2 9.2) scale(1.4)">${symbol}</g>`,108);
const outputs=[];
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
await writeFile(path.join(root,'android/app/src/main/res/drawable/ic_launcher_background.xml'),`<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="${brand}" android:pathData="M0,0h108v108h-108z" />
</vector>\n`);
await writeFile(path.join(root,'android/app/src/main/res/drawable-v24/ic_launcher_foreground.xml'),`<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <group android:translateX="9.2" android:translateY="9.2" android:scaleX="1.4" android:scaleY="1.4">
        <path android:pathData="${symbol.match(/ d="([^"]+)"/)[1]}" android:fillColor="#00000000" android:strokeColor="${paper}" android:strokeWidth="4" android:strokeLineCap="round" android:strokeLineJoin="round" />
    </group>
</vector>\n`);
async function save(relative,bytes){
 const dest=path.join(root,relative);await writeFile(dest,bytes);
 const meta=await sharp(bytes).metadata();
 outputs.push({path:relative,width:meta.width,height:meta.height,alpha:meta.hasAlpha,sha256:hash(bytes)});
}
for(const [density,factor] of Object.entries({mdpi:1,hdpi:1.5,xhdpi:2,xxhdpi:3,xxxhdpi:4})){
 const dir=`android/app/src/main/res/mipmap-${density}`;
 await save(`${dir}/ic_launcher.png`,await sharp(Buffer.from(mark)).resize(48*factor).png().toBuffer());
 await save(`${dir}/ic_launcher_round.png`,await sharp(round).resize(48*factor).png().toBuffer());
 await save(`${dir}/ic_launcher_foreground.png`,await sharp(adaptive).resize(108*factor).png().toBuffer());
}
await save('ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png',await sharp(icon).resize(1024).flatten({background:brand}).removeAlpha().png().toBuffer());
const splashFiles=[];
const res='android/app/src/main/res';
for(const name of (await readdir(path.join(root,res))).filter(v=>/^drawable(?:-(?:port|land)-\w+)?$/.test(v))){
 if((await readdir(path.join(root,res,name))).includes('splash.png'))splashFiles.push(`${res}/${name}/splash.png`);
}
const iosSplash='ios/App/App/Assets.xcassets/Splash.imageset';
for(const name of (await readdir(path.join(root,iosSplash))).filter(v=>v.endsWith('.png')))splashFiles.push(`${iosSplash}/${name}`);
for(const relative of splashFiles){
 const {width,height}=await sharp(await readFile(path.join(root,relative))).metadata();
 const size=relative.startsWith('ios/')?512:Math.round(Math.min(width,height)*.3);
 const rendered=await sharp(Buffer.from(mark)).resize(size).png().toBuffer();
 await save(relative,await sharp({create:{width,height,channels:3,background:paper}}).composite([{input:rendered,gravity:'centre'}]).removeAlpha().png().toBuffer());
}
await writeFile(path.join(root,'config/native-brand-assets.json'),JSON.stringify({
 source:'src/assets/mark.svg',sourceSha256:hash(mark),renderer:`sharp ${sharpVersion}`,
 derivation:'Existing V8 mark. Opaque iOS icon; Android adaptive foreground stays in the central safe region; centered mark on the existing cream launch background.',
 outputs:outputs.sort((a,b)=>a.path.localeCompare(b.path))
},null,2)+'\n');
console.log(`Rendered ${outputs.length} native assets from the existing AVARYN mark.`);
