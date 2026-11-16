#!/usr/bin/env python3
"""Sync supplied team recordings to the unchanged captions and add data visuals."""
import argparse
import bisect
import json
import math
import os
import re
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw
import build_video as v

ROOT=v.ROOT
TMP=Path(os.environ.get('MCA_VIDEO_BUILD_DIR',ROOT/'docs/video/.build'))
SYNC_PATH=ROOT/'docs/video/MCA_Final_Sync.json'
SYNC=json.loads((SYNC_PATH if SYNC_PATH.exists() else TMP/'sync.json').read_text())
CUES=SYNC['cues']
DURATION=SYNC['duration']
FPS=15
OUT=ROOT/'docs/video'
STARTS=[c['start'] for c in CUES]
def at(i):return CUES[i]['start']

ORIGINAL_SCENES={s[1]:s for s in v.SCENES}
SPECS=[
 (0,'title'),(at(2),'team'),(at(4),'concept'),(at(7),'pe_intro'),
 (at(8),'mac'),(at(9),'sum_graph'),(at(11),'datapath'),(at(12),'valid'),
 (at(14),'pe_tests'),(at(15),'pe_waveform'),(at(16),'grid'),(at(17),'flow'),
 (at(20),'reuse'),(at(23),'skew'),(at(26),'scoreboard'),
 (at(29),'integration'),(at(31),'fsm'),(at(34),'handshake'),
 (at(36),'timing_waveform'),(at(37),'golden'),(at(39),'testbench'),
 (at(41),'results'),(at(44),'system_tests'),(at(46),'top_waveform'),
 (at(47),'top_zoom'),(at(49),'metrics'),(at(50),'finish'),
 (at(52),'roadmap'),(at(55),'end')]
CUSTOM={
 'sum_graph':('Four products. One running sum.','C[0][0] / exact accumulation values from the example matrices'),
 'pe_waveform':('Inside the processing element','PE waveform from the project report / multiplication, clear and forwarding'),
 'timing_waveform':('The controller, one edge at a time','Timing diagram derived from RTL / registered outputs after each rising edge'),
 'top_waveform':('From start to a captured result','Full top-level waveform figure from the repository report'),
 'top_zoom':('Done marks the completed matrix','Detail from the same report figure / result capture and output value')}
SCENES=[]
for t,k in SPECS:
 if k in CUSTOM:title,sub=CUSTOM[k]
 else:_,_,title,sub=ORIGINAL_SCENES[k]
 SCENES.append((t,k,title,sub))
SSTARTS=[s[0] for s in SCENES]

