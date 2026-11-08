#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Explicit real BB-stress check in the authorized candidate, no game launches.

Requires BB and Sam safely on land. Uses only the game's original request API,
stays below 75% stress and restores the starting stress and switch choice.
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
        deadline=time.monotonic()+8
        while time.monotonic()<deadline:
            n,r=states()
            if predicate(n,r):return n,r
            time.sleep(.04)
        raise RuntimeError(label)
    def toggle(wanted):
        send(dict(action='set',feature=4,wanted=wanted))
        return wait(lambda n,r:r['features'][4]['wanted']==wanted and (not wanted or r['features'][4]['active']),'BB stress switch')
    def set_rate(rate):
        serial=send(dict(channel='probe',action='bbStress',value=rate))
        wait(lambda n,r:n.get('lastAction',{}).get('serial')==serial and n['lastAction'].get('accepted'),'native BB request')
    def at_rate(n,rate):
        expected=n['maximumBBStress']*rate
        return abs(n['bbStress']-expected)<.1 and abs(n['displayBBStress']-expected)<.1
    baseline,presentation=states();original_wanted=presentation['features'][4]['wanted']
    assert presentation['ready'] and presentation['features'][4]['available'],'BB candidate unavailable'
    assert 0<=baseline['bbStress']<=.75*baseline['maximumBBStress'],'begin below 75% BB stress'
    original_rate=baseline['bbStress']/baseline['maximumBBStress']
    try:
        toggle(False);set_rate(.5)
        before,_=wait(lambda n,r:at_rate(n,.5),'original BB stress setter and gauge')
        toggle(True)
        after,_=wait(lambda n,r:at_rate(n,0) and r['features'][4]['active'],'BB stress cleared')
        set_rate(.35)
        wait(lambda n,r:at_rate(n,0) and r['features'][4]['active'],'continued BB stress suppression')
        toggle(False);set_rate(.3)
        disabled,_=wait(lambda n,r:at_rate(n,.3) and not r['features'][4]['active'],'BB stress suppression disabled')
        print(json.dumps(dict(pid=initial['pid'],before=before['bbStress'],after=after['bbStress'],disabled=disabled['bbStress'],gauge=after['displayBBStress'])))
        print('PASS: original BB request, real stress/gauge readback, maintenance and disable.')
    finally:
        toggle(False);set_rate(original_rate)
        wait(lambda n,r:at_rate(n,original_rate),'starting BB stress restored')
        toggle(original_wanted)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('root',type=Path);args=parser.parse_args();main(args.root.resolve())
