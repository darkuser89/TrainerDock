// SPDX-License-Identifier: GPL-3.0-only
// Test executables have no game's VM. Any accidental VM access must fail loudly.
// This file is never linked into a trainer library.
#include <stdint.h>
#include <stdlib.h>
int lua_pcallk(void *state,int arguments,int results,int error,intptr_t context,void *continuation){(void)state;(void)arguments;(void)results;(void)error;(void)context;(void)continuation;abort();}
void lua_close(void *state){(void)state;abort();}
