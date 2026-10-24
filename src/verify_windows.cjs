// Verify the actual ASAR shipped in an unpacked or installed Windows application.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const asar = require('../windows-app/node_modules/@electron/asar');
const root = path.resolve(__dirname, '..');
const resources = path.resolve(process.argv[2] || path.join(root,'dist/windows/win-unpacked/resources'));
const archive = path.join(resources,'app.asar');
const entries = asar.listPackage(archive).map(p=>p.replace(/\\/g,'/').replace(/^\/+/, ''));
assert(!entries.some(p=>/\.(m4a|mp3|wav|ogg|flac|aac)$/i.test(p)||/(^|\/)(sounds|node_modules|\.git|backups)(\/|$)/.test(p)), 'Private audio or development files included');
for (const name of ['main.cjs','preload.cjs','renderer.js','settings.js','index.html','settings.html','pet.css','settings.css']) {
  assert(asar.extractFile(archive,name).equals(fs.readFileSync(path.join(root,'windows-app',name))), 'Packaged source mismatch: '+name);
}
const metadata=JSON.parse(asar.extractFile(archive,'package.json'));
assert.equal(metadata.version,JSON.parse(fs.readFileSync(path.join(root,'windows-app/package.json'))).version);
for (const skin of ['standard','chibi','crayon']) for(const state of ['idle','blink','happy','sad','sleep']) {
  for (const name of [`${skin}_${state}.png`,`animation/${skin}_${state}.png`,...Array.from({length:5},(_,i)=>`mouths/${skin}_${state}_${i}.png`)]) {
    assert(asar.extractFile(archive,path.normalize('assets/'+name)).length>100,'Missing image: '+name);
  }
}
for(const name of ['LICENSE','THIRD_PARTY_NOTICES.md'])assert(fs.readFileSync(path.join(resources,name)).equals(fs.readFileSync(path.join(root,name))),'Notice mismatch');
console.log(JSON.stringify({version:metadata.version,images:105,audioIncluded:false,sourceMatches:true,notices:true}));
