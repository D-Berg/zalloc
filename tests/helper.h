#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>

#define STR(x) #x
#define XSTR(x) STR(x)

#define assert_zalloc() do { \
    assert(strcmp(XSTR(malloc), "zmalloc") == 0); \
    assert(strcmp(XSTR(realloc), "zrealloc") == 0); \
    assert(strcmp(XSTR(free), "zfree") == 0); \
    assert(strcmp(XSTR(calloc), "zcalloc") == 0); \
} while(0) 
