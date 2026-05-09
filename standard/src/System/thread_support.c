#include <pthread.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef void* (*au_thread_fn_t)(void*);

typedef struct {
    au_thread_fn_t fn;
    void*          data;
} au_job_t;

static void au_abort_message(const char* message) {
    fputs(message, stderr);
    fputc('\n', stderr);
    abort();
}

static void au_abort_pthread(const char* what, int err) {
    fprintf(stderr, "%s failed: %s\n", what, strerror(err));
    abort();
}

static void* au_trampoline(void* arg) {
    au_job_t* job = (au_job_t*)arg;
    void* result = job->fn(job->data);
    free(job);
    return result;
}

/* au_spawn_thread: allocates pthread_t on heap, returns it as uint8_t*.
   Austral sees this as Address[Nat8]. */
uint8_t* au_spawn_thread(void* fn, uint8_t* data) {
    if (fn == NULL) {
        au_abort_message("au_spawn_thread: null function pointer");
    }

    pthread_t* t   = (pthread_t*)malloc(sizeof(pthread_t));
    au_job_t*  job = (au_job_t*)malloc(sizeof(au_job_t));
    if (t == NULL || job == NULL) {
        free(t);
        free(job);
        au_abort_message("au_spawn_thread: out of memory");
    }

    job->fn   = (au_thread_fn_t)fn;
    job->data = (void*)data;

    int rc = pthread_create(t, NULL, au_trampoline, job);
    if (rc != 0) {
        free(job);
        free(t);
        au_abort_pthread("pthread_create", rc);
    }

    return (uint8_t*)t;
}

/* au_join_thread: joins and frees the heap-allocated pthread_t. */
uint8_t* au_join_thread(uint8_t* handle) {
    if (handle == NULL) {
        au_abort_message("au_join_thread: null thread handle");
    }

    pthread_t* t = (pthread_t*)handle;
    void* result = NULL;
    int rc = pthread_join(*t, &result);
    if (rc != 0) {
        free(t);
        au_abort_pthread("pthread_join", rc);
    }

    free(t);
    return (uint8_t*)result;
}

typedef struct {
    pthread_mutex_t mutex;
    pthread_cond_t  not_empty;
    uint8_t**       items;
    size_t          capacity;
    size_t          head;
    size_t          count;
    int             closed;
} au_queue_t;

static au_queue_t* au_as_queue(uint8_t* raw, const char* name) {
    if (raw == NULL) {
        au_abort_message(name);
    }
    return (au_queue_t*)raw;
}

static void au_queue_grow(au_queue_t* q) {
    size_t new_capacity = q->capacity * 2;
    uint8_t** new_items = (uint8_t**)malloc(new_capacity * sizeof(uint8_t*));
    if (new_items == NULL) {
        au_abort_message("au_queue_grow: out of memory");
    }

    for (size_t i = 0; i < q->count; i++) {
        new_items[i] = q->items[(q->head + i) % q->capacity];
    }

    free(q->items);
    q->items = new_items;
    q->capacity = new_capacity;
    q->head = 0;
}

uint8_t* au_queue_create(size_t capacity) {
    if (capacity == 0) {
        capacity = 1;
    }

    au_queue_t* q = (au_queue_t*)malloc(sizeof(au_queue_t));
    if (q == NULL) {
        au_abort_message("au_queue_create: out of memory");
    }

    q->items = (uint8_t**)calloc(capacity, sizeof(uint8_t*));
    if (q->items == NULL) {
        free(q);
        au_abort_message("au_queue_create: out of memory");
    }

    int rc = pthread_mutex_init(&q->mutex, NULL);
    if (rc != 0) {
        free(q->items);
        free(q);
        au_abort_pthread("pthread_mutex_init", rc);
    }

    rc = pthread_cond_init(&q->not_empty, NULL);
    if (rc != 0) {
        pthread_mutex_destroy(&q->mutex);
        free(q->items);
        free(q);
        au_abort_pthread("pthread_cond_init", rc);
    }

    q->capacity = capacity;
    q->head = 0;
    q->count = 0;
    q->closed = 0;
    return (uint8_t*)q;
}

