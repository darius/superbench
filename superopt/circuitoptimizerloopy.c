// gcc -std=c99 -W -Wall -g2 -O2 circuitoptimizerloopy.c -o circuitoptimizerloopy

#include <assert.h>
#include <errno.h>
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

static Word target_output;

static int ninputs;
static Word mask;

static int found = 0;           // boolean
static int nwires;
static Word wires[max_wires];
static int linputs[max_wires];
static int rinputs[max_wires];

static char vname (int w) {
    return (w < ninputs ? 'A' : 'a') + w;
}

static void print_circuit (void) {
    for (int w = ninputs; w < nwires; ++w)
        printf ("%s%c = ~(%c %c)",
                w == ninputs ? "" : "; ",
                vname (w), vname (linputs[w]), vname (rinputs[w]));
    printf("\n");
}

static Word compute (Word left_input, Word right_input) {
    return ~(left_input & right_input);
}

static void sweeping (void) {
    for (int k = 0; k < nwires; ++k)
        linputs[k] = rinputs[k] = 0;
    int w = ninputs;
    for (;;) {

        // Update the circuit representation for the current 'number':
        for (int k = w; k < nwires-1; ++k)
            wires[k] = compute (wires[linputs[k]], wires[rinputs[k]]);
        int last_rinput = 0;
        int last_linput = linputs[nwires-1];
        Word last_wire_linput = wires[last_linput];
        
        // Test the circuit and bump the 'last digit' until 'carry':
        do {
            if (target_output == (mask & compute (last_wire_linput,
                                                  wires[last_rinput]))) {
                found = 1;
                rinputs[w] = last_rinput;
                print_circuit ();
            }
        } while (++last_rinput <= last_linput);

        // Propagate the 'carry':
        w = nwires-1;
        while (w == ++linputs[w]) {
            linputs[w] = 0;
            if (--w < ninputs)
                return;         // 'Overflow'
            if (++rinputs[w] <= linputs[w])
                break;
            rinputs[w] = 0;
        }
    }
}

static void tabulate_inputs (void) {
    for (int i = 1; i <= ninputs; ++i) {
        Word shift = 1 << (i-1);
        wires[ninputs-i] = (1u << shift) - 1;
        for (int j = ninputs-i+1; j < ninputs; ++j)
            wires[j] |= wires[j] << shift;
    }
}

static void find_circuits (int max_gates) {
    mask = (1u << (1u << ninputs)) - 1u;
    tabulate_inputs ();
    printf ("Trying 0 gates...\n");
    if (target_output == 0 || target_output == mask) {
        printf ("%c = %d\n", vname (ninputs), target_output & 1);
        return;
    }
    for (int w = 0; w < ninputs; ++w)
        if (target_output == wires[w]) {
            printf ("%c = %c\n", vname (ninputs), vname (w));
            return;
        }
    for (int ngates = 1; ngates <= max_gates; ++ngates) {
        printf ("Trying %d gates...\n", ngates);
        nwires = ninputs + ngates;
        assert (nwires <= 26); // vnames must be letters
        if (sweeping (), found)
            return;
    }
}

static unsigned parse_uint (const char *s, unsigned base) {
    char *end;
    unsigned long u = strtoul (s, &end, base);
    if (u == 0 && errno == EINVAL)
        error (strerror (errno));
    if (*end != '\0')
        error ("Literal has crud in it, or extra spaces, or something");
    return (unsigned) u;
}

static void superopt (const char *tt_output, int max_gates) {
    ninputs = (int) log2 (strlen (tt_output));
    if (1u << ninputs != strlen (tt_output))
        error ("truth_table_output must have a power-of-2 size");
    if (max_inputs < ninputs)
        error ("Truth table too big. I can't represent so many inputs.");
    target_output = parse_uint (tt_output, 2);
    find_circuits (max_gates);
}

int main (int argc, char **argv) {
    argv0 = argv[0];
    assert ((1ULL << (1ULL << max_inputs)) - 1ULL <= UINT_MAX);
    if (argc != 3)
        error ("Usage: circuitoptimizer truth_table_output max_gates");
    superopt (argv[1], (int) parse_uint (argv[2], 10));
    return 0;
}
