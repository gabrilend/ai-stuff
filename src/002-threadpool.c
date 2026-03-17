// src/002-threadpool.c
// Threadpool implementation for parallel task execution
// Uses pthreads with mutex-protected queue and condition variables

#include "003-threadpool.h"
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>  // For sysconf

// {{{ worker_thread
// Worker thread loop: dequeues and executes tasks until shutdown.
// Waits on condition variable when queue is empty.
static void* worker_thread(void* arg) {
    ThreadPool* pool = (ThreadPool*)arg;

    while (1) {
        pthread_mutex_lock(&pool->queue.lock);

        // Wait for task or shutdown
        while (pool->queue.count == 0 && !pool->shutdown) {
            pthread_cond_wait(&pool->queue.not_empty, &pool->queue.lock);
        }

        // Shutdown if no more tasks
        if (pool->shutdown && pool->queue.count == 0) {
            pthread_mutex_unlock(&pool->queue.lock);
            break;
        }

        // Dequeue task
        Task task = pool->queue.tasks[pool->queue.head];
        pool->queue.head = (pool->queue.head + 1) % pool->queue.capacity;
        pool->queue.count--;

        pthread_cond_signal(&pool->queue.not_full);
        pthread_mutex_unlock(&pool->queue.lock);

        // Execute task
        task.func(task.data);

        // Decrement pending counter
        pthread_mutex_lock(&pool->pending_lock);
        pool->pending_tasks--;
        if (pool->pending_tasks == 0) {
            pthread_cond_broadcast(&pool->all_done);
        }
        pthread_mutex_unlock(&pool->pending_lock);
    }

    return NULL;
}
// }}}

// {{{ threadpool_create
ThreadPool* threadpool_create(int thread_count, int queue_capacity) {
    if (thread_count <= 0 || queue_capacity <= 0) {
        return NULL;
    }

    ThreadPool* pool = (ThreadPool*)malloc(sizeof(ThreadPool));
    if (!pool) {
        return NULL;
    }

    pool->thread_count = thread_count;
    pool->shutdown = 0;
    pool->pending_tasks = 0;

    // Initialize queue
    pool->queue.capacity = queue_capacity;
    pool->queue.head = 0;
    pool->queue.tail = 0;
    pool->queue.count = 0;
    pool->queue.tasks = (Task*)malloc(sizeof(Task) * queue_capacity);

    if (!pool->queue.tasks) {
        free(pool);
        return NULL;
    }

    // Initialize mutexes and condition variables
    pthread_mutex_init(&pool->queue.lock, NULL);
    pthread_cond_init(&pool->queue.not_empty, NULL);
    pthread_cond_init(&pool->queue.not_full, NULL);
    pthread_mutex_init(&pool->pending_lock, NULL);
    pthread_cond_init(&pool->all_done, NULL);

    // Allocate thread array
    pool->threads = (pthread_t*)malloc(sizeof(pthread_t) * thread_count);
    if (!pool->threads) {
        free(pool->queue.tasks);
        free(pool);
        return NULL;
    }

    // Spawn worker threads
    for (int i = 0; i < thread_count; i++) {
        if (pthread_create(&pool->threads[i], NULL, worker_thread, pool) != 0) {
            // Cleanup on failure
            pool->shutdown = 1;
            pthread_cond_broadcast(&pool->queue.not_empty);
            for (int j = 0; j < i; j++) {
                pthread_join(pool->threads[j], NULL);
            }
            free(pool->threads);
            free(pool->queue.tasks);
            pthread_mutex_destroy(&pool->queue.lock);
            pthread_cond_destroy(&pool->queue.not_empty);
            pthread_cond_destroy(&pool->queue.not_full);
            pthread_mutex_destroy(&pool->pending_lock);
            pthread_cond_destroy(&pool->all_done);
            free(pool);
            return NULL;
        }
    }

    return pool;
}
// }}}

// {{{ threadpool_submit
int threadpool_submit(ThreadPool* pool, void (*func)(void*), void* data) {
    if (!pool || !func) {
        return -1;
    }

    pthread_mutex_lock(&pool->queue.lock);

    // Wait if queue is full
    while (pool->queue.count == pool->queue.capacity && !pool->shutdown) {
        pthread_cond_wait(&pool->queue.not_full, &pool->queue.lock);
    }

    if (pool->shutdown) {
        pthread_mutex_unlock(&pool->queue.lock);
        return -1;
    }

    // Enqueue task
    pool->queue.tasks[pool->queue.tail].func = func;
    pool->queue.tasks[pool->queue.tail].data = data;
    pool->queue.tail = (pool->queue.tail + 1) % pool->queue.capacity;
    pool->queue.count++;

    pthread_cond_signal(&pool->queue.not_empty);
    pthread_mutex_unlock(&pool->queue.lock);

    // Increment pending counter
    pthread_mutex_lock(&pool->pending_lock);
    pool->pending_tasks++;
    pthread_mutex_unlock(&pool->pending_lock);

    return 0;
}
// }}}

// {{{ threadpool_wait_all
void threadpool_wait_all(ThreadPool* pool) {
    if (!pool) {
        return;
    }

    pthread_mutex_lock(&pool->pending_lock);
    while (pool->pending_tasks > 0) {
        pthread_cond_wait(&pool->all_done, &pool->pending_lock);
    }
    pthread_mutex_unlock(&pool->pending_lock);
}
// }}}

// {{{ threadpool_destroy
void threadpool_destroy(ThreadPool* pool) {
    if (!pool) {
        return;
    }

    // Signal shutdown
    pthread_mutex_lock(&pool->queue.lock);
    pool->shutdown = 1;
    pthread_cond_broadcast(&pool->queue.not_empty);
    pthread_mutex_unlock(&pool->queue.lock);

    // Join all worker threads
    for (int i = 0; i < pool->thread_count; i++) {
        pthread_join(pool->threads[i], NULL);
    }

    // Free resources
    free(pool->threads);
    free(pool->queue.tasks);
    pthread_mutex_destroy(&pool->queue.lock);
    pthread_cond_destroy(&pool->queue.not_empty);
    pthread_cond_destroy(&pool->queue.not_full);
    pthread_mutex_destroy(&pool->pending_lock);
    pthread_cond_destroy(&pool->all_done);
    free(pool);
}
// }}}

// {{{ get_optimal_thread_count
int get_optimal_thread_count(void) {
    // Detect number of online processors using POSIX sysconf
    long cores = sysconf(_SC_NPROCESSORS_ONLN);

    // Fallback to 4 if detection fails
    if (cores < 1) {
        fprintf(stderr, "WARNING: Could not detect CPU count, defaulting to 4\n");
        cores = 4;
    }

    // Calculate optimal thread count: cores - 1 (leave one for main thread)
    int thread_count = (int)cores - 1;

    // Clamp to reasonable range [2, 16]
    // Minimum 2: need at least 2 threads for parallelism benefit
    // Maximum 16: diminishing returns and memory overhead beyond this
    if (thread_count < 2) {
        thread_count = 2;
    } else if (thread_count > 16) {
        thread_count = 16;
    }

    return thread_count;
}
// }}}
