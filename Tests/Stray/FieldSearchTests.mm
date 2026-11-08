// SPDX-License-Identifier: GPL-3.0-only
// Synthetic UField boundary fixture; never linked into product sources.
#import "StrayFieldSearch.hpp"
#include <map>
namespace {
using st::Object;
struct Node{NSString *name=nil;uintptr_t owner=0,next=0,child=0,parent=0;bool field=false,function=false;};
struct Reader{
 std::map<uintptr_t,Node> nodes;
 void validate(Object o){if(!nodes.count(o.address))throw std::runtime_error("Unknown fixture metadata owner");}
 Object children(Object o){return {nodes.at(o.address).child};}
 Object super(Object o){return {nodes.at(o.address).parent};}
 Object next(Object o){return {nodes.at(o.address).next};}
 Object outer(Object o){return {nodes.at(o.address).owner};}
 bool isField(Object o){return nodes.at(o.address).field;}
 bool isFunction(Object o){return nodes.at(o.address).function;}
 NSString *name(Object o){return nodes.at(o.address).name;}
};
void check(bool value,const char *why){if(!value){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
template<class Work> bool rejects(Work work){try{work();return false;}catch(const std::exception &){return true;}}
}
int main(){@autoreleasepool{
 Reader r;
 r.nodes[1]={@"LifeComponent",0,0,10,2};r.nodes[2]={@"ActorComponent",0,0,20,0};
 r.nodes[10]={@"GetCurrentLife",1,11,0,0,true,true};
 // Mirrors the observed original ULifeComponent chain: a DelegateFunction
 // appears before the requested inherited ActorComponent.GetOwner function.
 r.nodes[11]={@"LifeComponentRevivedDelegate__DelegateSignature",1,12,0,0,true,true};
 r.nodes[12]={@"GetOwner",1,0,0,0,true,false}; // valid UField, not a function
 r.nodes[20]={@"GetOwner",2,0,0,0,true,true};
 check(st::detail::findFunction(Object{1},@"GetOwner",r)==Object{20},"delegate and non-function fields cannot obstruct the inherited original function");
 check(st::detail::findFunction(Object{1},@"LifeComponentRevivedDelegate__DelegateSignature",r)==Object{11},"UFunction subclasses are recognized by original class inheritance");
 check(rejects([&]{st::detail::findFunction(Object{1},@"Missing",r);}),"absent functions never receive a replacement");
 r.nodes[11].field=false;
 check(rejects([&]{st::detail::findFunction(Object{1},@"GetOwner",r);}),"unknown non-UField objects remain rejected");r.nodes[11].field=true;
 r.nodes[11].owner=2;
 check(rejects([&]{st::detail::findFunction(Object{1},@"GetOwner",r);}),"a foreign field owner remains rejected");r.nodes[11].owner=1;
 r.nodes[12].next=10;
 check(rejects([&]{st::detail::findFunction(Object{1},@"GetOwner",r);}),"cyclic field links remain rejected");r.nodes[12].next=0;
 r.nodes[2].parent=1;
 check(rejects([&]{st::detail::findFunction(Object{1},@"Missing",r);}),"cyclic superclass links remain rejected");
 puts("PASS: delegate-before-GetOwner traversal, valid non-function fields, owner checks and cycle rejection. Synthetic metadata only; no game started.");
}}
