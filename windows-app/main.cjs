const { app, BrowserWindow, ipcMain, Menu, Tray, nativeImage, screen } = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const smoke = process.argv.includes('--smoke-test');
const voiceAvailable = Array.from({length:10},(_,i)=>path.join(__dirname,'assets/sounds/voice_'+String(i+1).padStart(2,'0')+'.m4a')).every(p=>fs.existsSync(p));
const initial = {skin:'crayon', size:280, opacity:1, sound:voiceAvailable, volume:0.8, motion:true, hourly:true, mood:70, city:'', weather:'none'};
let prefs = {...initial}, pet, settings, tray, drag, store;
app.setAppUserModelId('com.miku.deskpet.windows');
app.commandLine.appendSwitch('autoplay-policy', 'no-user-gesture-required');
if (smoke) app.setPath('userData', path.join(app.getPath('temp'), 'miku-deskpet-smoke'));
if (!smoke && !app.requestSingleInstanceLock()) app.quit();
app.on('second-instance', () => pet?.show());
function save() {
  if (smoke) return;
  fs.mkdirSync(path.dirname(store), {recursive:true});
  fs.writeFileSync(store+'.tmp', JSON.stringify(prefs,null,2));
  fs.renameSync(store+'.tmp', store);
}
function config() { return {...prefs, sound:voiceAvailable && prefs.sound, voiceAvailable, login:app.getLoginItemSettings().openAtLogin}; }
function broadcast() {
  for (const w of [pet,settings]) if (w && !w.isDestroyed()) w.webContents.send('config',config());
}
function action(name) { if (pet && !pet.isDestroyed()) pet.webContents.send('action',name); }
function update(values) {
  for (const key of ['sound','motion','hourly']) if (typeof values[key]==='boolean') prefs[key]=values[key];
  if (['crayon','standard','chibi'].includes(values.skin)) prefs.skin=values.skin;
  for (const [key,lo,hi] of [['size',140,500],['opacity',0.25,1],['volume',0,1]]) {
    if (Number.isFinite(values[key])) prefs[key]=Math.min(hi,Math.max(lo,values[key]));
  }
  if (typeof values.city==='string') prefs.city=values.city.trim().slice(0,80);
  if (['none','sun','rain','snow','stars','cherry','maple'].includes(values.weather)) prefs.weather=values.weather;
  if (typeof values.login==='boolean' && !smoke) app.setLoginItemSettings({openAtLogin:values.login});
  if (!voiceAvailable) prefs.sound=false;
  pet.setOpacity(prefs.opacity);
  const {x,y,width:w,height:h}=pet.getBounds();
  const height=Math.round(prefs.size*1.5+80), width=Math.round(prefs.size*1.2+60);
  pet.setBounds({x:Math.round(x+(w-width)/2),y:Math.round(y+h-height),width,height});
  save(); broadcast();
}
function secureWindow(win) {
  win.webContents.setWindowOpenHandler(()=>({action:'deny'}));
  win.webContents.on('will-navigate',e=>e.preventDefault());
  win.webContents.session.setPermissionRequestHandler((_wc,_perm,done)=>done(false));
}
function openSettings() {
  if (settings && !settings.isDestroyed()) {settings.show();settings.focus();return;}
  settings=new BrowserWindow({width:460,height:690,resizable:false,title:'初音桌宠 · 设置',autoHideMenuBar:true,show:!smoke,
    webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true}});
  secureWindow(settings); settings.loadFile('settings.html');
  settings.on('closed',()=>settings=null);
}
function menu() {
  return Menu.buildFromTemplate([
    {label:'✨ 动态模式',type:'checkbox',checked:prefs.motion,click:i=>update({motion:i.checked})},
    {label:'🎭 切换形象',submenu:[['crayon','蜡笔初音'],['standard','标准初音'],['chibi','Q版初音']].map(([skin,label])=>({label,type:'radio',checked:prefs.skin===skin,click:()=>update({skin})}))},
    {label:'🥬 投喂大葱',click:()=>action('feed')},
    {label:'💬 聊聊天',click:()=>action('chat')},
    ...(voiceAvailable ? [{label:'🎤 演示语音口型',click:()=>action('speech')}] : []),
    {label:'▶ 演示动作',click:()=>action('motion')},
    {label:'天气与季节特效',submenu:[['none','关闭'],['sun','晴天'],['rain','下雨'],['snow','下雪'],['stars','流星'],['cherry','樱花'],['maple','枫叶']].map(([weather,label])=>({label,type:'radio',checked:prefs.weather===weather,click:()=>update({weather})}))},
    {type:'separator'}, {label:'⚙ 设置…',click:openSettings},
    {label:'显示桌宠',click:()=>{pet.show(); const a=screen.getPrimaryDisplay().workArea;pet.setPosition(a.x+a.width-pet.getBounds().width-30,a.y+a.height-pet.getBounds().height-30);}},
    {type:'separator'},{label:'退出',click:()=>app.quit()}
  ]);
}
function trusted(event) { return [pet,settings].some(w=>w && !w.isDestroyed() && w.webContents===event.sender); }
ipcMain.handle('get-config',e=>trusted(e)?config():null);
ipcMain.handle('set-config',(e,v)=>{if(trusted(e) && v && typeof v==='object')update(v);return config();});
ipcMain.on('context',e=>{if(trusted(e))menu().popup({window:pet});});
ipcMain.on('action',(e,name)=>{if(trusted(e)&&['feed','chat','speech','motion'].includes(name))action(name);});
ipcMain.on('mouse',(e,active)=>{if(pet?.webContents===e.sender&&!drag)pet.setIgnoreMouseEvents(!active,{forward:true});});
ipcMain.on('drag',(e,phase)=>{
  if(pet?.webContents!==e.sender)return;
  if(phase==='start') {const p=screen.getCursorScreenPoint(),b=pet.getBounds();drag={x:p.x-b.x,y:p.y-b.y};}
  if(phase==='end')drag=null;
});
app.whenReady().then(()=>{
  store=path.join(app.getPath('userData'),'preferences.json');
  if(!smoke)try{const v=JSON.parse(fs.readFileSync(store,'utf8'));for(const k of Object.keys(initial))if(typeof v[k]===typeof initial[k])prefs[k]=v[k];}catch{}
  if (!voiceAvailable) prefs.sound=false;
  const a=screen.getPrimaryDisplay().workArea, width=Math.round(prefs.size*1.2+60),height=Math.round(prefs.size*1.5+80);
  pet=new BrowserWindow({width,height,x:a.x+a.width-width-50,y:a.y+a.height-height-20,transparent:true,frame:false,resizable:false,hasShadow:false,
    alwaysOnTop:true,skipTaskbar:true,show:!smoke,webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,backgroundThrottling:false}});
  secureWindow(pet);pet.setOpacity(prefs.opacity);pet.setIgnoreMouseEvents(true,{forward:true});
  if(process.platform==='darwin')pet.setVisibleOnAllWorkspaces(true,{visibleOnFullScreen:true});
  pet.loadFile('index.html',{query:smoke?{smoke:'1'}:{}});
  if(!smoke){
    const icon=nativeImage.createFromPath(path.join(__dirname,'assets/crayon_idle.png')).resize({width:32,height:32});
    tray=new Tray(icon);tray.setToolTip('初音桌宠 · 右键打开菜单');
    tray.on('right-click',()=>menu().popup());tray.on('click',()=>{pet.show();openSettings();});
  }
  setInterval(()=>{if(drag){const p=screen.getCursorScreenPoint();pet.setPosition(p.x-drag.x,p.y-drag.y);}},16);
  if(smoke){
    const deadline=setTimeout(()=>{console.error('SMOKE: timeout');app.exit(1);},45000);
    ipcMain.once('smoke-result',async(e,result)=>{
      if(e.sender!==pet.webContents)return;
      console.log('SMOKE:',JSON.stringify(result));
      if(result.ok){
        const shot=await pet.webContents.capturePage();
        const output=process.env.MIKU_SMOKE_OUTPUT || path.join(app.getPath('temp'),'miku-deskpet-smoke-preview.png');
        fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,shot.toPNG());
        openSettings(); await new Promise(resolve=>settings.webContents.once('did-finish-load',resolve));
        const settingsOK=await settings.webContents.executeJavaScript('document.querySelectorAll("input, select, button").length >= 10') && (voiceAvailable || await settings.webContents.executeJavaScript('["sound","volume","speech"].every(id=>document.getElementById(id).disabled)'));
        console.log('SETTINGS:',settingsOK);clearTimeout(deadline);app.exit(settingsOK?0:1);
      }else{clearTimeout(deadline);app.exit(1);}
    });
  }
});
app.on('window-all-closed',()=>{if(smoke)app.quit();});
