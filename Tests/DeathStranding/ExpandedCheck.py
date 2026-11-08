#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Explicit live checks of native time and capacity; never starts/stops a game.

Run only in the authorized candidate with Sam safely standing on land. Original
choices and capacity bases are restored. This does not establish weapon, vehicle,
or cargo durability effects.
"""
from pathlib import Path
import argparse,json,time

def main(root):
    def load(name):return json.loads((root/name).read_text())
    initial=load('NativeState.json');launch=load('Launch.json')
    assert initial['session']==launch['environment']['MHT_SESSION'],'wrong session'
    owner=initial['state']['owner']
    def states():
        n,r=load('NativeState.json'),load('RuntimeState.json')
        assert n['pid']==r['pid']==initial['pid'] and n['session']==r['session']==initial['session'],'test instance changed'
        assert n['state'].get('owner')==owner,'player owner changed'
        return n['state'],r['state']
    def send(commands):
        serial=load('Requests.json')['serial']+1
        stage=root/'Requests.next.json';stage.write_text(json.dumps(dict(serial=serial,commands=commands)));stage.replace(root/'Requests.json')
    def wait(predicate,label):
        deadline=time.monotonic()+8
        while time.monotonic()<deadline:
            n,r=states()
            if predicate(n,r):return n,r
            time.sleep(.05)
        raise RuntimeError(label)
    def select(feature,wanted,value=None):
        # Distributed notifications are asynchronous. Confirm each change before
        # posting the next instead of assuming a burst preserves delivery order.
        _,r=states()
        if value is not None and r['features'][feature]['value']!=value:
            send([dict(action='value',feature=feature,value=value)])
            wait(lambda n,r:r['features'][feature]['value']==value,'numeric value')
        _,r=states()
        if r['features'][feature]['wanted']!=wanted:send([dict(action='set',feature=feature,wanted=wanted)])
        return wait(lambda n,r:r['features'][feature]['wanted']==wanted and (value is None or r['features'][feature]['value']==value),'selection')
    def close(a,b):return len(a)==len(b) and all(abs(x-y)<.01 for x,y in zip(a,b))
    baseline,presentation=states();original={i:presentation['features'][i] for i in (5,23)}
    assert presentation['ready'] and all(original[i]['available'] for i in original),'expanded candidate unavailable'
    assert not any(original[i]['wanted'] for i in original),'begin with capacity and speed off'
    assert close(baseline['timeScales'],[1,1,1]),'begin at normal engine speed'
    results=[]
    try:
        for value in (.5,1.5):
            select(23,True,value)
            n,_=wait(lambda n,r:close(n['timeScales'],[value]*3) and r['features'][23]['active'],'native time request')
            results.append(dict(speed=value,actual=n['timeScales']))
        select(23,False)
        wait(lambda n,r:close(n['timeScales'],[1]*3) and not r['features'][23]['active'],'native time request retirement')
        for value in (150,180):
            select(5,True,value)
            n,_=wait(lambda n,r:close(n['capacityBases'],[value]*2) and n['capacityLimits'][1]>=value-.01 and r['features'][5]['active'],'native effective capacity')
            results.append(dict(capacity=value,bases=n['capacityBases'],effective=n['capacityLimits']))
        select(5,False)
        n,_=wait(lambda n,r:close(n['capacityBases'],baseline['capacityBases']) and close(n['capacityLimits'],baseline['capacityLimits'])
            and not r['features'][5]['active'],'capacity restoration')
        print(json.dumps(dict(pid=initial['pid'],results=results,restoredBases=n['capacityBases'],restoredLimits=n['capacityLimits'])))
        print('PASS: actual engine time scales, original capacity calculation, value changes and restoration. Visual gameplay confirmation remains separate.')
    finally:
        for i,f in original.items():select(i,f['wanted'],f['value'])
        wait(lambda n,r:close(n['timeScales'],baseline['timeScales']) and close(n['capacityBases'],baseline['capacityBases']),'final restoration')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('root',type=Path);args=parser.parse_args();main(args.root.resolve())
