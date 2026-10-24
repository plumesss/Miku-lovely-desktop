const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('petAPI',{
  getConfig:()=>ipcRenderer.invoke('get-config'),
  setConfig:v=>ipcRenderer.invoke('set-config',v),
  onConfig:fn=>ipcRenderer.on('config',(_e,v)=>fn(v)),
  onAction:fn=>ipcRenderer.on('action',(_e,v)=>fn(v)),
  menu:()=>ipcRenderer.send('context'),
  action:name=>ipcRenderer.send('action',name),
  mouse:active=>ipcRenderer.send('mouse',!!active),
  drag:phase=>ipcRenderer.send('drag',phase),
  smokeResult:v=>ipcRenderer.send('smoke-result',v)
});
