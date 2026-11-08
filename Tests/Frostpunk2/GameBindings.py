#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Read-only UHT binding inspection of the single identified original image.

No game is launched and no game bytes are modified. The pointer decoding is
specific to this image's DYLD_CHAINED_PTR_64_OFFSET rebases. Output is analysis,
not an assertion that any trainer effect has been tested in game.
"""
import argparse, bisect, json, re, struct
from capstone import Cs, CS_ARCH_ARM64, CS_MODE_ARM
from Inspect import Image
BASE = 0x100000000
PATTERN = (r'^(ChangeStockpile(?:Internal)?|GetCityStockpileOfResource|TryChangeCityStockpile|'
           r'SetStatisticValuesInstantly(?:Internal)?|SetTargetStatisticValue(?:Internal)?|'
           r'GetCurrentStatisticValue|GetTargetStatisticValue|GetSupportedStatistics|'
           r'ChangeCommunitySize|GetCommunitySize|ChangeCommunityStanding|GetCommunityStanding|'
           r'DecreaseWear|GetWearAmount|GetWearMinValue|GetWearMaxValue|'
           r'SetAlwaysPassPolicyCheat|SetInstantResearchEnabled|FinishCurrentResearch|'
           r'SetInstantExplorationEnabled|SetInstantUpgradeConstructionCheat|'
           r'ToggleInstant(?:Building|District|AreaExpander|Enhancement|Trail)ConstructionCheat|'
           r'GetDeconstructionProgress|GetDeconstructionTimeLeft|UpdateNoCooldownCheat|'
           r'ResetCooldown|SetGameSpeedLevel|GetGameSpeedLevel|GetCheatActorForCity|'
           r'GetCityTensionStatistic|GetGenerator|GetGameContext|GetMainCity|GetCurrentCity|GetCityNation|GetPlayerNation|GetNationMainCity|GetNation|SetInstantPolicyPassingCheat|SkipRecessTime|RequestSession|GetCurrentParliament|GetAllCommunitiesComponentsInParliament)$')
TYPES={0:'byte',1:'int8',2:'int16',3:'int32',4:'int64',5:'uint16',6:'uint32',7:'uint64',
       10:'float32',11:'float64',12:'bool',17:'UClass*',18:'UObject*',
       20:'FName',21:'FString',22:'array',23:'map',24:'set',25:'struct',29:'FText',30:'enum'}

def ptr(raw):
    if not raw or raw >> 63: return 0
    return BASE + (raw & 0xfffffffff)

def register_constant(m, function, register):
    values={}
    for ins in Cs(CS_ARCH_ARM64,CS_MODE_ARM).disasm(m.bytes(function,400),function):
        parts=[x.strip() for x in ins.op_str.split(',')]
        if ins.mnemonic in ('adrp','adr'):
            values[parts[0]]=int(parts[1][1:],0)
        elif ins.mnemonic=='add' and len(parts)==3 and parts[1] in values and parts[2].startswith('#'):
            values[parts[0]]=values[parts[1]]+int(parts[2][1:],0)
        if ins.mnemonic=='bl' and register in values:return values[register]
    return 0

def class_name(m, owner):
    try:
        metadata=register_constant(m,owner,'x1')
        static_class=ptr(m.u64(metadata))
        string=register_constant(m,static_class,'x1')
        data=m.bytes(string,180)
        end=next(i for i in range(0,len(data)-1,2) if data[i:i+2]==b'\0\0')
        name=data[:end].decode('utf-16-le')
        return name if name.startswith('PX') else ''
    except (ValueError,StopIteration,UnicodeError):return ''

def bool_offset(m, definition):
    setter=ptr(m.u64(definition+56))
    if not setter:return None
    for ins in Cs(CS_ARCH_ARM64,CS_MODE_ARM).disasm(m.bytes(setter,32),setter):
        match=re.fullmatch(r'w[0-9]+, \[x0(?:, #(0x[0-9a-f]+|[0-9]+))?\]',ins.op_str)
        if ins.mnemonic=='strb' and match:return int(match[1],0) if match[1] else 0
        if ins.mnemonic=='ret':break
    return None

def is_exec(instructions):
    frame={'x1'}
    for ins in instructions:
        parts=[x.strip() for x in ins.op_str.split(',')]
        if ins.mnemonic=='mov' and len(parts)==2 and parts[1] in frame:frame.add(parts[0])
        if ins.mnemonic=='ldr' and any(', ['+reg+', #0x20]' in ins.op_str for reg in frame):return True
        if ins.mnemonic=='ret':return False
    return False

def inspect(pattern=PATTERN):
    m=Image(); names={v-BASE:n for v,n in m.names(pattern)}
    lo,hi=next((x[2],x[2]+x[3]) for x in m.sections if x[0]=='__text')
    execs={}; metadata={}
    for sec,seg,va,n,o in m.sections:
        if seg!='__DATA_CONST': continue
        for i in range(o,o+n-16,8):
            raw,nxt=struct.unpack_from('<QQ',m.data,i)
            if raw & 0xfffffffff not in names: continue
            name=names[raw&0xfffffffff];a=va+i-o;f=ptr(nxt)
            if lo<=f<hi:
                code=m.bytes(f,256)
                # UFunction construction singletons follow the name in a second
                # table; those are not native exec callbacks.
                ins=list(Cs(CS_ARCH_ARM64,CS_MODE_ARM).disasm(code,f))
                if is_exec(ins):execs.setdefault(name,[]).append((a,f))
            if i>=o+16:
                owner=ptr(m.u64(a-16))
                count,size=struct.unpack('<HH',m.bytes(a+0x20,4))
                if lo<=owner<hi and count<=32 and size<=4096:
                    array=ptr(m.u64(a+0x18));props=[]
                    if count and not array:continue
                    try:
                        for j in range(count):
                            p=ptr(m.u64(array+j*8));pn=m.string(ptr(m.u64(p)))
                            flags=struct.unpack('<I',m.bytes(p+24,4))[0]
                            offset=struct.unpack('<H',m.bytes(p+50,2))[0]
                            props.append({'name':pn,'type':TYPES.get(flags&0x3f,hex(flags&0x3f)),
                                          'offset':bool_offset(m,p) if flags&0x3f==12 else offset,
                                          'definition':hex(p),'genFlags':hex(flags)})
                    except ValueError:continue
                    metadata.setdefault(name,[]).append({'definition':hex(a-16),'ownerGetter':hex(owner),'ownerClass':class_name(m,owner),
                                                       'parameterSize':size,'parameters':props})
    result=[];cs=Cs(CS_ARCH_ARM64,CS_MODE_ARM)
    for name in sorted(set(metadata)|set(execs)):
        row={'name':name,'metadata':metadata.get(name,[]),'execs':[]}
        for table,f in execs.get(name,[]):
            targets=[]
            end=m.starts[bisect.bisect_right(m.starts,f)]
            for ins in cs.disasm(m.bytes(f,min(2048,end-f)),f):
                if ins.mnemonic in ('bl','b') and ins.op_str.startswith('#'):
                    targets.append((ins.address,ins.mnemonic,int(ins.op_str[1:],0)))
                if ins.mnemonic=='ret':break
            row['execs'].append({'registration':hex(table),'address':hex(f),'bytes16':m.bytes(f,16).hex(),
                                 'branches':[(hex(a),op,hex(t)) for a,op,t in targets]})
        result.append(row)
    return result
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--pattern',default=PATTERN)
    p.add_argument('--verify-header');a=p.parse_args()
    if a.verify_header:
        from pathlib import Path
        m=Image(); source=Path(a.verify_header).read_text();count=0
        for name,address,values in re.findall(r'\{"([^"]+)", UINT64_C\((0x[0-9a-f]+)\), \{([^}]+)\}\}',source):
            expected=bytes(int(x.strip(),0) for x in values.split(','))
            assert len(expected)==16,(name,'signature length')
            assert m.bytes(int(address,0),16)==expected,(name,'instruction mismatch')
            count+=1
        assert count>0,'No bindings found'
        layouts=0
        for owner,name,address,size,n,body in re.findall(r'\{"(PX[^"]+)", "([^"]+)", UINT64_C\((0x[0-9a-f]+)\), ([0-9]+), ([0-9]+), \{(.*)\}\},',source):
            address=int(address,0);size=int(size);n=int(n)
            assert m.string(ptr(m.u64(address+16)))==name,(name,'metadata name')
            assert class_name(m,ptr(m.u64(address)))==owner,(name,'owner class')
            assert struct.unpack('<HH',m.bytes(address+48,4))==(n,size),(name,'parameter layout size')
            parameters=re.findall(r'\{"([^"]+)", "([^"]+)", ([0-9]+|UINT16_MAX)\}',body)
            assert len(parameters)==n,(name,'parameter count')
            array=ptr(m.u64(address+40))
            for j,(pn,pt,po) in enumerate(parameters):
                p=ptr(m.u64(array+j*8));flags=struct.unpack('<I',m.bytes(p+24,4))[0]&63
                assert m.string(ptr(m.u64(p)))==pn,(name,'parameter name')
                assert TYPES.get(flags,hex(flags))==pt,(name,'parameter type')
                off=bool_offset(m,p) if flags==12 else struct.unpack('<H',m.bytes(p+50,2))[0]
                assert po=='UINT16_MAX' or int(po)==off,(name,'parameter offset')
            layouts+=1
        print(f'{count} original instruction signatures and {layouts} UHT layouts verified; no game executed.')
    else:print(json.dumps(inspect(a.pattern),indent=2))
