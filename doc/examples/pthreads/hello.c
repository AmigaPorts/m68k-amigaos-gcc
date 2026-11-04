#include <pthread.h>
#include <stdio.h>

static pthread_mutex_t print_lock = PTHREAD_MUTEX_INITIALIZER;

// Hello, World from four threads: each one says hello under a mutex,
// and the main thread waits for all of them.
static void *hello(void *arg)
{
	int n = (int) (long) arg;

	pthread_mutex_lock(&print_lock);
	printf("Hello, World from thread %d\n", n);
	pthread_mutex_unlock(&print_lock);
	return NULL;
}

int main(void)
{
	pthread_t threads[4];
	int n;

	for (n = 0; n < 4; n++)
		pthread_create(&threads[n], NULL, hello, (void *) (long) (n + 1));
	for (n = 0; n < 4; n++)
		pthread_join(threads[n], NULL);
	printf("All %d threads are done\n", n);
	return 0;
}
