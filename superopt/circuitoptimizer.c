#include <assert.h>
#include <limits.h>
#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

enum { max_wires = 20 };
enum { max_inputs = 5 };

typedef unsigned Word;

static const char *argv0 = "";

static void error (const char *plaint) {
    fprintf (stderr, "%s: %s\n", argv0, plaint);
    exit (1);
}

static int ninputs;
static Word mask;
static int nwires;

static Word wires[max_wires];
static int linputs[max_wires];
static int rinputs[max_wires];

static char vname (int w) {
    return (w < ninputs ? 'A' : 'a') + w;
}

static void print_circuit (void) {
    int w;
    for (w = ninputs; w < nwires; ++w)
        printf ("%s%c = ~(%c %c)",
                w == ninputs ? "" : "; ",
                vname (w), vname (linputs[w]), vname (rinputs[w]));
    printf("\n");
}

static unsigned parse_uint (const char *s, unsigned base) {
    assert (base == 10);
    return (unsigned) atoi (s); /* XXX */
}

static void superopt (const char *tt_output, int max_gates) {
    ninputs = (int) log2 (strlen (tt_output));
    if (1u << ninputs != strlen (tt_output))
        error ("truth_table_output must have a power-of-2 size");
}

int main (int argc, char **argv) {
    argv0 = argv[0];
    assert ((1ULL << (1ULL << max_inputs)) - 1ULL <= UINT_MAX);
    if (argc != 3)
        error ("Usage: circuitoptimizer truth_table_output max_gates");
    superopt (argv[1], (int) parse_uint (argv[2], 10));
    return 0;
}
