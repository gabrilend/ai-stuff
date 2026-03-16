# src/002-threadpool.c

## Purpose
Threadpool implementation for parallel task execution using pthreads.
Provides worker thread management, thread-safe task queue, and
synchronization primitives.

## External Functions

### threadpool_create
```c
ThreadPool* threadpool_create(int thread_count, int queue_capacity)
```
**Description:** Creates and initializes a new threadpool

**Parameters:**
- `thread_count`: Number of worker threads to spawn
- `queue_capacity`: Maximum number of tasks in queue

**Returns:** ThreadPool pointer on success, NULL on failure

**Behavior:**
- Allocates threadpool structure
- Initializes circular buffer task queue
- Creates mutexes and condition variables
- Spawns worker threads
- Returns NULL if any step fails

---

### threadpool_submit
```c
int threadpool_submit(ThreadPool* pool, void (*func)(void*), void* data)
```
**Description:** Submits a task to the threadpool for execution

**Parameters:**
- `pool`: ThreadPool instance
- `func`: Function pointer to execute
- `data`: Data pointer to pass to function

**Returns:** 0 on success, -1 on failure

**Behavior:**
- Blocks if queue is full until space available
- Enqueues task into circular buffer
- Signals worker threads via condition variable
- Increments pending task counter

---

### threadpool_wait_all
```c
void threadpool_wait_all(ThreadPool* pool)
```
**Description:** Blocks until all submitted tasks complete

**Parameters:**
- `pool`: ThreadPool instance

**Returns:** void

**Behavior:**
- Waits on condition variable while pending_tasks > 0
- Returns immediately if no pending tasks

---

### threadpool_destroy
```c
void threadpool_destroy(ThreadPool* pool)
```
**Description:** Shuts down threadpool and frees resources

**Parameters:**
- `pool`: ThreadPool instance

**Returns:** void

**Behavior:**
- Sets shutdown flag
- Broadcasts to wake all worker threads
- Joins all worker threads
- Frees allocated resources
- Safe to call with pending tasks (they will complete first)
