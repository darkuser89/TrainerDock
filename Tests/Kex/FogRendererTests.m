// SPDX-License-Identifier: GPL-3.0-only
// Own synthetic shader only. Proves GPU fog override and restoration, no game source.
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#import <AppKit/AppKit.h>
#import <OpenGL/gl.h>
#import <OpenGL/glext.h>
#import <dlfcn.h>
static void check(BOOL ok,const char *why){if(!ok){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
static GLuint shader(GLenum type,const char *text){GLuint s=glCreateShader(type);glShaderSource(s,1,&text,NULL);glCompileShader(s);GLint ok=0;glGetShaderiv(s,GL_COMPILE_STATUS,&ok);check(ok,"own GLSL fixture compiles");return s;}
static unsigned pixel(void){glClear(GL_COLOR_BUFFER_BIT);glBegin(GL_TRIANGLE_STRIP);glVertex2f(-1,-1);glVertex2f(1,-1);glVertex2f(-1,1);glVertex2f(1,1);glEnd();glFinish();unsigned char p[4]={0};glReadPixels(0,0,1,1,GL_RGBA,GL_UNSIGNED_BYTE,p);return p[0];}
int main(){@autoreleasepool{
 NSOpenGLPixelFormatAttribute attributes[]={NSOpenGLPFAAccelerated,NSOpenGLPFAColorSize,24,0};NSOpenGLPixelFormat *format=[[NSOpenGLPixelFormat alloc]initWithAttributes:attributes];NSOpenGLContext *context=[[NSOpenGLContext alloc]initWithFormat:format shareContext:nil];check(context!=nil,"real local GL fixture context");[context makeCurrentContext];
 GLuint texture=0,fbo=0;glGenTextures(1,&texture);glBindTexture(GL_TEXTURE_2D,texture);glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA8,2,2,0,GL_RGBA,GL_UNSIGNED_BYTE,NULL);glGenFramebuffersEXT(1,&fbo);glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,fbo);glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT,GL_COLOR_ATTACHMENT0_EXT,GL_TEXTURE_2D,texture,0);check(glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT)==GL_FRAMEBUFFER_COMPLETE_EXT,"own offscreen fixture framebuffer");glViewport(0,0,2,2);
 GLuint program=glCreateProgram(),vertex=shader(GL_VERTEX_SHADER,"#version 120\nvoid main(){gl_Position=gl_Vertex;}"),fragment=shader(GL_FRAGMENT_SHADER,"#version 120\nuniform float uFogNear; uniform float uFogFar;void main(){float d=50.0;float f=d<=uFogNear?1.0:clamp(1.0-(d-uFogNear)/(uFogFar-uFogNear),0.0,1.0);gl_FragColor=vec4(f,f,f,1.0);}");glAttachShader(program,vertex);glAttachShader(program,fragment);glLinkProgram(program);GLint linked=0;glGetProgramiv(program,GL_LINK_STATUS,&linked);check(linked,"own fixture program links");glUseProgram(program);
 GLint near=glGetUniformLocation(program,"uFogNear"),far=glGetUniformLocation(program,"uFogFar");check(near>=0 && far>=0,"exact scalar fog uniforms are reflected");glUniform1f(near,10);GLfloat originalFar=100;glUniform1fv(far,1,&originalFar);
 BOOL (*setFog)(BOOL)=dlsym(RTLD_DEFAULT,"KEXFogSet");check(setFog!=NULL,"actual candidate fog implementation loaded");unsigned before=pixel();check(before>100 && before<180,"original fixture fog visible");check(setFog(YES),"real GPU parameters confirm override");check(pixel()>250,"rendered pixels have no fog after enabling");
 glUniform1f(near,20);originalFar=120;glUniform1fv(far,1,&originalFar);check(pixel()>250,"original per-frame uploads cannot reintroduce fog");
 setFog(NO);GLfloat a=0,b=0;glGetUniformfv(program,near,&a);glGetUniformfv(program,far,&b);check(a==20 && b==120 && pixel()<200,"off restores the latest original uploads and actual fog pixels");
 glDeleteProgram(program);check(!setFog(YES),"deleted original shader programs are not reused");setFog(NO);glDeleteShader(vertex);glDeleteShader(fragment);glDeleteFramebuffersEXT(1,&fbo);glDeleteTextures(1,&texture);[NSOpenGLContext clearCurrentContext];
 puts("PASS: original candidate GL interposition, real GPU readback/pixels, float/vector uploads, current-value restoration and shader lifetime. Synthetic shader; no game launched.");return 0;
}}
