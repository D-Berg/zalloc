
// Taken from https://en.cppreference.com/w/c/memory/free.html
#include <stdio.h>
#include <stdlib.h>
#include "helper.h"
 
int test_free(void) {
    assert_zalloc();
    int *p1 = malloc(10*sizeof *p1);
    free(p1); // every allocated pointer must be freed
 
    int *p2 = calloc(10, sizeof(*p2));
    int *p3 = realloc(p2, 1000*sizeof(*p3));
    if(p3) { // p3 not null means p2 was freed by realloc
       free(p3);
    } else { // p3 null means p2 was not freed
       free(p2);
    }
    return EXIT_SUCCESS;
}
