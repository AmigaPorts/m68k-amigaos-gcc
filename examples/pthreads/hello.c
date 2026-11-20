#include <pthread.h>
#include <stdio.h>

constexpr int thread_count = 4;

static pthread_mutex_t print_lock = PTHREAD_MUTEX_INITIALIZER;

// Hello, World from four threads: each one says hello under a mutex,
// and the main thread waits for all of them.
static void *hello(void *arg)
{
    const int n = (int)(long)arg;

    pthread_mutex_lock(&print_lock);
    printf("Hello, World from thread %d\n", n);
    pthread_mutex_unlock(&print_lock);

    return nullptr;
}

int main(void)
{
    pthread_t threads[thread_count];

    for (int n = 0; n < thread_count; n++) {
        pthread_create(&threads[n], nullptr, hello, (void *)(long)(n + 1));
    }

    for (int n = 0; n < thread_count; n++) {
        pthread_join(threads[n], nullptr);
    }

    printf("All %d threads are done\n", thread_count);
    return 0;
}
