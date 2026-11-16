#!/usr/bin/env python3
"""Render the team's 4m40 captioned prototype film from the reviewed script.

Dependencies: Pillow, ffmpeg. No network calls, generated imagery, or simulated
terminal evidence. Diagrams are explanatory; recorded results are sourced from
the repository README and the waveform is explicitly the report figure.
"""
from pathlib import Path
import argparse
import bisect
import json
import math
import re
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/video'
TMP = Path('/tmp/mca_video_build')
W,H,FPS,DURATION = 1920,1080,15,280
BG='#0a1020'; PANEL='#131f34'; BORDER='#283b54'; INK='#f4f7fc'
MUTED='#a8b9d0'; CYAN='#55e0c1'; BLUE='#64b6ff'; GOLD='#ffc36b'; PURPLE='#bba6ff'
FONT='/System/Library/Fonts/Supplemental/Arial.ttf'
BOLD='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
MONO='/System/Library/Fonts/Menlo.ttc'
FONTS={}
def font(size,bold=False,mono=False):
    key=(size,bold,mono)
    if key not in FONTS: FONTS[key]=ImageFont.truetype(MONO if mono else BOLD if bold else FONT,size)
    return FONTS[key]
def text(d,xy,s,size=32,fill=INK,bold=False,mono=False,anchor=None):
    d.text(xy,str(s),font=font(size,bold,mono),fill=fill,anchor=anchor)
def center(d,xy,s,size=32,fill=INK,bold=False,mono=False):
    text(d,xy,s,size,fill,bold,mono,'mm')
def rr(d,box,fill=PANEL,outline=BORDER,r=22,width=2):
    d.rounded_rectangle(box,radius=r,fill=fill,outline=outline,width=width)
def wrap(s,size,maxwidth,bold=False):
    f=font(size,bold); lines=[]; line=''
    for word in s.split():
        test=(line+' '+word).strip()
        if f.getlength(test)>maxwidth and line: lines.append(line);line=word
        else: line=test
    if line:lines.append(line)
    return lines
def para(d,xy,s,size=32,width=650,fill=MUTED,lineheight=None,bold=False):
    for i,line in enumerate(wrap(s,size,width,bold)):
        text(d,(xy[0],xy[1]+i*(lineheight or int(size*1.4))),line,size,fill,bold)
def arrow(d,a,b,color=CYAN,width=4):
    d.line([a,b],fill=color,width=width)
    theta=math.atan2(b[1]-a[1],b[0]-a[0]); length=14
    p=[b,(b[0]-length*math.cos(theta-.5),b[1]-length*math.sin(theta-.5)),(b[0]-length*math.cos(theta+.5),b[1]-length*math.sin(theta+.5))]
    d.polygon(p,fill=color)
def dot(d,a,b,q,color=CYAN,r=7):
    x=a[0]+(b[0]-a[0])*q;y=a[1]+(b[1]-a[1])*q
    d.ellipse((x-r,y-r,x+r,y+r),fill=color)

SECTIONS=[(0,35,'Aman Soni','Project idea'),(35,85,'Aman Soni','Processing element'),(85,155,'Mayank Sharma','Array architecture'),(155,200,'Ankit Kumar Pandey','Controller'),(200,255,'Ankit Kumar Pandey','Verification'),(255,280,'Mayank Sharma','Phase 1 and next steps')]

def narration():
    source=(ROOT/'docs/TEAM_VIDEO_SCRIPT.md').read_text()
    blocks=[]
    for b in source.split('\n## '):
        lines=[l[2:] for l in b.splitlines() if l.startswith('> ')]
        if lines:blocks.append(' '.join(lines).replace('“','').replace('”',''))
    assert len(blocks)==6
    # Preserve the story while matching evidence that can be shown in this film.
    blocks[4]=blocks[4].replace('Here is the complete system test.','Here is the complete system testbench.').replace('The terminal shows this test passing, followed by all nine system tests passing.','The documented run shows this test passing, followed by all nine system tests passing.').replace('In the waveform,','In the report waveform,')
    return blocks

