// SPDX-License-Identifier: GPL-3.0-only
// Calls the real private frame function with no selected/owned effects and an
// entirely unbound API. Any native lookup would fail this test immediately.
#if defined(MHT_IDLE_TLD)
#include "../../Modules/the-long-dark/Sources/LongDarkBackend.mm"
BOOL TLDInFrame(){return YES;}
BOOL TLDEnqueue(dispatch_block_t){return NO;}
BOOL TLDEnsureLoop(){return NO;}
void TLDSetFrameHandler(dispatch_block_t){}
NSDictionary *TLDLoopDiagnostics(){return @{};}
#elif defined(MHT_IDLE_VC)
#include "../../Modules/vampire-crawlers/Sources/VampireBackend.mm"
BOOL VCInFrame(){return YES;}
BOOL VCEnqueue(dispatch_block_t){return NO;}
BOOL VCEnsureLoop(){return NO;}
void VCSetFrameHandler(dispatch_block_t){}
NSDictionary *VCLoopDiagnostics(){return @{};}
#elif defined(MHT_IDLE_TR)
#include "../../Modules/terraria/Sources/TerrariaBackend.mm"
#else
#error Select the actual backend under test
#endif
int main(){@autoreleasepool{
 for(unsigned i=0;i<20000;i++){
#if defined(MHT_IDLE_TLD)
  frame();if(TLDMouse(NO))return 1;
#elif defined(MHT_IDLE_VC)
  tick();if(VCMouse(NO))return 1;
#else
  tick();inFrame=true;if(TRMouse(NO))return 1;inFrame=false;
#endif
 }
 puts("PASS: 20,000 idle callbacks and closed-mouse polls with unbound native APIs; no gameplay lookup, effect or game startup.");
}}
