#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Explicit live candidate test on safe ground; never launches or stops a game.

Requires the test-only StoreHarness and CandidateProbe. This checks
native reserve refill, not whether the player remains upright in flowing water.
The latter requires a separate observed water test. Other cheat choices stay as-is.
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
    def send(command):
        serial=load('Requests.json')['serial']+1
        stage=root/'Requests.next.json';stage.write_text(json.dumps(dict(serial=serial,commands=[command])));stage.replace(root/'Requests.json')
        return serial
    def wait(predicate,label):
        deadline=time.monotonic()+6
        while time.monotonic()<deadline:
            n,r=states()
            if predicate(n,r):return n,r
            time.sleep(.04)
        raise RuntimeError(label)
    def toggle(wanted):
        send(dict(action='set',feature=10,wanted=wanted))
        return wait(lambda n,r:r['features'][10]['wanted']==wanted and r['features'][10]['active']==wanted,'reserve toggle')
    def consume():
        serial=send(dict(channel='probe',action='standReserve',value=-200))
        return wait(lambda n,r:n.get('lastAction',{}).get('serial')==serial and n['lastAction'].get('accepted'),'native reserve consumption')[0]
    baseline,presentation=states()
    assert presentation['ready'] and presentation['features'][10]['available'],'balance candidate unavailable'
    assert baseline['maximumStandReserve']>=500 and baseline['standReserve']>=baseline['maximumStandReserve']-.02,'start with a full reserve on safe ground'
    original_wanted=presentation['features'][10]['wanted']
    try:
        toggle(False);low=consume()
        assert low['standReserve']<low['maximumStandReserve']-100,'native consumption not observed'
        toggle(True)
        filled,_=wait(lambda n,r:n['standReserve']>=n['maximumStandReserve']-.02 and r['features'][10]['active'],'native refill')
        consume()
        wait(lambda n,r:n['standReserve']>=n['maximumStandReserve']-.02 and r['features'][10]['active'],'frame maintenance')
        toggle(False);off=consume()
        assert off['standReserve']<off['maximumStandReserve']-100,'disabled refill still applied'
        toggle(True)
        wait(lambda n,r:n['standReserve']>=n['maximumStandReserve']-.02,'restore full reserve')
        print(json.dumps(dict(pid=initial['pid'],nativeBefore=low['standReserve'],nativeAfter=filled['standReserve'],disabled=off['standReserve'],maintenance=True)))
        print('PASS: real native reserve refill/readback, frame maintenance and disable. Water stability is NOT established by this test.')
    finally:
        toggle(original_wanted)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('root',type=Path);args=parser.parse_args();main(args.root.resolve())