def make_captions():
    cues=[];voice=[]
    for sec,words in zip(SECTIONS,narration()):
        start,end,speaker,label=sec
        sentences=re.split(r'(?<=[.!?])\s+',words)
        chunks=[]
        for sentence in sentences:
            # Captions remain short and complete; split long sentences at clauses.
            parts=re.split(r'(?<=[,;:])\s+',sentence) if len(sentence)>108 else [sentence]
            line=''
            for p in parts:
                if len((line+' '+p).strip())>108 and line:chunks.append(line);line=p
                else:line=(line+' '+p).strip()
            if line:chunks.append(line)
        weights=[len(c.split())+.8 for c in chunks]
        available=end-start-1.0
        pos=start+.35
        for c,weight in zip(chunks,weights):
            dur=available*weight/sum(weights)
            cues.append({'start':round(pos,3),'end':round(pos+dur,3),'speaker':speaker,'text':c})
            pos+=dur
        voice.append({'start':start,'end':end,'speaker':speaker,'section':label,'text':words})
    return cues,voice

def stamp(t):
    ms=round(t*1000);h,ms=divmod(ms,3600000);m,ms=divmod(ms,60000);s,ms=divmod(ms,1000)
    return f'{h:02}:{m:02}:{s:02},{ms:03}'

SCENES=[
 (0,'title','Sixteen answers. One story.','Follow C[0][0] from operands to result'),
 (8,'team','Three people. One accelerator.','MCA Phase 1 / Verilog HDL prototype'),
 (21,'concept','Compute where the data flows','4×4 mesh / signed INT8 operands / INT32 sums'),
 (35,'pe_intro','Start with one processing element','Aman Soni / Datapath RTL'),
 (42,'mac','How does eighty happen?','First row of A × first column of B'),
 (61,'datapath','Signed multiply. Wide accumulation.','Each PE retains its own partial sum'),
 (71,'valid','Only valid pairs contribute','Actual source / rtl/processing_element.v'),
 (80,'pe_tests','Verify the building block','Unit testbench / 10 directed cases'),
 (85,'grid','From one PE to sixteen','Mayank Sharma / Systolic array architecture'),
 (94,'flow','A moves right. B moves down.','Output-stationary dataflow / partial sums remain local'),
 (114,'reuse','Reuse the operands along the way','PE(0,0) builds 80 while the wave reaches other PEs'),
 (126,'skew','The right operands at the right time','Internal row and column delays: 0 / 1 / 2 / 3 cycles'),
 (144,'scoreboard','Check every clock edge','Core scoreboard / 105 matrices and control scenarios'),
 (155,'integration','Coordinate the whole accelerator','Ankit Kumar Pandey / Control RTL and system verification'),
 (163,'fsm','Clear. Load. Drain. Capture.','Four-state controller / documented 14-cycle sequence'),
 (179,'handshake','A small interface with clear meaning','start is an input / busy and done are outputs'),
 (189,'golden','A separate software reference','40 directed and random reference vectors'),
 (200,'testbench','Compare all sixteen answers','Actual source / testbench/tb_systolic_array.v'),
 (210,'results','Return to our example','Expected matrix for the existing positive Test 2'),
 (225,'system_tests','Check more than easy inputs','Documented repository results / 9 system tests'),
 (236,'waveform','Watch the operation complete','Repository report waveform figure / explanatory reproduction'),
 (250,'metrics','Evidence at three RTL levels','Recorded results in README and Phase 1 report'),
 (255,'finish','From four products to one answer','C[0][0] = 80 / the array produces sixteen outputs'),
 (264,'roadmap','Phase 1 built. Next steps defined.','RTL and simulation now / FPGA measurements next'),
 (274,'end','Thank you','Aman Soni / Mayank Sharma / Ankit Kumar Pandey'),
]

