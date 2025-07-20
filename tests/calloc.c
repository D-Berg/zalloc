//! taken and adapted from https://en.cppreference.com/w/c/memory/calloc.html
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include "helper.h"
 
int test_calloc(void) {
    assert_zalloc();
    int* p1 = calloc(4, sizeof(int));    // allocate and zero out an array of 4 int
    assert(p1);
    int* p2 = calloc(1, sizeof(int[4])); // same, naming the array type directly
    assert(p2);
    int* p3 = calloc(4, sizeof *p3);     // same, without repeating the type name
    assert(p3);
 
    if (p2) {
        for (int n = 0; n < 4; ++n) { // print the array
            printf("p2[%d] = %d\n", n, p2[n]);
            assert(p2[n] == 0);
        }
    }
 
    free(p1);
    free(p2);
    free(p3);

    return EXIT_SUCCESS;
}
