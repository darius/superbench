// gcc -std=c99 -W -Wall -g2 -O2 circuitoptimizerbummed.c -o circuitoptimizerbummed

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

// gates_used[w] = a bitset of all gate wires transitively used if you
//   use gate w
static Word gates_used[max_wires];  

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

static void note_found (int llwire, int rr) {
    if (llwire < wires[rr]) return;
    found = 1;
    rinputs[nwires-1] = rr;
    print_circuit ();
}

// Given the partial circuit before wire #w, with bitset prev_used
// representing which gates are used as inputs within that circuit.
// (And all_used_size must be the number of bits set in prev_used,
// plus a loop-invariant offset to make the too-many-unused comparison
// go faster.)
// Check all extensions of that partial circuit to nwires (pruned
// for symmetry and optimality).
static void sweeping (int w, Word prev_used, int prev_used_size) {
    for (int ll = 0; ll < w; ++ll) {
        Word llwire = wires[ll];
        linputs[w] = ll;

        if (w+1 < nwires) {
            int l_used_size = prev_used_size;
            if (ninputs <= ll)
                l_used_size += 1 & ((~prev_used) >> ll);

            // Since NAND is symmetric, we can require the right wire's 
            // number to be <= the left one's.
            for (int rr = 0; rr <= ll; ++rr) {
                Word rrwire = wires[rr];

                // To produce fewer equivalent circuits, we enforce an
                // ordering on the *truth functions* of the inputs too.
                if (llwire < rrwire)
                    goto skip;

                // Require the count of inputs still unassigned to be
                // enough to use all of the still-unused gate outputs.
                Word used = gates_used[ll] | gates_used[rr];
                Word all_used = prev_used | used;
                int all_used_size = l_used_size;
                if (ninputs <= rr && ll != rr)
                    all_used_size += 1 & ((~prev_used) >> rr);
                // The ridiculously opaque expression below is equivalent to, but
                // faster than, the more obvious
                //   Word n_internal_gates = ngates - 1;  // (hoisted to global)
                //   Word n_unused = n_internal_gates - popcount (all_used);
                //   Word n_still_unassigned = 2 * (nwires - w - 1);
                //   if (n_still_unassigned < n_unused)
                if (all_used_size < 2*w)
                    goto skip;

                Word w_wire = compute (llwire, rrwire);

                // Two ways of pruning, with combined code.
                // First, we enforce an order on the truth functions of
                // gates that commute. Gate w commutes with gate k if
                // gate w uses no wire between k and w.
                // Second, computing w_wire twice can't be optimal.
                int k;
                for (k = w-1; ninputs <= k; --k) {
                    if (used & (1 << k))
                        break;
                    if (w_wire <= wires[k])
                        goto skip;
                }
                for (; 0 <= k; --k) {
                    if (wires[k] == w_wire)
                        goto skip;
                }

                // OK! This gate's not pruned.
                // XXX The above pruning logic is pretty hairy. Test that it works.
                gates_used[w] = used | (1 << w);
                wires[w] = w_wire;
                rinputs[w] = rr;
                sweeping (w + 1, all_used, all_used_size);
            skip: ;
            }
        } else if (ll == w-1) {
            for (int rr = 0; rr <= ll; ++rr) {
                if ((mask & compute (llwire, wires[rr])) == target_output)
                    note_found (llwire, rr);
            }
        } else {
            // The last gate must use the next-to-last gate's
            // output. The left input here being from another gate
            // forces our choice of the right input.
            int rr = w-1;
            if (rr <= ll && (mask & compute (llwire, wires[rr])) == target_output)
                note_found (llwire, rr);
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
    memset (gates_used, 0, sizeof gates_used);
    for (int ngates = 1; ngates <= max_gates; ++ngates) {
        printf ("Trying %d gates...\n", ngates);
        nwires = ninputs + ngates;
        assert (nwires <= 26); // vnames must be letters
        if (sweeping (ninputs, 0, ninputs + nwires - 1), found)
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