int32_t au_queue_push(uint8_t* raw_queue, uint8_t* item) {
    au_queue_t* q = au_as_queue(raw_queue, "au_queue_push: null queue");
    if (item == NULL) {
        au_abort_message("au_queue_push: null item");
    }

    int rc = pthread_mutex_lock(&q->mutex);
    if (rc != 0) {
        au_abort_pthread("pthread_mutex_lock", rc);
    }

    if (q->closed) {
        au_abort_message("au_queue_push: queue is closed");
    }

    if (q->count == q->capacity) {
        au_queue_grow(q);
    }

    size_t tail = (q->head + q->count) % q->capacity;
    q->items[tail] = item;
    q->count++;

    rc = pthread_cond_signal(&q->not_empty);
    if (rc != 0) {
        au_abort_pthread("pthread_cond_signal", rc);
    }

    rc = pthread_mutex_unlock(&q->mutex);
    if (rc != 0) {
        au_abort_pthread("pthread_mutex_unlock", rc);
    }

    return 0;
}

uint8_t* au_queue_pop(uint8_t* raw_queue) {
    au_queue_t* q = au_as_queue(raw_queue, "au_queue_pop: null queue");

    int rc = pthread_mutex_lock(&q->mutex);
    if (rc != 0) {
        au_abort_pthread("pthread_mutex_lock", rc);
    }

    while (q->count == 0 && !q->closed) {
        rc = pthread_cond_wait(&q->not_empty, &q->mutex);
        if (rc != 0) {
            au_abort_pthread("pthread_cond_wait", rc);
        }
    }

    if (q->count == 0 && q->closed) {
        rc = pthread_mutex_unlock(&q->mutex);
        if (rc != 0) {
            au_abort_pthread("pthread_mutex_unlock", rc);
        }
        return NULL;
    }

    uint8_t* item = q->items[q->head];
    q->items[q->head] = NULL;
    q->head = (q->head + 1) % q->capacity;
    q->count--;

    rc = pthread_mutex_unlock(&q->mutex);
    if (rc != 0) {
        au_abort_pthread("pthread_mutex_unlock", rc);
    }

    return item;
}

int32_t au_queue_close(uint8_t* raw_queue) {
    au_queue_t* q = au_as_queue(raw_queue, "au_queue_close: null queue");

    int rc = pthread_mutex_lock(&q->mutex);
    if (rc != 0) {
        au_abort_pthread("pthread_mutex_lock", rc);
    }

    q->closed = 1;

    rc = pthread_cond_broadcast(&q->not_empty);
    if (rc != 0) {
        au_abort_pthread("pthread_cond_broadcast", rc);
    }

    rc = pthread_mutex_unlock(&q->mutex);
    if (rc != 0) {
        au_abort_pthread("pthread_mutex_unlock", rc);
    }

    return 0;
}

size_t au_queue_count(uint8_t* raw_queue) {
    au_queue_t* q = au_as_queue(raw_queue, "au_queue_count: null queue");

    int rc = pthread_mutex_lock(&q->mutex);
    if (rc != 0) {
        au_abort_pthread("pthread_mutex_lock", rc);
    }

    size_t count = q->count;

    rc = pthread_mutex_unlock(&q->mutex);
    if (rc != 0) {
        au_abort_pthread("pthread_mutex_unlock", rc);
    }

    return count;
}

int32_t au_queue_destroy(uint8_t* raw_queue) {
    au_queue_t* q = au_as_queue(raw_queue, "au_queue_destroy: null queue");

    int rc = pthread_mutex_lock(&q->mutex);
    if (rc != 0) {
        au_abort_pthread("pthread_mutex_lock", rc);
    }

    if (q->count != 0) {
        au_abort_message("au_queue_destroy: queue is not empty");
    }

    rc = pthread_mutex_unlock(&q->mutex);
    if (rc != 0) {
        au_abort_pthread("pthread_mutex_unlock", rc);
    }

    rc = pthread_cond_destroy(&q->not_empty);
    if (rc != 0) {
        au_abort_pthread("pthread_cond_destroy", rc);
    }

    rc = pthread_mutex_destroy(&q->mutex);
    if (rc != 0) {
        au_abort_pthread("pthread_mutex_destroy", rc);
    }

    free(q->items);
    free(q);
    return 0;
}
