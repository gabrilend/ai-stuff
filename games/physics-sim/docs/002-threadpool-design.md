# 002 - Threadpool Design

## Overview

The threadpool processes ball physics updates in parallel. Each tick,
the main thread submits one task per active ball, then waits for
completion before rendering.

## Core Structures

### Task
```c
// {{{ typedef struct Task
typedef struct Task {
    void (*func)(void* data);  // Function to execute
    void* data;                 // Task-specific data pointer
    int completed;              // Completion flag
} Task;
// }}}
```

### TaskQueue
```c
// {{{ typedef struct TaskQueue
typedef struct TaskQueue {
    Task* tasks;           // Fixed-size task array
    int capacity;          // Maximum tasks
    int head;              // Next task to dequeue
    int tail;              // Next empty slot
    int count;             // Current task count
    pthread_mutex_t lock;  // Queue access mutex
    pthread_cond_t not_empty;  // Signal when tasks available
    pthread_cond_t not_full;   // Signal when space available
} TaskQueue;
// }}}
```

### ThreadPool
```c
// {{{ typedef struct ThreadPool
typedef struct ThreadPool {
    pthread_t* threads;    // Worker thread handles
    int thread_count;      // Number of workers
    TaskQueue queue;       // Shared task queue
    int shutdown;          // Shutdown flag
} ThreadPool;
// }}}
```

## API Functions

### Initialization
```c
// {{{ threadpool_create
ThreadPool* threadpool_create(int thread_count, int queue_capacity);
// }}}

// {{{ threadpool_destroy
void threadpool_destroy(ThreadPool* pool);
// }}}
```

### Task Submission
```c
// {{{ threadpool_submit
// Submit a task to the pool. Blocks if queue is full.
int threadpool_submit(ThreadPool* pool, void (*func)(void*), void* data);
// }}}
```

### Synchronization
```c
// {{{ threadpool_wait_all
// Block until all submitted tasks complete.
void threadpool_wait_all(ThreadPool* pool);
// }}}
```

## Worker Thread Loop

```c
// {{{ worker_thread
void* worker_thread(void* arg) {
    ThreadPool* pool = (ThreadPool*)arg;

    while (1) {
        pthread_mutex_lock(&pool->queue.lock);

        // Wait for task or shutdown
        while (pool->queue.count == 0 && !pool->shutdown) {
            pthread_cond_wait(&pool->queue.not_empty, &pool->queue.lock);
        }

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
    }

    return NULL;
}
// }}}
```

## Task Data Memory

Each ball physics task receives a pointer to a TaskData struct:

```c
// {{{ typedef struct BallTaskData
typedef struct BallTaskData {
    int ball_index;        // Index into ball array
    Ball* read_buffer;     // Current state (read-only)
    Ball* write_buffer;    // Next state (write target)
    World* world;          // World reference for collisions
} BallTaskData;
// }}}
```

This data region is pre-allocated at startup, one per maximum ball count,
avoiding malloc during gameplay.

## Synchronization Pattern

```
Frame N:
  1. Main: Submit tasks for all active balls
  2. Main: Call threadpool_wait_all()
  3. Workers: Process tasks in parallel
  4. Workers: All complete, signal main
  5. Main: Swap ball buffers
  6. Main: Render from current buffer
```
