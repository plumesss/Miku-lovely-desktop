"""Calibrated mouth texture rigs, retaining the existing painted art.
Not a Cubism model. Leek/hand foreground is explicitly preserved.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'mouths'
SKINS = {'standard':'miku','chibi':'miku_chibi','crayon':'miku_crayon'}
STATES = ['idle','blink','happy','sad','sleep']
# Native-pixel mouth masks, independently calibrated for every expression.
POLYS = {
 'standard': {
  'idle':[(503,204),(534,195),(539,202),(530,213),(506,214)],
  'blink':[(502,204),(532,194),(538,202),(527,213),(505,214)],
  'happy':[(502,200),(539,188),(543,195),(539,212),(526,221),(512,217),(502,209)],
  'sad':[(506,208),(528,201),(533,207),(512,216)],
  'sleep':[(489,211),(515,195),(519,201),(506,215),(491,218)]},
 'chibi':{
  'idle':[(578,499),(641,489),(650,507),(649,532),(630,546),(600,541),(580,523)],
  'blink':[(510,448),(551,434),(557,440),(545,452),(512,458)],
  'happy':[(497,430),(554,410),(564,424),(567,450),(552,469),(530,476),(510,466),(499,447)],
  'sad':[(499,448),(554,431),(563,439),(555,451),(511,462),(499,462)],
  'sleep':[(521,447),(565,430),(570,437),(555,450),(525,458)]},
 'crayon':{
  'idle':[(320,408),(328,400),(351,400),(373,411),(373,448),(320,448)],
  'blink':[(318,408),(326,400),(350,401),(373,411),(373,448),(318,448)],
  'happy':[(310,347),(345,342),(378,348),(385,363),(382,396),(367,418),(344,426),(320,415),(308,394),(304,364)],
  'sad':[(315,364),(329,357),(345,360),(357,356),(376,368),(380,384),(314,384)],
  'sleep':[(324,417),(341,411),(353,414),(363,425),(363,441),(323,441)]}}
# Target center / mouth width / maximum height / slope in radians.
RIGS = {
 'standard':[(520,206,32,20,-.36),(519,206,32,20,-.36),(522,206,36,26,-.36),(520,209,28,18,-.34),(504,208,29,19,-.55)],
 'chibi':[(615,517,66,49,-.12),(533,449,43,34,-.30),(533,441,65,62,-.28),(534,447,42,31,-.28),(547,447,44,33,-.34)],
 'crayon':[(346,415,46,25,0),(345,415,46,25,0),(345,384,76,75,0),(346,372,51,33,0),(343,423,35,19,0)]}
DONORS = {
 'standard':([(505,204),(538,191),(539,201),(534,212),(524,218),(514,215),(506,209)],(522,206),36,27,-.36),
 'chibi':([(500,432),(515,424),(545,419),(553,413),(560,421),(565,443),(561,456),(551,467),(535,473),(521,471),(509,462),(503,451)],(533,441),66,61,-.28),
 'crayon':([(313,351),(345,347),(376,352),(381,363),(378,395),(366,414),(345,421),(322,411),(312,392),(309,365)],(345,384),76,75,0)}

def poly_mask(size, points):
 m=Image.new('L',size);ImageDraw.Draw(m).polygon(points,fill=255);return m

def sample(arr,x,y):
 h,w=arr.shape[:2];x=np.clip(x,0,w-1.001);y=np.clip(y,0,h-1.001)
 x0=x.astype(int);y0=y.astype(int);ax=(x-x0)[...,None];ay=(y-y0)[...,None]
 return (arr[y0,x0]*(1-ax)+arr[y0,x0+1]*ax)*(1-ay)+(arr[y0+1,x0]*(1-ax)+arr[y0+1,x0+1]*ax)*ay

def build():
 OUT.mkdir(parents=True,exist_ok=True);manifest={}
 for skin,prefix in SKINS.items():
  donor=Image.open(ROOT/'assets'/f'{prefix}_happy.png').convert('RGBA')
  dp,dc,dw,dh,da=DONORS[skin]
  dm=poly_mask(donor.size,dp).filter(ImageFilter.GaussianBlur(.5))
  donor.putalpha(dm);don=np.asarray(donor).astype(float)/255
  # Premultiplied interpolation avoids dark fringes.
  don[...,:3]*=don[...,3:]
  for state,rig in zip(STATES,RIGS[skin]):
   im=Image.open(ROOT/'assets'/f'{prefix}_{state}.png').convert('RGBA');w,h=im.size
   cx,cy,mw,mh,angle=rig;pts=POLYS[skin][state]
   # A small rectangular face patch with feathered edges.
   extent= (int(min(min(x for x,y in pts),cx-mw*.7))-7,
             int(min(min(y for x,y in pts),cy-mh*.8))-7,
             int(max(max(x for x,y in pts),cx+mw*.7))+8,
             int(max(max(y for x,y in pts),cy+mh*.8))+8)
   left,top,right,bottom=extent;patch=im.crop(extent);pw,ph=patch.size
   pix=np.asarray(patch).astype(float)/255
   mask=poly_mask(patch.size,[(x-left,y-top) for x,y in pts]).filter(ImageFilter.MaxFilter(7))
   erase=np.asarray(mask)>0
   foreground=np.zeros((ph,pw),bool)
   if skin=='crayon':
    # Keep white leek and dark foreground outlines untouched, including AA.
    rgb=pix[...,:3]
    yy0,xx0=np.mgrid[top:bottom,left:right]
    stalk=(np.min(rgb,axis=2)>.90)&(np.ptp(rgb,axis=2)<.07)&(yy0>=cy+1)&(abs(xx0-cx)<14)
    if state not in ['idle','blink','sleep']: stalk[:]=False
    foreground=stalk|((rgb[...,0]<.32)&(rgb[...,2]>.25))
    fg=Image.fromarray((foreground*255).astype('uint8')).filter(ImageFilter.MaxFilter(3))
    foreground=np.asarray(fg)>0
    erase &= ~foreground
   # Harmonic inpainting only of original mouth pixels, fixed skin boundary.
   filled=pix[...,:3].copy()
   boundary=filled[~erase & ~foreground]
   if not len(boundary): raise ValueError((skin,state,'missing skin boundary'))
   filled[erase]=np.median(boundary,axis=0)
   for _ in range(650):
    avg=(np.roll(filled,1,0)+np.roll(filled,-1,0)+np.roll(filled,1,1)+np.roll(filled,-1,1))*.25
    filled[erase]=avg[erase]
   if skin=='crayon':
    rgb=pix[...,:3]
    skin_pixels=(rgb[...,0]>.9)&(rgb[...,1]>.65)&(rgb[...,2]>.65)&(~erase)&(~foreground)
    filled[erase]=np.median(rgb[skin_pixels],axis=0)
   base=pix.copy();base[...,:3]=filled
   yy,xx=np.mgrid[top:bottom,left:right].astype(float)
   u=(xx-cx)*np.cos(angle)+(yy-cy)*np.sin(angle)
   v=-(xx-cx)*np.sin(angle)+(yy-cy)*np.cos(angle)
   feather=np.minimum.reduce([np.arange(pw)[None,:]+np.zeros((ph,1)),pw-1-np.arange(pw)[None,:]+np.zeros((ph,1)),np.arange(ph)[:,None]+np.zeros((1,pw)),ph-1-np.arange(ph)[:,None]+np.zeros((1,pw))])
   feather=np.clip(feather/5,0,1)
   # High-resolution source texture -> five continuous visual aperture levels.
   for level,amount in enumerate([.055,.24,.47,.72,1.]):
    su=u*dw/mw;sv=v*dh/(mh*amount)
    sx=dc[0]+su*np.cos(da)-sv*np.sin(da)
    sy=dc[1]+su*np.sin(da)+sv*np.cos(da)
    mouth=sample(don,sx,sy)
    if level==0:
     # Slightly curved lip, minimum native thickness for every art style.
     curve=(u/(mw*.5))**2 * (-1.3 if skin!='crayon' else -.8)
     lip=np.clip((1.1 if skin!='crayon' else 1.9)-abs(v-curve),0,1)*np.clip((mw*.5-abs(u))/2,0,1)
     lip_color=np.array([.64,.28,.30] if skin!='crayon' else [.77,.36,.45])
     mouth=np.concatenate((lip[...,None]*lip_color,lip[...,None]),axis=2)
    a=mouth[...,3:]
    rgb=base[...,:3]*(1-a)+mouth[...,:3]
    rgb[foreground]=pix[...,:3][foreground]
    result=np.concatenate((rgb,((pix[...,3]>=1)*feather)[...,None]),axis=2)
    Image.fromarray(np.uint8(np.clip(result*255,0,255))).save(OUT/f'{skin}_{state}_{level}.png')
   manifest[f'{skin}_{state}']={'rect':[left/w,top/h,pw/w,ph/h]}
   print(skin,state,extent,flush=True)
 (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))

if __name__=='__main__':build()
