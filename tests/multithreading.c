#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include "helper.h"


void *worker(void *arg) {
    int thread_id = *(int *)arg;
    free(arg); // We dynamically allocate this below, so we free it here.

    // Allocate memory
    int *data = malloc(5 * sizeof(int));
    if (!data) {
        fprintf(stderr, "Thread %d: malloc failed\n", thread_id);
        pthread_exit(NULL);
    }

    // Fill and print
    for (int i = 0; i < 5; ++i) {
        data[i] = thread_id * 10 + i;
        printf("Thread %d: data[%d] = %d\n", thread_id, i, data[i]);
    }

    // Free memory
    free(data);
    pthread_exit(NULL);
}

int test_threading(int n_threads) {
    assert_zalloc();

    pthread_t threads[n_threads];

    for (int i = 0; i < n_threads; ++i) {
        int *arg = malloc(sizeof(int)); // avoid race condition
        assert(arg);

        *arg = i;
        if (pthread_create(&threads[i], NULL, worker, arg) != 0) {
            perror("pthread_create");
            free(arg);
            return 1;
        }
    }

    for (int i = 0; i < n_threads; ++i) {
        pthread_join(threads[i], NULL);
    }

    printf("All threads completed.\n");
    return 0;
}