A=[[4*r+c+1 for c in range(4)] for r in range(4)]
B=[[16-(4*r+c) for c in range(4)] for r in range(4)]
C=[[sum(A[r][k]*B[k][c] for k in range(4)) for c in range(4)] for r in range(4)]

def matrix(d,x,y,values,title,cell=91,hi=None,color=CYAN):
    text(d,(x,y-55),title,29,MUTED,True)
    for r in range(4):
        for c in range(4):
            active=hi and hi(r,c)
            box=(x+c*cell,y+r*cell,x+(c+1)*cell-10,y+(r+1)*cell-10)
            rr(d,box,'#163c3e' if active else '#18263c',color if active else BORDER,r=13)
            center(d,((box[0]+box[2])/2,(box[1]+box[3])/2),values[r][c],31,color if active else INK,True)

def code(d,box,path,lines,highlights=()):
    rr(d,box,'#101a2c')
    text(d,(box[0]+28,box[1]+24),path,24,CYAN,mono=True)
    d.line((box[0]+25,box[1]+68,box[2]-25,box[1]+68),fill=BORDER,width=2)
    for i,l in enumerate(lines):
        y=box[1]+96+i*41
        if i in highlights:rr(d,(box[0]+18,y-4,box[2]-18,y+35),'#213b44',None,8)
        text(d,(box[0]+30,y),l,25,INK if i in highlights else MUTED,mono=True)

def card(d,box,kicker,value,detail,color=CYAN):
    rr(d,box)
    text(d,(box[0]+32,box[1]+28),kicker,26,color,True)
    text(d,(box[0]+32,box[1]+85),value,61,INK,True)
    para(d,(box[0]+32,box[1]+175),detail,28,box[2]-box[0]-64)

def grid(d,x=1000,y=260,cell=124,active=None,show_sums=False):
    for r in range(4):
        for c in range(4):
            xx=x+c*cell;yy=y+r*cell
            if c<3:arrow(d,(xx+100,yy+47),(xx+cell-5,yy+47),CYAN,3)
            if r<3:arrow(d,(xx+47,yy+100),(xx+47,yy+cell-5),BLUE,3)
            ac=(active is not None and r+c==active)
            rr(d,(xx,yy,xx+100,yy+100),'#174640' if ac else PANEL,CYAN if ac else BORDER,15)
            center(d,(xx+50,yy+36),f'PE {r},{c}',21,CYAN if ac else MUTED)
            center(d,(xx+50,yy+70),C[r][c] if show_sums else 'MAC',25,INK,True)

