#include <cstdio>
#include <mutex>
#include <thread>
#include <vector>

static std::mutex print_lock;

// Hello, World from four threads: each one says hello under a mutex,
// and the main thread waits for all of them.
static void hello(int n)
{
	std::lock_guard<std::mutex> guard(print_lock);
	std::printf("Hello, World from thread %d\n", n);
}

int main()
{
	std::vector<std::thread> threads;

	for (int n = 1; n <= 4; n++)
		threads.emplace_back(hello, n);
	for (std::thread &t : threads)
		t.join();
	std::printf("All %zu threads are done\n", threads.size());
	return 0;
}
