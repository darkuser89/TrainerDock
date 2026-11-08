// SPDX-License-Identifier: GPL-3.0-only
// Actual fog interposition with counted, fixture-only GL calls. No game or GPU.
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#import <AppKit/AppKit.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>
#import <dlfcn.h>
#import <mach-o/loader.h>
static NSUInteger threadQueries,callerQueries,contextQueries,programQueries,uploads;
static GLfloat nearValue=10,farValue=100;
static GLint currentProgram=7;
static BOOL live=YES;
@interface FogFixtureThread : NSObject
+ (BOOL)isMainThread;
@end
@implementation FogFixtureThread
+ (BOOL)isMainThread{threadQueries++;return YES;}
@end
static CGLContextObj fixtureContext(void){contextQueries++;return (CGLContextObj)(uintptr_t)1;}
static int fixtureCaller(const void *p,Dl_info *info){(void)p;callerQueries++;static struct mach_header_64 h={.magic=MH_MAGIC_64,.cputype=CPU_TYPE_X86_64,.filetype=MH_EXECUTE};memset(info,0,sizeof(*info));info->dli_fbase=&h;return 1;}
static GLint fixtureLocation(GLuint p,const GLchar *name){return p==7&&!strcmp(name,"uFogNear")?3:p==7&&!strcmp(name,"uFogFar")?4:-1;}
static void fixtureCurrent(GLenum key,GLint *p){(void)key;programQueries++;*p=currentProgram;}
static void fixtureUniform(GLint location,GLfloat n){uploads++;if(currentProgram==7){if(location==3)nearValue=n;if(location==4)farValue=n;}}
static void fixtureUniformVector(GLint location,GLsizei count,const GLfloat *n){if(count==1&&n)fixtureUniform(location,*n);}
static void fixtureGet(GLuint p,GLint location,GLfloat *n){*n=p==7&&location==3?nearValue:p==7&&location==4?farValue:0;}
static GLboolean fixtureIsProgram(GLuint p){return p==7&&live;}
static void fixtureUse(GLuint p){currentProgram=(GLint)p;}
static void fixtureDelete(GLuint p){if(p==7)live=NO;}
static void *fixtureSDL(const char *name);
#define NSThread FogFixtureThread
#define dladdr fixtureCaller
#define CGLGetCurrentContext fixtureContext
#define glGetUniformLocation fixtureLocation
#define glGetIntegerv fixtureCurrent
#define glUniform1f fixtureUniform
#define glUniform1fv fixtureUniformVector
#define glGetUniformfv fixtureGet
#define glIsProgram fixtureIsProgram
#define glUseProgram fixtureUse
#define glDeleteProgram fixtureDelete
#define SDL_GL_GetProcAddress fixtureSDL
#import "../../Modules/_Shared/Kex/KexFog.m"
#undef SDL_GL_GetProcAddress
static void *fixtureSDL(const char *name){(void)name;return NULL;}
static void check(BOOL okay,const char *why){if(!okay){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
int main(void){@autoreleasepool{
 check(fogLocation(7,"uFogNear")==3&&fogLocation(7,"uFogFar")==4,"the product reflects the two exact fog locations");
 threadQueries=callerQueries=contextQueries=programQueries=uploads=0;
 for(unsigned i=0;i<100000;i++){fogUniform(3,10);GLfloat n=100;fogUniformVector(4,1,&n);}
 check(uploads==200000&&!threadQueries&&!callerQueries&&!contextQueries&&!programQueries,"200,000 disabled uploads pass straight through without thread, caller, context or current-program discovery");
 check(KEXFogSet(YES)&&nearValue==clearNear&&farValue==clearFar,"enabling captures current GPU values and confirms the real override");
 fogUniform(3,20);GLfloat n=120;fogUniformVector(4,1,&n);
 check(nearValue==clearNear&&farValue==clearFar,"active uploads remain intercepted");
 KEXFogSet(NO);check(nearValue==20&&farValue==120,"off restores the latest original active uploads");
 fogUniform(3,30);n=140;fogUniformVector(4,1,&n);
 check(KEXFogSet(YES),"re-enable after inactive uploads");KEXFogSet(NO);
 check(nearValue==30&&farValue==140,"re-enable never restores stale pre-disable uniforms");
 fogDelete(7);check(!KEXFogSet(YES),"deleted programs are not reused");KEXFogSet(NO);
 puts("PASS: actual KEX fog code: 200,000 disabled GL uploads perform zero metadata/context queries; active readback, latest-value restoration, reacquisition and shader deletion preserved. Synthetic GL only.");
}return 0;}
