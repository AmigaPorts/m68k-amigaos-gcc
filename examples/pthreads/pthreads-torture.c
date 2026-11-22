// Threads of a newlib program, built with -pthread, that never wait: only the
// end of a time slice switches them, which is what the per-thread reent and
// the locks have to survive.  Each thread checks that errno and strtok() stay
// its own across a busy loop, keeps a few heap blocks filled with its own
// pattern, and writes whole lines to one shared FILE.  The file is read back
// at the end.
//
// Under an emulator that only switches tasks when one waits, such as
// volamos, no switch happens and nothing is tested: run it on a real
// Kickstart.  The test counts the switches it saw inside its busy loops.
//
//   pthreads-torture [threads [rounds [spin]]]

#include <errno.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { MAX_THREADS = 16, BLOCKS = 8, MAX_FAILURES = 20 };

static const char *const out_name = "pthreads-torture.out";
static FILE *out;
static int threads = 6;
static int rounds = 500;
static int spin_count = 2000;

static pthread_mutex_t report_lock = PTHREAD_MUTEX_INITIALIZER;
static int failures;

static void fail(int id, int round, const char *what)
{
    pthread_mutex_lock(&report_lock);
    if (++failures <= MAX_FAILURES) {
        printf("FAIL: thread %d round %d: %s\n", id, round, what);
    }
    pthread_mutex_unlock(&report_lock);
}

// The last thread to start a busy loop, and how often another one started
// one meanwhile: the switches the test saw.  Without any, it proves nothing.
static volatile int spinner;
static atomic_int switches;

// A busy loop, long enough for a time slice to end in it now and then.
static void spin(int id)
{
    spinner = id;
    for (volatile int i = 0; i < spin_count; i++) {
    }
    if (spinner != id) {
        atomic_fetch_add(&switches, 1);
    }
}

static uint32_t next_random(uint32_t *state)
{
    *state = *state * 1103515245u + 12345u;
    return *state >> 8;
}

static void check_errno(int id, int round)
{
    errno = 1000 + id;
    spin(id);
    if (errno != 1000 + id) {
        fail(id, round, "errno changed");
    }
}

static void check_strtok(int id, int round)
{
    char line[64];
    char expected[3][16];

    snprintf(line, sizeof line, "t%d,r%d,x%d", id, round, id * 7);
    snprintf(expected[0], sizeof expected[0], "t%d", id);
    snprintf(expected[1], sizeof expected[1], "r%d", round);
    snprintf(expected[2], sizeof expected[2], "x%d", id * 7);

    const char *token = strtok(line, ",");
    for (int i = 0; i < 3; i++) {
        spin(id);
        if (token == nullptr || strcmp(token, expected[i]) != 0) {
            fail(id, round, "strtok() returned another thread's token");
            return;
        }
        token = strtok(nullptr, ",");
    }
    if (token != nullptr) {
        fail(id, round, "strtok() returned a token too many");
    }
}

struct block {
    unsigned char *data;
    size_t size;
};

static void check_block(int id, int round, const struct block *b)
{
    for (size_t i = 0; i < b->size; i++) {
        if (b->data[i] != (unsigned char)id) {
            fail(id, round, "a heap block was overwritten");
            return;
        }
    }
}

// Replace one of the thread's blocks with a new one of another size.
static void churn_heap(int id, int round, struct block blocks[BLOCKS], uint32_t *state)
{
    struct block *b = &blocks[next_random(state) % BLOCKS];

    if (b->data != nullptr) {
        check_block(id, round, b);
        free(b->data);
    }

    b->size = 1 + next_random(state) % 2000;
    b->data = malloc(b->size);
    if (b->data == nullptr) {
        fail(id, round, "malloc() failed");
        b->size = 0;
        return;
    }
    memset(b->data, id, b->size);
}

static void *run(void *arg)
{
    const int id = (int)(intptr_t)arg;
    struct block blocks[BLOCKS] = {};
    uint32_t state = 12345u + (uint32_t)id;

    for (int round = 0; round < rounds; round++) {
        check_errno(id, round);
        check_strtok(id, round);
        churn_heap(id, round, blocks, &state);
        fprintf(out, "thread %d round %d %s\n", id, round, "abcdefghijklmnopqrstuvwxyz");
    }

    for (int i = 0; i < BLOCKS; i++) {
        if (blocks[i].data != nullptr) {
            check_block(id, rounds, &blocks[i]);
            free(blocks[i].data);
        }
    }
    return nullptr;
}

// Every line must be whole, and each thread must have written all its rounds,
// in order.
static void check_output(void)
{
    FILE *in = fopen(out_name, "r");
    int next_round[MAX_THREADS] = {};
    char line[128];

    if (in == nullptr) {
        fail(-1, -1, "can't read the output back");
        return;
    }
    while (fgets(line, sizeof line, in) != nullptr) {
        int id;
        int round;
        char tail[64];

        if (sscanf(line, "thread %d round %d %63s", &id, &round, tail) != 3
            || id < 0 || id >= threads || round != next_round[id]
            || strcmp(tail, "abcdefghijklmnopqrstuvwxyz") != 0) {
            fail(-1, -1, "a line of the output is broken");
            continue;
        }
        next_round[id]++;
    }
    fclose(in);

    for (int id = 0; id < threads; id++) {
        if (next_round[id] != rounds) {
            fail(id, next_round[id], "lines of the output are missing");
        }
    }
}

int main(int argc, char **argv)
{
    pthread_t thread[MAX_THREADS];

    if (argc > 1) {
        threads = atoi(argv[1]);
    }
    if (argc > 2) {
        rounds = atoi(argv[2]);
    }
    if (argc > 3) {
        spin_count = atoi(argv[3]);
    }
    if (threads < 1 || threads > MAX_THREADS || rounds < 1) {
        fprintf(stderr, "usage: pthreads-torture [threads (1-%d) [rounds [spin]]]\n", MAX_THREADS);
        return 2;
    }

    out = fopen(out_name, "w");
    if (out == nullptr) {
        perror(out_name);
        return 2;
    }

    // The main task checks its own errno too: it must not see the threads'.
    errno = 999;
    for (int id = 0; id < threads; id++) {
        int err = pthread_create(&thread[id], nullptr, run, (void *)(intptr_t)id);
        if (err != 0) {
            fprintf(stderr, "pthread_create: %s\n", strerror(err));
            return 2;
        }
    }
    for (int id = 0; id < threads; id++) {
        pthread_join(thread[id], nullptr);
    }
    if (errno != 999) {
        fail(-1, -1, "the main task's errno changed");
    }

    fclose(out);
    check_output();

    printf("pthreads-torture: %d threads, %d rounds, %d task switches seen: %d failures\n",
           threads, rounds, switches, failures);
    if (switches == 0) {
        printf("pthreads-torture: no task switch inside a busy loop, so nothing was tested\n");
    }
    return failures != 0;
}
