//! Taken and adapted from https://en.cppreference.com/w/c/memory/malloc.html
#include <assert.h>
#include <stdio.h>   
#include <stdlib.h> 
#include "helper.h"


int test_malloc(void) {
    assert_zalloc();
    int *p1 = malloc(4*sizeof(int));  // allocates enough for an array of 4 int
    assert(p1);
    int *p2 = malloc(sizeof(int[4])); // same, naming the type directly
    assert(p2);
    int *p3 = malloc(4*sizeof *p3);   // same, without repeating the type name
    assert(p3);
 
    if(p1) {
        for(int n=0; n<4; ++n) // populate the array
            p1[n] = n*n;
        for(int n=0; n<4; ++n) // print it back out
            printf("p1[%d] == %d\n", n, p1[n]);
    }
 
    free(p1);
    free(p2);
    free(p3);

    return EXIT_SUCCESS;
}