def prepare_voiceover():
 """Rebuild audio from the locally retained originals without changing speech."""
 TMP.mkdir(parents=True,exist_ok=True)
 clips=SYNC['clips']
 for clip in clips:
  source=OUT/clip['source']
  if not source.is_file():
   raise FileNotFoundError(f'Missing original recording: {source}. See docs/video/README.md.')
  target=TMP/(clip['stem']+'_normalized.wav')
  trim0,trim1=clip['trim_start'],clip['trim_end']
  pre=f'atrim=start={trim0}:end={trim1},asetpts=PTS-STARTPTS,highpass=f=75,lowpass=f=9500,afftdn=nr=6:nf=-35'
  result=subprocess.run(['ffmpeg','-hide_banner','-i',str(source),'-af',pre+',loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
  measure=json.loads(re.findall(r'\{[^{}]*"input_i"[^{}]*\}',result.stderr,re.S)[-1])
  loud=f"loudnorm=I=-16:TP=-1.5:LRA=11:measured_I={measure['input_i']}:measured_TP={measure['input_tp']}:measured_LRA={measure['input_lra']}:measured_thresh={measure['input_thresh']}:offset={measure['target_offset']}:linear=true"
  filt=pre+','+loud+f',afade=t=in:d=0.02,afade=t=out:st={trim1-trim0-.025}:d=0.025'
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-af',filt,'-ar','48000','-ac','2',str(target)],check=True)
  print(f"Prepared recording: {clip['speaker']} / {clip['stem']}",flush=True)
 cmd=['ffmpeg','-hide_banner','-v','error','-y']
 for clip in clips:cmd+=['-i',str(TMP/(clip['stem']+'_normalized.wav'))]
 filters=[f'[{i}:a]adelay={round(clip["start"]*1000)}:all=1[a{i}]' for i,clip in enumerate(clips)]
 filters.append(''.join(f'[a{i}]' for i in range(len(clips)))+f'amix=inputs={len(clips)}:normalize=0:dropout_transition=0,apad=whole_dur={DURATION}[mix]')
 cmd+=['-filter_complex',';'.join(filters),'-map','[mix]','-ar','48000','-ac','2','-t',str(DURATION),str(TMP/'final_voiceover.wav')]
 subprocess.run(cmd,check=True)

def empty(scene):
 im=Image.new('RGB',(1920,1080),v.BG);d=ImageDraw.Draw(im)
 for x in range(0,1920,80):d.line((x,0,x,850),fill='#0e192b')
 for y in range(0,850,80):d.line((0,y,1920,y),fill='#0e192b')
 v.text(d,(70,42),'MCA  /  PHASE 01',25,v.CYAN,True)
 v.text(d,(70,102),scene[2],57,v.INK,True)
 v.text(d,(73,178),scene[3],28,v.MUTED)
 return im

def custom_base(scene):
 im=empty(scene);d=ImageDraw.Draw(im);k=scene[1]
 if k=='sum_graph':
  v.rr(d,(85,260,1400,815))
  left,right,top,bottom=230,1290,325,705
  for val in range(0,81,16):
   y=bottom-val/80*(bottom-top)
   d.line((left,y,right,y),fill=v.BORDER,width=2)
   v.text(d,(left-65,y-17),val,28,v.MUTED)
  for n in range(5):
   x=left+n*(right-left)/4
   d.line((x,top,x,bottom),fill=v.BORDER,width=1)
   v.center(d,(x,bottom+35),n,27,v.MUTED)
  v.text(d,(260,761),'Accepted product terms',28,v.MUTED)
  v.text(d,(110,280),'SUM',22,v.CYAN,True)
  v.card(d,(1460,275,1835,810),'TARGET OUTPUT','80','16 + 24 + 24 + 16. Each accepted operand pair contributes one product.',v.CYAN)
 elif k=='pe_waveform':
  pic=Image.open(ROOT/'report/figures/fig4_pe_waveform.png').convert('RGB')
  pic=pic.resize((1485,594),Image.Resampling.LANCZOS)
  im.paste(pic,(70,245))
  v.rr(d,(1605,270,1850,800))
  for i,(l,num,col) in enumerate([('3 × 4','12',v.CYAN),('CLEAR','0',v.GOLD),('−3 × 5','−15',v.BLUE)]):
   v.text(d,(1630,304+i*155),l,27,col,True);v.text(d,(1630,352+i*155),num,62,v.INK,True)
 elif k=='timing_waveform':
  x0=340;dx=100;top=280
  for e in range(14):
   x=x0+e*dx;d.line((x,top,x,775),fill=v.BORDER,width=2)
   v.center(d,(x,top),str(e),25,v.MUTED)
  signals=[('clear_acc',[1]+[0]*13,v.GOLD),('input valid',[0,0]+[1]*4+[0]*8,v.BLUE),('busy',[1]*13+[0],v.CYAN),('done',[0]*13+[1],v.PURPLE)]
  for i,(name,states,col) in enumerate(signals):
   y=370+i*105;v.text(d,(95,y-20),name,30,col,True)
   pts=[]
   for e,val in enumerate(states):
    x=x0+e*dx;yy=y-30 if val else y+20
    if e:pts.append((x,pts[-1][1]))
    pts.extend([(x,yy),(x+dx,yy)])
   d.line(pts,fill=col,width=5)
  v.text(d,(95,805),'Edges 0–13 inclusive: acceptance → clear/load/drain → registered result and done',29,v.MUTED)
 elif k=='top_waveform':
  pic=Image.open(ROOT/'report/figures/fig3_top_waveform.png').convert('RGB')
  pic=pic.resize((1375,600),Image.Resampling.LANCZOS)
  im.paste(pic,(70,240))
  v.rr(d,(1505,270,1845,810))
  v.text(d,(1535,310),'C[0][0]',32,v.CYAN,True)
  v.text(d,(1535,390),'80',112,v.INK,True)
  v.text(d,(1535,555),'0x00000050',29,v.MUTED,mono=True)
  v.para(d,(1535,650),'Result latched when done pulses.',29,280)
 elif k=='top_zoom':
  pic=Image.open(ROOT/'report/figures/fig3_top_waveform.png').convert('RGB')
  # Preserve the report's labels while enlarging its busy/done/state and result rows.
  for crop,box,label in [((0,165,1100,305),(80,280,1840,504),'BUSY / DONE / STATE'),((0,430,1100,480),(80,620,1840,700),'RESULT REGISTER')]:
   v.text(d,(80,box[1]-45),label,25,v.CYAN,True)
   part=pic.crop(crop).resize((box[2]-box[0],box[3]-box[1]),Image.Resampling.LANCZOS);im.paste(part,(box[0],box[1]))
  v.text(d,(85,790),'The lowest 32-bit word encodes 80 as hexadecimal 00000050.',33,v.CYAN,True)
 if k in ('top_waveform','top_zoom','pe_waveform'):
  v.text(d,(75,850),'SOURCE: existing report waveform figure / not a fresh simulator capture',20,v.MUTED)
 return im

def frame(t,cache):
 ix=bisect.bisect_right(SSTARTS,t)-1;scene=SCENES[ix];k=scene[1];local=t-scene[0]
 if ix not in cache:cache[ix]=custom_base(scene) if k in CUSTOM else v.base(scene)
 im=cache[ix].copy();d=ImageDraw.Draw(im)
 if k in ('title','concept','grid','flow','reuse'):
  x,y,cell=(1120,265,132) if k=='title' else (1040,260,128)
  cyc=int(local*.7)%10
  for r in range(4):
   for c in range(4):
    if r+c<=cyc<=r+c+3:d.rounded_rectangle((x+c*cell-3,y+r*cell-3,x+c*cell+103,y+r*cell+103),radius=17,outline=v.CYAN,width=4)
    if c<3:v.dot(d,(x+c*cell+102,y+r*cell+47),(x+(c+1)*cell-5,y+r*cell+47),(local*.7)%1,v.CYAN,5)
    if r<3:v.dot(d,(x+c*cell+47,y+r*cell+102),(x+c*cell+47,y+(r+1)*cell-5),(local*.7)%1,v.BLUE,5)
 if k=='sum_graph':
  vals=[0,16,40,64,80];coords=[(230+i*265,705-val/80*380) for i,val in enumerate(vals)]
  progress=min(4,max(0,(t-at(9))/(at(11)-at(9))*4.8))
  pts=[coords[0]]
  for i in range(1,min(4,int(progress))+1):pts.extend([(coords[i][0],coords[i-1][1]),coords[i]])
  if len(pts)>1:d.line(pts,fill=v.CYAN,width=7)
  for i in range(min(4,int(progress))+1):
   x,y=coords[i];d.ellipse((x-9,y-9,x+9,y+9),fill=v.CYAN);v.center(d,(x,y-34),vals[i],35,v.INK,True)
 if k=='skew':
  for r in range(4):v.dot(d,(460,337+r*118),(1430,337+r*118),(local*.23-r*.12)%1,v.CYAN,9)
 if k=='fsm':
  p=(local%12)/12;active=0 if p<.08 else 1 if p<.17 else 2 if p<.46 else 3;x=90+active*455
  d.rounded_rectangle((x-4,351,x+394,629),radius=24,outline=v.CYAN,width=5)
 if k=='timing_waveform':
  x=340+min(13,local/4*13)*100;d.line((x,305,x,770),fill=v.GOLD,width=3)
 if k=='top_waveform':
  x=340+min(1,local/7.5)*1020;d.line((x,300,x,817),fill=v.GOLD,width=3)
 ci=bisect.bisect_right(STARTS,t)-1
 if ci<0:speaker='Aman Soni'
 else:speaker=CUES[ci]['speaker']
 color=v.CYAN if speaker=='Aman Soni' else v.BLUE if speaker=='Mayank Sharma' else v.GOLD
 v.rr(d,(1390,30,1850,85),'#16253b',None,25);d.ellipse((1410,45,1430,65),fill=color);v.text(d,(1448,43),speaker,27,v.INK,True)
 d.rectangle((0,870,1920,1080),fill='#080d18')
 if ci>=0 and t<CUES[ci]['end']:
  lines=v.wrap(CUES[ci]['text'],42,1730);assert len(lines)<=2
  yy=931-(len(lines)-1)*28
  for j,line in enumerate(lines):v.center(d,(960,yy+j*56),line,42,v.INK)
 stage='PROJECT IDEA' if t<at(7) else 'PROCESSING ELEMENT' if t<at(16) else 'ARRAY ARCHITECTURE' if t<at(29) else 'CONTROLLER' if t<at(39) else 'VERIFICATION' if t<at(50) else 'PHASE 1 AND NEXT STEPS'
 v.text(d,(73,1015),stage,21,color,True)
 v.center(d,(1795,1028),f'{int(t)//60}:{int(t)%60:02} / 4:55',22,v.MUTED)
 d.rectangle((70,1060,1850,1064),fill=v.BORDER);d.rectangle((70,1060,70+1780*t/DURATION,1064),fill=color)
 return im

def main():
 p=argparse.ArgumentParser();p.add_argument('--preview',action='store_true');args=p.parse_args()
 TMP.mkdir(parents=True,exist_ok=True)
 old=json.loads((OUT/'MCA_Voiceover_Timing.json').read_text())['captions']
 assert [c['text'] for c in CUES]==[c['text'] for c in old],'Caption wording changed'
 cache={}
 if args.preview:
  for t in [54,59,84,133,190,246,253,270,292]:frame(t,cache).save(TMP/f'final_preview_{t:03}.jpg',quality=94)
  print('Previewed new visuals; all 57 caption texts unchanged.');return
 prepare_voiceover()
 (OUT/'MCA_Final_Captions.srt').write_text('\n\n'.join(f"{i+1}\n{v.stamp(c['start'])} --> {v.stamp(c['end'])}\n{c['text']}" for i,c in enumerate(CUES))+'\n')
 sections=[(0,at(7),'Aman Soni - Introduction'),(at(7),at(16),'Aman Soni - Processing Element'),(at(16),at(29),'Mayank Sharma - Array'),(at(29),at(39),'Ankit Kumar Pandey - Controller'),(at(39),at(50),'Ankit Kumar Pandey - Verification'),(at(50),DURATION,'Mayank Sharma - Conclusion')]
 meta=[';FFMETADATA1','title=MCA Systolic Array Final Team Video','artist=Aman Soni, Mayank Sharma, Ankit Kumar Pandey']
 for a,b,title in sections:meta+=['[CHAPTER]','TIMEBASE=1/1000',f'START={round(a*1000)}',f'END={round(b*1000)}',f'title={title}']
 (TMP/'final_chapters.txt').write_text('\n'.join(meta))
 final=OUT/'MCA_Final_With_Team_Voiceovers_1080p.mp4'
 cmd=['ffmpeg','-hide_banner','-v','warning','-y','-f','rawvideo','-pix_fmt','rgb24','-s','1920x1080','-r',str(FPS),'-i','pipe:0','-i',str(TMP/'final_voiceover.wav'),'-f','ffmetadata','-i',str(TMP/'final_chapters.txt'),'-map','0:v','-map','1:a','-map_metadata','2','-map_chapters','2','-c:v','libx264','-preset','veryfast','-crf','19','-pix_fmt','yuv420p','-r','30','-c:a','aac','-b:a','192k','-t',str(DURATION),'-movflags','+faststart',str(final)]
 with open(TMP/'final_render.log','w') as log:
  process=subprocess.Popen(cmd,stdin=subprocess.PIPE,stderr=log)
  try:
   for i in range(math.ceil(DURATION*FPS)):
    process.stdin.write(frame(i/FPS,cache).tobytes())
    if i%(10*FPS)==0:print(f'Rendered {i/FPS:.0f}/{DURATION} seconds',flush=True)
   process.stdin.close();rc=process.wait()
  except Exception:process.kill();raise
 if rc:raise RuntimeError((TMP/'final_render.log').read_text())
 manifest={'duration_seconds':DURATION,'script_wording':'unchanged existing captions','audio_processing':'leading/trailing silence trims, mild noise reduction, -16 LUFS loudness normalization; no speed or pitch changes','clips':SYNC['clips'],'caption_count':len(CUES),'scenes':[{'start':s[0],'type':s[1]} for s in SCENES]}
 (OUT/'MCA_Final_Edit_Notes.json').write_text(json.dumps(manifest,indent=2))
 print('FINAL VIDEO READY',final,final.stat().st_size,flush=True)

if __name__=='__main__':main()
