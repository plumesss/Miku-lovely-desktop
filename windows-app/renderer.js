const canvas=document.querySelector('#pet'),ctx=canvas.getContext('2d',{willReadFrequently:true}),bubble=document.querySelector('#bubble');
let prefs,manifest={},tempState='',until=0,bubbleTimer,gesture=0,gestureKind='',dragging=false,down=null,lastMouse=false,lastHour=new Date().getHours(),weather='none';
let audioContext,analyser,samples,activeAudio,lip=0,lastFrame=0,rect={x:0,y:0,w:0,h:0},currentImage;
const cache=new Map(),pending=new Map(),atlases=new Map(),audioCache=new Map();
const names=['standard','chibi','crayon'],states=['idle','blink','happy','sad','sleep'];
const lines={tap:['诶嘿嘿～被戳到了啦♪','干嘛呀～痒痒的！','想听我唱歌嘛？♫','摸摸头，会变聪明的哦！','一直在哦，随时找我玩～'],chat:['工作累了就休息一下眼睛吧～','喝口水，活动一下吧♪','♫ 啦啦啦～今天也加油！'],feed:['哇！大葱！未来酱的最爱！！♪','咔嚓咔嚓…幸福～谢谢你！']};
const random=a=>a[Math.floor(Math.random()*a.length)];
function say(text){bubble.textContent=text;bubble.hidden=false;clearTimeout(bubbleTimer);bubbleTimer=setTimeout(()=>bubble.hidden=true,4200);}
async function image(file,atlas=false){
 const map=atlas?atlases:cache;
 if(map.has(file)){const value=map.get(file);if(atlas){map.delete(file);map.set(file,value);}return value;}
 if(pending.has(file))return pending.get(file);
 const task=(async()=>{const r=await fetch('assets/'+file);if(!r.ok)throw Error('素材读取失败：'+file);const im=await createImageBitmap(await r.blob());map.set(file,im);if(atlas)while(map.size>3){const first=map.keys().next().value;map.get(first).close();map.delete(first);}return im;})();
 pending.set(file,task);try{return await task;}finally{pending.delete(file);}
}
function warm(file,atlas=false){const map=atlas?atlases:cache;if(!map.has(file)&&!pending.has(file))image(file,atlas).catch(e=>{console.error(e);say(e.message);});return map.get(file);}
function audioSetup(){if(audioContext)return;audioContext=new AudioContext();analyser=audioContext.createAnalyser();analyser.fftSize=512;samples=new Float32Array(analyser.fftSize);analyser.connect(audioContext.destination);}
function stopVoice(){if(activeAudio){activeAudio.pause();activeAudio.currentTime=0;}activeAudio=null;lip=0;}
async function speak(n){
 stopVoice();if(!prefs.sound||prefs.volume===0)return;
 try{audioSetup();await audioContext.resume();let a=audioCache.get(n);if(!a){a=new Audio('assets/sounds/voice_'+String(n).padStart(2,'0')+'.m4a');audioContext.createMediaElementSource(a).connect(analyser);audioCache.set(n,a);}a.volume=prefs.volume;activeAudio=a;await a.play();}catch(e){console.error('语音播放失败',e);say('语音暂时无法播放，请检查声音设置。');}
}
function action(name){
 gesture=performance.now();gestureKind=name;
 if(name==='feed'){prefs.mood=Math.min(100,prefs.mood+12);tempState='happy';until=Date.now()+4200;say(random(lines.feed));speak(random([3,4,7]));}
 else if(name==='chat'){tempState='happy';until=Date.now()+3000;say(random(lines.chat));speak(random([1,2,5,6]));}
 else if(name==='speech'){say('跟着语音一起动嘴巴～♪');speak(random([1,2,3,4,5,6,7,8,9,10]));}
 else if(name==='motion'){say('来看看未来酱的动作吧！');}
 else{prefs.mood=Math.min(100,prefs.mood+3);tempState='happy';until=Date.now()+2200;say(random(lines.tap));speak(random([2,5,8,9,10]));}
}
function currentState(t){
 if(Date.now()<until)return tempState;
 if(new Date().getHours()<7)return 'sleep';
 if(t%4700<145)return 'blink';
 return prefs.mood<30?'sad':prefs.mood>=75?'happy':'idle';
}
function warpedPoint(x,y,r,t,skin,state){
 const phase=Math.floor((t%4)*12)*2*Math.PI/48,dims=skin==='standard'?[.15,.17,.16]:skin==='chibi'?[.25,.29,.28]:[.34,.29,.29];
 const ix=(x-r.x)/r.w,iy=(y-r.y)/r.h;let nx=ix,ny=iy;
 for(let i=0;i<4;i++){const xx=nx-.5,head=Math.exp(-Math.pow((ny-dims[0])/dims[1],4)-Math.pow(xx/dims[2],4)),hair=Math.max(0,Math.min(1,(Math.abs(xx)-dims[2]*.7)/.18))*Math.max(0,Math.min(1,(ny-dims[0])/.55)),quiet=state==='sleep'?.42:1;
 const dx=quiet*(.004*Math.sin(phase)*(1-ny)+head*.010*Math.sin(phase)+hair*.026*Math.sin(phase+ny*3+(xx<0?-.8:.8)));
 let dy=quiet*(-.005*Math.sin(phase*2)*(1-ny)+head*.005*Math.cos(phase));if(skin==='crayon'&&state!=='sleep')dy+=head*.006*(Math.cos(phase*3)-.3);nx=ix+dx;ny=iy+dy;}
 return {x:r.x+nx*r.w,y:r.y+ny*r.h};
}
function drawMouth(key,r,t,state,animated){
 if(!activeAudio||activeAudio.paused||activeAudio.ended||!analyser)return;
 analyser.getFloatTimeDomainData(samples);let square=0;for(const x of samples)square+=x*x;const db=20*Math.log10(Math.sqrt(square/samples.length)+1e-8),target=db<-44?0:Math.max(0,Math.min(1,(db+44)/32));lip+=(target-lip)*(target>lip?.72:.55);
 const entry=manifest[key];if(!entry)return;const n=entry.rect,m={x:r.x+n[0]*r.w,y:r.y+n[1]*r.h,w:n[2]*r.w,h:n[3]*r.h};
 const value=Math.max(0,Math.min(4,lip*4)),lo=Math.floor(value),hi=Math.min(4,lo+1),low=warm('mouths/'+key+'_'+lo+'.png'),high=warm('mouths/'+key+'_'+hi+'.png');
 ctx.save();if(animated){const cx=m.x+m.w/2,cy=m.y+m.h/2,p=warpedPoint(cx,cy,r,t,prefs.skin,state),dx=warpedPoint(cx+.1,cy,r,t,prefs.skin,state),dy=warpedPoint(cx,cy+.1,r,t,prefs.skin,state),a=(dx.x-p.x)*10,b=(dx.y-p.y)*10,c=(dy.x-p.x)*10,d=(dy.y-p.y)*10;ctx.transform(a,b,c,d,p.x-a*cx-c*cy,p.y-b*cx-d*cy);}
 if(low)ctx.drawImage(low,m.x,m.y,m.w,m.h);if(high&&hi!==lo){ctx.globalAlpha=value-lo;ctx.drawImage(high,m.x,m.y,m.w,m.h);}ctx.restore();
}
function drawWeather(t){
 if(weather==='none')return;ctx.save();ctx.beginPath();ctx.rect(rect.x,rect.y,rect.w,rect.h);ctx.clip();
 for(let i=0;i<22;i++){
 const x=rect.x+rect.w*((i*47+13)%100)/100+Math.sin(t+i)*4,y=rect.y+rect.h*((i*31/100+t*(weather==='rain'?.48:.13))%1);
 ctx.globalAlpha=.65;ctx.fillStyle=weather==='sun'?'#ffe36b':weather==='rain'?'#72c7ef':weather==='cherry'?'#ffb5cf':weather==='maple'?'#f28b44':'#fff';
 if(weather==='sun'){ctx.beginPath();ctx.arc(rect.x+rect.w*.55,rect.y+rect.h*.22,18+Math.sin(t+i)*9,0,Math.PI*2);ctx.globalAlpha=.015;ctx.fill();}
 else if(weather==='stars'||weather==='rain'){ctx.strokeStyle=ctx.fillStyle;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x-(weather==='stars'?8:2),y-12);ctx.stroke();}
 else{ctx.beginPath();ctx.ellipse(x,y,weather==='snow'?2:4,weather==='snow'?2:2.3,t+i,0,Math.PI*2);ctx.fill();}
 }ctx.restore();
}
function frame(now){
 requestAnimationFrame(frame);if(!prefs||now-lastFrame<1000/30)return;lastFrame=now;
 if(canvas.width!==innerWidth||canvas.height!==innerHeight){canvas.width=innerWidth;canvas.height=innerHeight;}
 const t=now/1000,state=currentState(now),key=prefs.skin+'_'+state,base=warm(key+'.png');
 const atlas=prefs.motion?warm('animation/'+key+'.png',true):null;
 ctx.clearRect(0,0,canvas.width,canvas.height);if(!base)return;
 const maxH=Math.min(prefs.size,canvas.height-100),w=Math.min(canvas.width-40,maxH*base.width/base.height),h=w*base.height/base.width;
 rect={x:(canvas.width-w)/2,y:canvas.height-h-18,w,h};ctx.save();
 let bob=0,angle=0,sx=1,sy=1;
 if(prefs.motion){bob=Math.sin(t*2.2)*.7;angle=.7*Math.sin(t*1.6);const elapsed=(now-gesture)/1000,duration=gestureKind==='feed'?2.2:1.6;
 if(elapsed<duration){const p=elapsed/duration,envelope=Math.sin(Math.PI*p);bob-=Math.abs(Math.sin(p*Math.PI*3))*13*envelope;angle+=Math.sin(p*Math.PI*4)*3*envelope;sy+=.035*envelope*Math.sin(p*Math.PI*6);sx-=.018*envelope*Math.sin(p*Math.PI*6);}
 ctx.translate(rect.x+w/2,rect.y+h+bob);ctx.rotate(angle*Math.PI/180);ctx.scale(sx,sy);ctx.translate(-rect.x-w/2,-rect.y-h);}
 if(atlas){const i=Math.floor((t%4)*12)%48,fw=atlas.width/8,fh=atlas.height/6,pad=.06/.88;ctx.drawImage(atlas,(i%8)*fw,Math.floor(i/8)*fh,fw,fh,rect.x-w*pad,rect.y-h*pad,w*(1+2*pad),h*(1+2*pad));}
 else ctx.drawImage(base,rect.x,rect.y,w,h);
 drawMouth(key,rect,t,state,!!atlas);ctx.restore();drawWeather(t);currentImage=base;
}
let cityRequest=0;
async function updateCity(city){
 const request=++cityRequest;if(!city)return;
 try{const geo=await fetch('https://geocoding-api.open-meteo.com/v1/search?name='+encodeURIComponent(city)+'&count=1&language=zh&format=json',{signal:AbortSignal.timeout(12000)}).then(r=>{if(!r.ok)throw Error('定位服务暂不可用');return r.json();});
 const place=geo.results?.[0];if(!place)throw Error('没有找到这个城市');
 const data=await fetch('https://api.open-meteo.com/v1/forecast?latitude='+place.latitude+'&longitude='+place.longitude+'&current=temperature_2m,weather_code,is_day',{signal:AbortSignal.timeout(12000)}).then(r=>{if(!r.ok)throw Error('天气服务暂不可用');return r.json();});
 if(request!==cityRequest)return;const c=data.current;if(!c)throw Error('天气数据不可用');const code=c.weather_code;
 weather=code>=71&&code<=77||code===85||code===86?'snow':code>=51?'rain':c.is_day?'sun':'stars';say(place.name+'：'+c.temperature_2m+'℃，陪你度过今天♪');
 }catch(e){if(request===cityRequest)say('天气查询失败：'+e.message);}
}
function applyConfig(v){const previous=prefs;prefs=v;if(!previous||previous.weather!==v.weather)weather=v.weather;if(!v.sound||v.volume===0)stopVoice();else if(activeAudio)activeAudio.volume=v.volume;if(previous&&previous.city!==v.city){if(v.city)updateCity(v.city);else{cityRequest++;weather=v.weather;}}}
petAPI.onConfig(applyConfig);petAPI.onAction(action);
window.addEventListener('contextmenu',e=>{e.preventDefault();petAPI.menu();});
window.addEventListener('mousemove',e=>{
 if(dragging)return;let hit=false;try{hit=ctx.getImageData(Math.floor(e.clientX),Math.floor(e.clientY),1,1).data[3]>20;}catch{}
 if(hit!==lastMouse){lastMouse=hit;petAPI.mouse(hit);}
});
window.addEventListener('mouseleave',()=>{if(!dragging){lastMouse=false;petAPI.mouse(false);}});
window.addEventListener('pointerdown',e=>{if(e.button!==0)return;down={x:e.screenX,y:e.screenY};dragging=true;canvas.setPointerCapture(e.pointerId);petAPI.drag('start');});
window.addEventListener('pointerup',e=>{if(e.button!==0||!down)return;petAPI.drag('end');dragging=false;if(Math.hypot(e.screenX-down.x,e.screenY-down.y)<6)action('tap');down=null;});
window.addEventListener('blur',()=>{petAPI.drag('end');dragging=false;down=null;});
window.addEventListener('pointercancel',()=>{petAPI.drag('end');dragging=false;down=null;});
setInterval(()=>{if(!prefs)return;const hour=new Date().getHours();if(hour!==lastHour){lastHour=hour;if(prefs.hourly)say('现在是'+hour+'点，记得休息和喝水哦～♪');}prefs.mood=Math.max(0,prefs.mood-.05);},30000);
setInterval(()=>{if(prefs?.city)updateCity(prefs.city);},30*60*1000);
async function smoke(){
 try{
  let images=0,frames=0,mouths=0,voices=0;
  for(const skin of names)for(const state of states){const key=skin+'_'+state;const im=await image(key+'.png');if(!im.width)throw Error(key);images++;const atlas=await image('animation/'+key+'.png',true);if(atlas.width%8||atlas.height%6)throw Error('动态图集尺寸异常：'+key);frames+=48;
   for(let i=0;i<5;i++){const mouth=await image('mouths/'+key+'_'+i+'.png');if(!mouth.width)throw Error('口型素材异常');mouths++;}
  }
  audioSetup();for(let n=1;n<=10;n++){const r=await fetch('assets/sounds/voice_'+String(n).padStart(2,'0')+'.m4a');const audio=await audioContext.decodeAudioData(await r.arrayBuffer());if(audio.duration<=0)throw Error('语音解码失败');voices++;}
  await petAPI.setConfig({skin:'standard',volume:.4});const updated=await petAPI.getConfig();if(updated.skin!=='standard'||updated.volume!==.4)throw Error('设置未生效');
  await petAPI.setConfig({skin:'crayon',volume:.8});applyConfig(await petAPI.getConfig());tempState='happy';until=Date.now()+10000;say('你好呀～我是初音未来，来陪你啦♪');
  await image('crayon_happy.png');await image('animation/crayon_happy.png',true);await new Promise(r=>setTimeout(r,500));
  analyser.disconnect();const muted=audioContext.createGain();muted.gain.value=0;analyser.connect(muted);muted.connect(audioContext.destination);
  await speak(1);let peak=0,lipPeak=0;for(let i=0;i<20;i++){await new Promise(r=>setTimeout(r,100));analyser.getFloatTimeDomainData(samples);for(const sample of samples)peak=Math.max(peak,Math.abs(sample));lipPeak=Math.max(lipPeak,lip);}
  const playback=activeAudio?.currentTime>.1;if(!playback||peak<.0001||lipPeak<=0)throw Error('语音播放或口型同步未工作');stopVoice();
  let opaque=0;const pixels=ctx.getImageData(0,0,canvas.width,canvas.height).data;for(let i=3;i<pixels.length;i+=4)if(pixels[i]>20)opaque++;if(opaque<500)throw Error('桌宠绘制为空');
  petAPI.smokeResult({ok:true,images,frames,mouths,voices,opaque,settings:true,playback,lipsync:lipPeak>0});
 }catch(e){console.error(e);petAPI.smokeResult({ok:false,error:e.stack});}
}
(async()=>{try{const initialConfig=await petAPI.getConfig();manifest=await fetch('assets/mouths/manifest.json').then(r=>r.json());applyConfig(initialConfig);requestAnimationFrame(frame);
 if(new URLSearchParams(location.search).has('smoke'))await smoke();else{say('你好呀～我是初音未来，来陪你啦♪');setTimeout(()=>speak(random([1,2])),1000);if(prefs.city)updateCity(prefs.city);}
 }catch(e){console.error(e);say('桌宠素材加载失败，请重新安装。');if(new URLSearchParams(location.search).has('smoke'))petAPI.smokeResult({ok:false,error:e.stack});}})();
