// SPDX-License-Identifier: GPL-3.0-only
// The original games render through OpenGL. Override only reflected scalar fog
// uniforms, never shader sources, code pages, textures or game files.
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#import "KexFog.h"
#import <AppKit/AppKit.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>
#import <dlfcn.h>
#import <mach-o/loader.h>
#include <math.h>
static NSMutableDictionary<NSString *,NSMutableDictionary *> *programs;
static BOOL fogWanted;
static const GLfloat clearNear=1e20f,clearFar=1e19f;
static BOOL fromGame(void *caller){Dl_info info={};if(!caller || !dladdr(caller,&info))return NO;const struct mach_header_64 *h=info.dli_fbase;return h && h->filetype==MH_EXECUTE && h->cputype==CPU_TYPE_X86_64;}
static NSString *keyFor(GLuint program){return [NSString stringWithFormat:@"%p:%u",CGLGetCurrentContext(),program];}
static NSMutableDictionary *entryFor(GLint location){
 if(!programs.count || location<0 || !CGLGetCurrentContext())return nil;
 GLint current=0;glGetIntegerv(GL_CURRENT_PROGRAM,&current);NSMutableDictionary *entry=programs[keyFor((GLuint)current)];
 return entry && ([entry[@"near"] intValue]==location || [entry[@"far"] intValue]==location) ? entry : nil;
}
static GLfloat adjusted(NSMutableDictionary *entry,GLint location,GLfloat original){
 BOOL near=[entry[@"near"] intValue]==location;entry[near ? @"originalNear" : @"originalFar"]=@(original);
 if(!fogWanted || !isfinite(original))return original;entry[near ? @"heldNear" : @"heldFar"]=@YES;return near ? clearNear : clearFar;
}
static GLint fogLocation(GLuint program,const GLchar *name){
 GLint location=glGetUniformLocation(program,name);
 if(location>=0 && name && NSThread.isMainThread && fromGame(__builtin_return_address(0)) && (!strcmp(name,"uFogNear") || !strcmp(name,"uFogFar"))){
  @autoreleasepool{if(!programs)programs=[NSMutableDictionary new];NSString *key=keyFor(program);NSMutableDictionary *entry=programs[key];if(!entry){entry=[@{@"program":@(program),@"context":@((uintptr_t)CGLGetCurrentContext()),@"near":@(-1),@"far":@(-1)} mutableCopy];programs[key]=entry;}entry[!strcmp(name,"uFogNear") ? @"near" : @"far"]=@(location);}
 }
 return location;
}
static void fogUniform(GLint location,GLfloat value){
 if(fogWanted && NSThread.isMainThread && fromGame(__builtin_return_address(0))){NSMutableDictionary *entry=entryFor(location);if(entry)value=adjusted(entry,location,value);}
 glUniform1f(location,value);
}
static void fogUniformVector(GLint location,GLsizei count,const GLfloat *values){
 if(fogWanted && count==1 && values && NSThread.isMainThread && fromGame(__builtin_return_address(0))){NSMutableDictionary *entry=entryFor(location);if(entry){GLfloat value=adjusted(entry,location,*values);glUniform1fv(location,1,&value);return;}}
 glUniform1fv(location,count,values);
}
static void fogDelete(GLuint program){if(NSThread.isMainThread)[programs removeObjectForKey:keyFor(program)];glDeleteProgram(program);}
BOOL KEXFogSet(BOOL wanted){
 if(!NSThread.isMainThread || !CGLGetCurrentContext())return NO;fogWanted=wanted;
 GLint previous=0;glGetIntegerv(GL_CURRENT_PROGRAM,&previous);NSUInteger confirmed=0;
 for(NSMutableDictionary *entry in programs.allValues){
  if([entry[@"context"] unsignedLongLongValue]!=(uintptr_t)CGLGetCurrentContext())continue;
  GLuint program=[entry[@"program"] unsignedIntValue];GLint near=[entry[@"near"] intValue],far=[entry[@"far"] intValue];
  if(near<0 || far<0 || !glIsProgram(program))continue;
  glUseProgram(program);
  for(NSString *which in @[@"Near",@"Far"]){
   GLint location=[which isEqual:@"Near"] ? near : far;GLfloat intended=[which isEqual:@"Near"] ? clearNear : clearFar,actual[16]={0};
   glGetUniformfv(program,location,actual);
   if(wanted){
    // Disabled uploads pass straight through. Capture the actual current GPU
    // value on acquisition (or a new external upload), never a stale off-state
    // observation. Active intercepted uploads still keep the latest original.
    if(!isfinite(actual[0]))continue;
    if(![entry[[@"held" stringByAppendingString:which]] boolValue] || actual[0]!=intended)
     entry[[@"original" stringByAppendingString:which]]=@(actual[0]);
    if(actual[0]!=intended)glUniform1f(location,intended);entry[[@"held" stringByAppendingString:which]]=@YES;
   }
   else if([entry[[@"held" stringByAppendingString:which]] boolValue]){
    if(actual[0]==intended)glUniform1f(location,[entry[[@"original" stringByAppendingString:which]] floatValue]);entry[[@"held" stringByAppendingString:which]]=@NO;
   }
  }
  GLfloat a[16]={0},b[16]={0};glGetUniformfv(program,near,a);glGetUniformfv(program,far,b);if(wanted && a[0]==clearNear && b[0]==clearFar)confirmed++;
 }
 glUseProgram((GLuint)previous);return wanted && confirmed>0;
}
extern void *SDL_GL_GetProcAddress(const char *name);
static void *fogProc(const char *name){
 void *original=SDL_GL_GetProcAddress(name);if(!original || !name)return original;
 if(!strcmp(name,"glGetUniformLocation"))return (void *)fogLocation;
 if(!strcmp(name,"glUniform1f"))return (void *)fogUniform;
 if(!strcmp(name,"glUniform1fv"))return (void *)fogUniformVector;
 if(!strcmp(name,"glDeleteProgram"))return (void *)fogDelete;
 return original;
}
__attribute__((used,section("__DATA,__interpose"))) static const struct {const void *replacement,*original;} fogInterpositions[]={
 {(const void *)fogLocation,(const void *)glGetUniformLocation},
 {(const void *)fogUniform,(const void *)glUniform1f},
 {(const void *)fogUniformVector,(const void *)glUniform1fv},
 {(const void *)fogDelete,(const void *)glDeleteProgram},
 {(const void *)fogProc,(const void *)SDL_GL_GetProcAddress}
};
