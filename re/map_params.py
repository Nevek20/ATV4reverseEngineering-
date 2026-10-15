import struct, re, json
from capstone import *
from elftools.elf.elffile import ELFFile
data=open('SCES_546.88','rb').read()
e=ELFFile(open('SCES_546.88','rb'))
s=e.get_section_by_name('.game_overlay'); base=s['sh_addr']; off=s['sh_offset']; size=s['sh_size']
def rd(va,n): return data[off+va-base:off+va-base+n]
def cstr(va):
    b=rd(va,80); return b[:b.index(0)].decode('latin1') if 0 in b else None
# strings: all printable C strings in the physics region
strs={}
for m in re.finditer(rb'[A-Za-z_%0-9]{3,}\x00', data[off+0x4815e0:off+0x4840e0]):
    strs[0x5815e0+m.start()]=m.group()[:-1].decode()
md=Cs(CS_ARCH_MIPS, CS_MODE_MIPS64+CS_MODE_LITTLE_ENDIAN); md.detail=False; md.skipdata=True
# find code refs (lui+addiu) to strings across overlay
code=rd(base,size)
refs=[]
for k in range(0,size-4,4):
    w=struct.unpack_from('<I',code,k)[0]
    if (w>>26)==0x09:
        rs=(w>>21)&31; lo=w&0xffff
        for b in range(1,16):
            if k-4*b<0: break
            w2=struct.unpack_from('<I',code,k-4*b)[0]
            if (w2>>26)==0x0f and ((w2>>16)&31)==rs:
                va=((w2&0xffff)<<16)+(lo-0x10000 if lo&0x8000 else lo)
                if va in strs: refs.append((base+k,va))
                break
print('refs',len(refs), hex(min(r[0] for r in refs)), hex(max(r[0] for r in refs)))
lo_=min(r[0] for r in refs)-0x400; hi_=max(r[0] for r in refs)+0x400
# linear symbolic scan
regs={}; fregs={}
rows=[]
def f32(x): return struct.unpack('<f',struct.pack('<I',x))[0]
cur_str=None
for i in md.disasm(rd(lo_,hi_-lo_), lo_):
    m,o=i.mnemonic,i.op_str
    ops=[p.strip() for p in o.split(',')]
    try:
        if m=='lui': regs[ops[0]]=('imm',int(ops[1],0)<<16)
        elif m in('addiu','daddiu') and len(ops)==3:
            src=regs.get(ops[1]); imm=int(ops[2],0)
            if src and src[0]=='imm': regs[ops[0]]=('imm',(src[1]+imm)&0xffffffff)
            else: regs[ops[0]]=('ptr',ops[1],imm)
        elif m=='ori' and len(ops)==3:
            src=regs.get(ops[1])
            regs[ops[0]]=('imm',(src[1]|int(ops[2],0))) if src and src[0]=='imm' else None
        elif m=='mtc1':
            src=regs.get(ops[0]); fregs[ops[1]]=f32(src[1]) if src and src[0]=='imm' else None
        elif m=='mov.s': fregs[ops[0]]=fregs.get(ops[1])
        elif m=='lw' and ops[0]=='$v0':
            mm=re.match(r'(-?0x[0-9a-f]+|\d+)\((\$\w+)\)',ops[1]); regs['$v0']=('slot',int(mm.group(1),0)) if mm else None
        elif m in ('move','or') and len(ops)>=2:
            regs[ops[0]]=regs.get(ops[1])
        elif m=='jalr' or m=='jal':
            a1=regs.get('$a1'); a2=regs.get('$a2'); slot=regs.get('$v0') if m=='jalr' else ('jal',o)
            name=strs.get(a1[1]) if a1 and a1[0]=='imm' else None
            if name:
                rows.append(dict(at=hex(i.address),name=name,dst=(a2[1],hex(a2[2])) if a2 and a2[0]=='ptr' else str(a2),
                    slot=slot, f12=fregs.get('$f12'), f13=fregs.get('$f13')))
            # a0..a3, v0,v1 clobbered but delay slot executes before call; keep simple
    except Exception as ex:
        pass
json.dump(rows,open('/home/claude/re/param_map.json','w'),indent=0,default=str)
for r in rows: print(r['at'], r['name'], r['dst'], r['slot'], r['f12'], r['f13'])