def base(scene):
    start,kind,title,sub=scene
    im=Image.new('RGB',(W,H),BG);d=ImageDraw.Draw(im)
    # Deliberately subtle drafting grid keeps the diagrams visually grounded.
    for x in range(0,W,80):d.line((x,0,x,850),fill='#0e192b')
    for y in range(0,850,80):d.line((0,y,W,y),fill='#0e192b')
    text(d,(70,42),'MCA  /  PHASE 01',25,CYAN,True)
    text(d,(70,102),title,57,INK,True)
    text(d,(73,178),sub,28,MUTED)
    if kind=='title':
        text(d,(110,300),'4×4',160,INK,True)
        text(d,(120,493),'SYSTOLIC ARRAY',46,CYAN,True)
        text(d,(120,555),'Matrix multiplication accelerator',34,MUTED)
        grid(d,1120,265,132)
        rr(d,(105,660,850,775),'#173a3b',CYAN)
        text(d,(135,687),'One output to follow:  C[0][0] = 80',37,CYAN,True)
    elif kind=='team':
        for i,(name,role,initials,col) in enumerate([('Aman Soni','Processing element','AS',CYAN),('Mayank Sharma','Array architecture','MS',BLUE),('Ankit Kumar Pandey','Controller and verification','AK',GOLD)]):
            x=80+i*590
            rr(d,(x,305,x+555,725))
            d.ellipse((x+38,350,x+148,460),fill='#21384b',outline=col,width=3)
            center(d,(x+93,405),initials,39,col,True)
            text(d,(x+36,500),name,36,INK,True)
            para(d,(x+36,570),role,30,480,col)
        text(d,(80,770),'Newton School of Technology, Sonipat',27,MUTED)
    elif kind in ('concept','grid','flow','reuse'):
        grid(d,1040,260,128,show_sums=kind=='reuse')
        if kind=='concept':
            text(d,(100,300),'C = A × B',76,INK,True)
            for i,(v,l,c) in enumerate([('16','processing elements',CYAN),('INT8','signed operands',BLUE),('INT32','local accumulators',GOLD)]):
                text(d,(110,430+i*107),v,49,c,True);text(d,(330,440+i*107),l,31,MUTED)
        elif kind=='grid':
            code(d,(80,270,950,770),'rtl/systolic_array.v',[
                'for (row = 0; row < 4; row = row + 1)',
                '  for (col = 0; col < 4; col = col + 1)',
                '    processing_element pe (',
                '      .a_in(a_link[row][col]),',
                '      .b_in(b_link[row][col]),',
                '      .acc_out(',
                '        acc_out[32*(4*row+col) +: 32])',
                '    );'],(0,1,6))
        else:
            text(d,(100,310),'A →',79,CYAN,True);text(d,(360,327),'across each row',34,MUTED)
            text(d,(100,438),'B ↓',79,BLUE,True);text(d,(360,455),'down each column',34,MUTED)
            rr(d,(95,585,910,775))
            para(d,(125,616),'Partial sums stay inside each PE. Neighbours reuse forwarded operands.',35,740,INK)
    elif kind in ('pe_intro','datapath'):
        if kind=='pe_intro':
            card(d,(90,275,790,785),'AMAN SONI','Processing element','Signed multiplication, accumulation, clock/reset, valid signals and forwarding.')
            rr(d,(1000,310,1720,725),'#163b3c',CYAN)
            center(d,(1360,395),'ONE PROCESSING ELEMENT',29,CYAN,True)
            center(d,(1360,505),'sum ← sum + A × B',47,INK,True)
            center(d,(1360,615),'A → east     B ↓ south',32,MUTED)
        else:
            boxes=[(90,345,460,605),(610,345,1040,605),(1200,345,1800,605)]
            for box,title,val,col in zip(boxes,['INPUTS','PRODUCT','ACCUMULATOR'],['signed 8-bit','signed 16-bit','signed 32-bit'],[BLUE,PURPLE,CYAN]):
                rr(d,box,outline=col);center(d,((box[0]+box[2])/2,405),title,27,col,True);center(d,((box[0]+box[2])/2,495),val,38,INK,True)
            arrow(d,(465,475),(600,475));arrow(d,(1045,475),(1190,475))
            center(d,(960,710),'Four signed INT8 products fit comfortably in each INT32 sum.',32,MUTED)
    elif kind=='mac':
        matrix(d,95,310,A,'A / highlight row 0',87,lambda r,c:r==0)
        matrix(d,570,310,B,'B / highlight column 0',87,lambda r,c:c==0,BLUE)
        rr(d,(1050,275,1810,790))
        text(d,(1090,310),'C[0][0]',34,CYAN,True)
        for i,(a,b) in enumerate(zip(A[0],[r[0] for r in B])):
            text(d,(1100,383+i*63),f'{a} × {b}',40,INK,True)
            text(d,(1320,390+i*63),f'= {a*b}',32,MUTED)
        text(d,(1490,375),'SUM',26,MUTED,True)
    elif kind=='valid':
        code(d,(80,270,1180,790),'rtl/processing_element.v',[
            'if (clear_acc) begin',
            "    acc_out <= 32'sd0;",
            'end else if (a_valid_in && b_valid_in) begin',
            '    acc_out <= acc_out +',
            '               {{16{product[15]}}, product};',
            'end',
            '',
            'a_out <= a_in;   b_out <= b_in;'],(2,3,4))
        card(d,(1230,290,1825,780),'CONTROL','VALID + VALID','Both operands valid → accumulate. Clear takes priority. Reset clears registers.')
    elif kind=='pe_tests':
        for i,(n,v,detail) in enumerate([('SIGNED ARITHMETIC','+ / − / 0','Positive, negative, zero and multi-cycle sums'),('CONTROL','Clear / reset','Valid suppression and clear priority'),('FORWARDING','A / B / valid','Registered operands and their valid flags')]):
            card(d,(80+i*595,295,640+i*595,765),n,v,detail,[CYAN,BLUE,GOLD][i])
    elif kind=='skew':
        for r in range(4):
            y=300+r*118
            text(d,(100,y+17),f'Row / column {r}',30,INK,True)
            for c in range(r):
                x=500+c*200;rr(d,(x,y,x+150,y+75),'#20334b',BLUE,12);center(d,(x+75,y+37),'1 cycle',27,BLUE,True)
                arrow(d,(x+153,y+37),(x+195,y+37),BLUE)
            arrow(d,(485+r*200,y+37),(1440,y+37),CYAN)
            rr(d,(1460,y,1790,y+75),'#17403d',CYAN,12);center(d,(1625,y+37),f'{r} delay stages',29,CYAN,True)
        text(d,(100,810),'Data and valid bits travel through the same delay stages.',31,MUTED)
    elif kind=='scoreboard':
        code(d,(80,270,1150,795),'testbench/tb_systolic_array_core.v',[
            'slot = cycle-r-c;',
            'if (history_av[slot][r] &&',
            '    history_bv[slot][c])',
            '  expected[4*r+c] = expected[4*r+c] +',
            '    history_a[slot][r]*history_b[slot][c];',
            '',
            'if (acc_out[...] !== expected[index])',
            '  $fatal(1, "... mismatch ...");'],(0,3,4))
        card(d,(1210,285,1820,780),'CORE COVERAGE','105 matrices','Cycle-by-cycle checking, valid masks, input bubbles, clear, reset and restart.',BLUE)
    elif kind=='integration':
        for box,name,desc in [((110,345,700,650),'CONTROLLER','Schedule / status / capture'),((1020,345,1810,650),'SYSTOLIC ARRAY','16 PEs / local partial sums')]:
            rr(d,box);center(d,((box[0]+box[2])/2,430),name,38,CYAN,True);center(d,((box[0]+box[2])/2,530),desc,30,MUTED)
        arrow(d,(710,420),(1005,420));text(d,(739,365),'data + valids',23,CYAN)
        arrow(d,(1005,590),(710,590),BLUE);text(d,(755,620),'16 results',24,BLUE)
        center(d,(960,755),'rtl/systolic_array_top.v',28,MUTED,mono=True)
    elif kind=='fsm':
        for i,(name,detail) in enumerate([('IDLE','Wait for start'),('CLEAR','Reset partial sums'),('LOAD','4 operand sets'),('DRAIN','8 cycles / capture')]):
            x=90+i*455;rr(d,(x,355,x+390,625));center(d,(x+195,435),name,42,INK,True);center(d,(x+195,535),detail,27,MUTED)
            if i<3:arrow(d,(x+395,490),(x+447,490))
        center(d,(960,735),'busy = 1 while active     •     done = one-cycle pulse',35,CYAN,True)
    elif kind=='handshake':
        for i,(key,val,desc,col) in enumerate([('start','INPUT','External pulse begins a transaction',BLUE),('busy','OUTPUT','High while the controller is active',GOLD),('done','OUTPUT','One cycle when the result is captured',CYAN)]):
            card(d,(80+i*595,285,640+i*595,785),val,key,desc,col)
    elif kind=='golden':
        card(d,(85,280,900,785),'PYTHON REFERENCE','40 vectors','20 directed corner cases + 20 random matrices. Reference values are distinct from RTL simulation results.',PURPLE)
        code(d,(970,280,1830,785),'verification/golden_model.py',[
            'for r in range(4):',
            '  for c in range(4):',
            '    acc = 0',
            '    for k in range(4):',
            '      acc += A[r][k] * B[k][c]',
            '    C[r][c] = acc'],(4,5))
    elif kind=='testbench':
        code(d,(90,270,1320,795),'testbench/tb_systolic_array.v',[
            'for (cr = 0; cr < 4; cr = cr + 1)',
            '  for (cc = 0; cc < 4; cc = cc + 1) begin',
            '    got = $signed(result[32*(4*cr+cc) +: 32]);',
            '    exp_val = C_exp[cr][cc];',
            '    if (got !== exp_val) begin',
            '      $display("FAIL test ...");',
            '      errors = errors + 1;',
            '    end',
            '  end'],(2,3,4))
        text(d,(1410,380),'16',128,CYAN,True);para(d,(1400,550),'outputs checked against expected values',34,410)
    elif kind in ('results','finish'):
        matrix(d,90,320,A,'INPUT A',99,lambda r,c:r==0)
        matrix(d,600,320,B,'INPUT B',99,lambda r,c:c==0,BLUE)
        text(d,(510,470),'×',54,MUTED)
        text(d,(1040,470),'=',54,MUTED)
        matrix(d,1165,320,C,'EXPECTED C / TEST 2',128,lambda r,c:r==0 and c==0)
        text(d,(90,790),'C[0][0] = 16 + 24 + 24 + 16 = 80',38,CYAN,True)
    elif kind=='system_tests':
        cases=['Identity × matrix','Zero × zero','Known positive matrix','Signed extremes: −128 / 127','Mixed positive / negative','Consecutive operation 1','Consecutive operation 2','Reset during computation','Result stability']
        for i,label in enumerate(cases):
            x=90+(i%3)*595;y=285+(i//3)*153
            rr(d,(x,y,x+560,y+120));text(d,(x+23,y+18),f'TEST {i}',21,CYAN,True);text(d,(x+23,y+58),label,27,INK,True)
        text(d,(100,800),'README recorded output: ALL TESTS PASSED (9 tests)',30,CYAN,mono=True)
    elif kind=='waveform':
        pic=Image.open(ROOT/'report/figures/fig3_top_waveform.png').convert('RGB')
        pic.thumbnail((1450,590),Image.Resampling.LANCZOS)
        im.paste(pic,(75,255))
        rr(d,(1550,280,1840,760))
        text(d,(1574,315),'FIRST WORD',24,CYAN,True)
        text(d,(1574,390),'80',90,INK,True)
        text(d,(1574,520),'0x00000050',26,MUTED,mono=True)
        para(d,(1574,610),'Captured result',28,240)
        text(d,(80,823),'Source: report/figures/fig3_top_waveform.png  •  report figure, not a new simulator capture',23,MUTED)
    elif kind=='metrics':
        for i,(n,v,s) in enumerate([('PE UNIT','10 tests','Arithmetic, reset and forwarding'),('ARRAY CORE','105 matrices','Cycle-by-cycle scoreboard'),('SYSTEM','9 tests','Integrated control and result checks')]):
            card(d,(80+i*595,305,640+i*595,770),n,v,s,[CYAN,BLUE,GOLD][i])
    elif kind=='roadmap':
        card(d,(90,290,900,780),'PHASE 1','RTL + simulation','Processing elements, array integration, controller and self-checking testbenches.',CYAN)
        card(d,(990,290,1820,780),'NEXT PHASE','FPGA deployment','Memory integration, matrix tiling, and measured frequency, resource use and power.',BLUE)
    elif kind=='end':
        center(d,(960,360),'4×4 Systolic Array Accelerator',65,INK,True)
        center(d,(960,465),'Verilog HDL  /  INT8 × INT8 → INT32',36,CYAN,True)
        center(d,(960,580),'Aman Soni   •   Mayank Sharma   •   Ankit Kumar Pandey',35,MUTED)
        center(d,(960,690),'github.com/MAYANKSHARMA01010/',31,INK)
        center(d,(960,739),'systolic-array-matrix-multiplication-accelerator',31,INK)
    return im

def render_frame(t,cache,cues,cstarts):
    ix=bisect.bisect_right([s[0] for s in SCENES],t)-1
    scene=SCENES[ix];kind=scene[1];local=t-scene[0]
    if ix not in cache: cache[ix]=base(scene)
    im=cache[ix].copy();d=ImageDraw.Draw(im)
    # Dynamic diagrams are educational animations rather than simulation traces.
    if kind in ('title','concept','grid','flow','reuse'):
        x,y,cell=(1120,265,132) if kind=='title' else (1040,260,128)
        cycle=int(local*.7)%10
        for r in range(4):
            for c in range(4):
                if r+c<=cycle<=r+c+3:
                    xx=x+c*cell;yy=y+r*cell
                    d.rounded_rectangle((xx-3,yy-3,xx+103,yy+103),radius=17,outline=CYAN,width=4)
                if c<3:dot(d,(x+c*cell+102,y+r*cell+47),(x+(c+1)*cell-5,y+r*cell+47),(local*.7)%1,CYAN,5)
                if r<3:dot(d,(x+c*cell+47,y+r*cell+102),(x+c*cell+47,y+(r+1)*cell-5),(local*.7)%1,BLUE,5)
    if kind=='mac':
        n=min(4,int(local/4.3)+1);sums=[16,40,64,80]
        for i in range(n):rr(d,(1077,375+i*63,1430,430+i*63),'#1d4442',CYAN,10)
        for i,(a,b) in enumerate(zip(A[0],[r[0] for r in B])):
            text(d,(1100,383+i*63),f'{a} × {b}',40,INK,True);text(d,(1320,390+i*63),f'= {a*b}',32,MUTED)
        center(d,(1598,515),sums[n-1],112,CYAN,True)
        center(d,(1585,650),f'{n} of 4 terms',25,MUTED)
    if kind=='fsm':
        p=(local%12)/12;active=0 if p<.08 else 1 if p<.17 else 2 if p<.46 else 3
        x=90+active*455
        d.rounded_rectangle((x-4,351,x+394,629),radius=24,outline=CYAN,width=5)
    if kind=='skew':
        for r in range(4):
            dot(d,(460,337+r*118),(1430,337+r*118),(local*.23-r*.12)%1,CYAN,9)
    if kind=='waveform':
        # Cursor movement is a presentation pointer across an existing report figure.
        xx=370+min(1,local/10)*970
        d.line((xx,330,xx,805),fill=GOLD,width=3)
    # Consistent speaker badge, progress and captions.
    sec=next(s for s in SECTIONS if s[0]<=t<s[1])
    speaker=sec[2];color=CYAN if speaker=='Aman Soni' else BLUE if speaker=='Mayank Sharma' else GOLD
    rr(d,(1390,30,1850,85),'#16253b',None,25)
    d.ellipse((1410,45,1430,65),fill=color)
    text(d,(1448,43),speaker,27,INK,True)
    d.rectangle((0,870,W,H),fill='#080d18')
    k=bisect.bisect_right(cstarts,t)-1
    if k>=0 and t<cues[k]['end']:
        lines=wrap(cues[k]['text'],42,1730)
        assert len(lines)<=2,(t,lines)
        yy=931-(len(lines)-1)*28
        for j,l in enumerate(lines):center(d,(960,yy+j*56),l,42,INK)
    text(d,(73,1015),sec[3].upper(),21,color,True)
    center(d,(1795,1028),f'{int(t)//60}:{int(t)%60:02} / 4:40',22,MUTED)
    d.rectangle((70,1060,1850,1064),fill=BORDER)
    d.rectangle((70,1060,70+1780*t/DURATION,1064),fill=color)
    # A short dip at scene changes avoids abrupt visual cuts without obscuring captions.
    fade=min(1,local/.25)
    if fade<1:
        upper=im.crop((0,90,W,860));upper=Image.blend(Image.new('RGB',upper.size,BG),upper,fade);im.paste(upper,(0,90))
    return im

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--preview',action='store_true');args=parser.parse_args()
    OUT.mkdir(exist_ok=True);TMP.mkdir(exist_ok=True)
    cues,voice=make_captions();cstarts=[c['start'] for c in cues]
    (OUT/'MCA_Captions.srt').write_text('\n\n'.join(f"{i+1}\n{stamp(c['start'])} --> {stamp(c['end'])}\n{c['text']}" for i,c in enumerate(cues))+'\n')
    (OUT/'MCA_Voiceover_Timing.json').write_text(json.dumps({'duration_seconds':DURATION,'sections':voice,'captions':cues},indent=2))
    recording=['# Voiceover recording guide','', 'The video is 4:40 with burned-in English captions and silent stereo audio. Record the paragraphs below to the matching captions. Only quoted narration is spoken.','', '| Speaker | Start | End | Duration |','|---|---|---|---|']
    for start,end,speaker,label in SECTIONS:recording.append(f'| {speaker} | {start//60}:{start%60:02} | {end//60}:{end%60:02} | {end-start}s |')
    for v in voice:recording.extend(['',f"## {v['speaker']} at {v['start']//60}:{v['start']%60:02}",'',v['text']])
    recording.extend(['','## Evidence shown in the video','','Architecture and dataflow scenes are explanatory animations. Verification summaries reproduce documented repository results. The waveform is the existing report figure, clearly labelled on screen; this video does not claim a fresh simulator run. The verification narration makes small wording adjustments to match these visuals.','','Add your voice recordings at the section start times above. Keep the video speed unchanged. Use the included SRT for exact phrase timings.'])
    (OUT/'MCA_Voiceover_Guide.md').write_text('\n'.join(recording)+'\n')
    cache={}
    if args.preview:
        for t in [3,12,27,37,49,65,75,82,89,103,120,135,149,158,170,182,195,204,219,231,244,252,259,269,277]:
            render_frame(t,cache,cues,cstarts).save(TMP/f'preview_{t:03}.jpg',quality=92)
        print('Preview frames ready',flush=True);return
    ffmeta=[';FFMETADATA1','title=MCA Phase 1 Systolic Array Accelerator','artist=Aman Soni, Mayank Sharma, Ankit Kumar Pandey','comment=Captioned 4m40 voiceover-ready prototype presentation.']
    for a,b,sp,label in SECTIONS:ffmeta.extend(['[CHAPTER]','TIMEBASE=1/1000',f'START={a*1000}',f'END={b*1000}',f'title={sp} - {label}'])
    (TMP/'chapters.txt').write_text('\n'.join(ffmeta))
    dest=OUT/'MCA_Prototype_Captioned_1080p.mp4'
    cmd=['ffmpeg','-hide_banner','-loglevel','warning','-y','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','pipe:0','-f','lavfi','-i','anullsrc=channel_layout=stereo:sample_rate=48000','-f','ffmetadata','-i',str(TMP/'chapters.txt'),'-map','0:v','-map','1:a','-map_metadata','2','-map_chapters','2','-c:v','libx264','-preset','veryfast','-crf','20','-pix_fmt','yuv420p','-r','30','-c:a','aac','-b:a','128k','-t',str(DURATION),'-movflags','+faststart',str(dest)]
    with open(TMP/'render.log','w') as log:
        p=subprocess.Popen(cmd,stdin=subprocess.PIPE,stderr=log)
        try:
            for i in range(DURATION*FPS):
                t=i/FPS;im=render_frame(t,cache,cues,cstarts);p.stdin.write(im.tobytes())
                if i%(FPS*10)==0:print(f'Rendered {int(t):03}/{DURATION} seconds',flush=True)
            p.stdin.close();rc=p.wait()
        except Exception:
            p.kill();raise
    if rc:raise RuntimeError((TMP/'render.log').read_text())
    print(f'FINISHED {dest} ({dest.stat().st_size} bytes)',flush=True)

if __name__=='__main__':main()
