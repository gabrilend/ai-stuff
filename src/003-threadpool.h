// src/003-threadpool.h
// Threadpool API for parallel task execution
// Provides thread-safe task queue and worker thread management

#ifndef THREADPOOL_H
#define THREADPOOL_H

#include <pthread.h>

// {{{ typedef struct Task
// Task represents a unit of work to be executed by a worker thread.
// The function pointer receives the data pointer as its argument.
typedef struct Task {
    void (*func)(void* data);  // Function to execute
    void* data;                 // Task-specific data pointer
} Task;
// }}}

// {{{ typedef struct TaskQueue
// TaskQueue is a circular buffer with mutex protection and condition variables.
// It blocks when full (submit) or empty (dequeue).
typedef struct TaskQueue {
    Task* tasks;                 // Fixed-size task array
    int capacity;                // Maximum tasks
    int head;                    // Next task to dequeue
    int tail;                    // Next empty slot
    int count;                   // Current task count
    pthread_mutex_t lock;        // Queue access mutex
    pthread_cond_t not_empty;    // Signal when tasks available
    pthread_cond_t not_full;     // Signal when space available
} TaskQueue;
// }}}

// {{{ typedef struct ThreadPool
// ThreadPool manages a fixed number of worker threads and a shared task queue.
// Workers pull tasks from the queue and execute them in parallel.
typedef struct ThreadPool {
    pthread_t* threads;          // Worker thread handles
    int thread_count;            // Number of workers
    TaskQueue queue;             // Shared task queue
    int shutdown;                // Shutdown flag
    int pending_tasks;           // Atomic counter for wait_all
    pthread_mutex_t pending_lock;  // Protects pending_tasks counter
    pthread_cond_t all_done;     // Signal when pending_tasks == 0
} ThreadPool;
// }}}

// {{{ threadpool_create
// Creates a new threadpool with the specified number of worker threads
// and task queue capacity. Returns NULL on failure.
//
// Parameters:
//   thread_count: Number of worker threads to create
//   queue_capacity: Maximum number of tasks in queue
//
// Returns:
//   ThreadPool pointer on success, NULL on failure
ThreadPool* threadpool_create(int thread_count, int queue_capacity);
// }}}

// {{{ threadpool_submit
// Submits a task to the threadpool for execution. Blocks if queue is full.
// The task will be executed asynchronously by a worker thread.
//
// Parameters:
//   pool: ThreadPool instance
//   func: Function pointer to execute
//   data: Data pointer to pass to function
//
// Returns:
//   0 on success, -1 on failure
int threadpool_submit(ThreadPool* pool, void (*func)(void*), void* data);
// }}}

// {{{ threadpool_wait_all
// Blocks until all submitted tasks have completed execution.
// This does not prevent new tasks from being submitted concurrently.
//
// Parameters:
//   pool: ThreadPool instance
void threadpool_wait_all(ThreadPool* pool);
// }}}

// {{{ threadpool_destroy
// Shuts down the threadpool, waits for all workers to exit, and frees resources.
// Any pending tasks in the queue will be completed before shutdown.
//
// Parameters:
//   pool: ThreadPool instance
void threadpool_destroy(ThreadPool* pool);
// }}}

#endif // THREADPOOL_H
