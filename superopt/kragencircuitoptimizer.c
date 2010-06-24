/*
primitive circuit optimizer

Kragen Sitaker kragen@pobox.com 
Sun, 16 Feb 2003 01:12:50 -0500 (EST)
Previous message: compiling Python arithmetic expressions to machine code
Next message: 'hello world' with pyGTK and ZODB
Messages sorted by: [ date ] [ thread ] [ subject ] [ author ]
Given a desired truth table, this program exhaustively searches
through combinations of NAND gates to find ways to produce this truth
table.  I'm sure e.g. VHDL synthesizers have better implementations of
this; on my 300MHz laptop, this takes about 2 seconds to run through
all the 5-gate circuits, which involves examining 549 067 candidate
circuits, and 75 seconds to run through all the 6-gate circuits.  (I'm
still running through all the 7-gate circuits as I write this.)  It
took some work to get even to this level of performance, but it still
runs through a lot of redundant work --- circuits that can't possibly
work, multiple permutations of the same circuit.
*/
/*
 * search through combinations of NAND gates for a combinatorial
 * circuit producing a particular truth table
 *
 * BUGS:
 * - produces suboptimal output (3 gates) for circuits with always-0
 *   or always-1 output, and also (2 gates) for circuits whose output is
 *   simply one of their inputs, other than the last input.
 */

#include <assert.h>
#include <setjmp.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

typedef struct {
  int ninputs, ngates; /* number of circuit inputs and number of gates */
  int input[1][2];  /* not really [1]... really [ngates+ninputs] */
  /* each input[a][b] contains input #b for gate #a.  gates < ninputs are dummy gates
   * whose output is a circuit input. */
} circuit;

circuit *newcircuit(int ninputs, int ngates) {
  circuit *cp = malloc(sizeof(*cp) + (ninputs + ngates - 1) * 2 * sizeof(int));
  if (!cp) return 0;
  cp->ninputs = ninputs;
  cp->ngates = ngates;
  return cp;
}

int evalcircuit(circuit *cp, int *inputs) {
  int noutputs = cp->ninputs + cp->ngates;
  int outputs[noutputs];  /* gcc extension to C: variable-size arrays */
  int ii;
  for (ii = 0; ii < cp->ninputs; ii++) outputs[ii] = inputs[ii];
  for (ii = cp->ninputs; ii < noutputs; ii++)
    outputs[ii] = !(outputs[cp->input[ii][0]] && outputs[cp->input[ii][1]]);
  return outputs[noutputs - 1];
}

char varname(int ii) { return ii < 3 ? 'A' + ii : 'a' + ii; }

int gate_output_used_more_than_once(circuit *cp, int gatenum) {
  int ii, jj;
  int uses = 0;
  for (ii = cp->ninputs; ii < cp->ninputs + cp->ngates; ii++) {
    for (jj = 0; jj < 2; jj++)
      if (cp->input[ii][jj] == gatenum) uses++;
  }
  return (uses > 1);
}

void print_gate_expression_or_var(circuit *cp, int gatenum);
void print_gate_expression(circuit *cp, int gatenum) {
  printf("-(");
  print_gate_expression_or_var(cp, cp->input[gatenum][0]);
  printf("*");
  print_gate_expression_or_var(cp, cp->input[gatenum][1]);
  printf(")");
}

void print_gate_expression_or_var(circuit *cp, int gatenum) {
  if (gatenum < cp->ninputs || gate_output_used_more_than_once(cp, gatenum)) {
    printf("%c", varname(gatenum));
  } else {
    print_gate_expression(cp, gatenum);
  }
}

void nicely_print_circuit(circuit *cp) {
  int ii;
  int output = cp->ninputs + cp->ngates - 1;
  for (ii = cp->ninputs; ii <= output; ii++)
    if (ii == output || gate_output_used_more_than_once(cp, ii)) {
      printf("%c = ", varname(ii));
      print_gate_expression(cp, ii);
      printf("\n");
    }
}

void printcircuit(circuit *cp) {
  int ii;
  for (ii = cp->ninputs; ii < cp->ninputs + cp->ngates; ii++)
    printf("%c = ~(%c %c); ", 
	   varname(ii), varname(cp->input[ii][0]), varname(cp->input[ii][1]));
  printf("\n");
}

void printentry(void *cd, circuit *cp, int *inputs, int output) {
  int ii;
  (void) cd;
  for (ii = 0; ii != cp->ninputs; ii++)
    printf("%d ", inputs[ii]);
  printf("-> %d\n", output);
}

void printentry_brief(void *cd, circuit *cp, int *inputs, int output) {
  (void) cd;
  (void) cp;
  (void) inputs;
  printf("%d", output);
}

void enumtable(circuit *cp, void *client_data, 
	       void (*cb)(void *client_data, 
			  circuit *cp, 
			  int *inputs, 
			  int output)
	       ) {
  int inputs[cp->ninputs];
  int ii;
  for (ii = 0; ii < cp->ninputs; ii++) inputs[ii] = 0;
  nextline: for (;;) {
    (*cb)(client_data, cp, inputs, evalcircuit(cp, inputs));
    for (ii = cp->ninputs - 1; ii >= 0; ii--)
      if (!inputs[ii]) {
	for (; ii < cp->ninputs; ii++) 
	  inputs[ii] = !inputs[ii];
	goto nextline;  /* we just horked ii */
      }
    return;
  }
}

void reset_circuit(circuit *cp) {
  int ii;
  for (ii = 0; ii < cp->ngates; ii++) {
    cp->input[cp->ninputs + ii][0] = 0;
    cp->input[cp->ninputs + ii][1] = 0;
  }
}

/* go to the lexically next valid circuit and return 1, 
 * or return 0 if that's not possible. */
int increment_circuit(circuit *cp) {
  /* in valid circuits, each input[ii][x] < ii, and of course >= 0. */
  /* We also enforce the condition that input[ii][1] <= input[ii][0],
   * because NAND is commutative; considering both -(B*A) and -(A*B)
   * doesn't help. */
  int ii;
  int min;
  for (ii = cp->ninputs + cp->ngates - 1; ii >= cp->ninputs; ii--) {
    min = ii - 1;
    if (cp->input[ii][0] < min) min = cp->input[ii][0];
    if (cp->input[ii][1] != min) {
      cp->input[ii][1]++;
    zero_lower_order_gates:
      for (ii++; ii < cp->ninputs + cp->ngates; ii++) {
        cp->input[ii][0] = 0;
        cp->input[ii][1] = 0;
      }
      return 1;
    }
    if (cp->input[ii][0] != ii - 1) {
      cp->input[ii][0]++;
      cp->input[ii][1] = 0;
      goto zero_lower_order_gates;
    }
  }
  return 0;
}

/* it isn't *really* necessary to put this in a struct.  Maybe I've
   been programming Python too much... */
typedef struct {
  int counter;
  char *pattern;
  jmp_buf mismatch;
} search_result;

search_result the_search_result;

void match(void *client_data, circuit *cp, int *inputs, int output) {
  (void) cp;
  (void) inputs;
  search_result *sr = client_data;
  char pattern_element = sr->pattern[sr->counter];
  sr->counter++;
  if (pattern_element == 'x') return;  /* don't care */
  if (output != pattern_element - '0') longjmp(sr->mismatch, -1);
}

int test_circuit(circuit *cp, char *pattern) {
  search_result *sr = &the_search_result;
  sr->counter = 0;
  sr->pattern = pattern;

  if (setjmp(sr->mismatch) == 0) {
    enumtable(cp, sr, &match);
  } else {
    return 0;  /* found a mismatch */
  }
  return 1;
}

int inputs_for_pattern(char *pattern) {
  char *s;
  int len;
  int log2 = 0;
  for (s = pattern; *s; s++)
    if ((*s != '0') && (*s != '1') && (*s != 'x')) return 0;
  len = s - pattern;
  while (len > 1) {
    if (len & 1) return 0;
    log2 ++;
    len >>= 1;
  }
  return log2;
}

int max_gates_for_inputs(int inputs) { 
  (void) inputs;
  /* this function may not be useful to implement, as the program
     takes too long to run in practice for more than a few gates. */
  return 100; 
}

int main(int argc, char **argv) {
  circuit *cp = 0;
  int ninputs, ngates, maxgates, done;
  if (argc != 2) {
    fprintf(stderr, 
	    "%s: Usage: %s pattern\n"
	    "pattern is a pattern of 0's, 1's, and x's.\n", 
	    argv[0], argv[0]);
    return 1;
  }
  if (!(ninputs = inputs_for_pattern(argv[1]))) {
    fprintf(stderr,
	    "%s: Don't understand pattern '%s' of length %lu.\n"
	    "Pattern lengths should be powers of 2; they "
	    "consist of 0's, 1's, and x's.\n",
	    argv[0], argv[1], strlen(argv[1]));
    return 2;
  }
  {
    int ii;
    printf("Inputs: ");
    for (ii = 0; ii < ninputs; ii++)
      printf("%c ", varname(ii));
    printf("\n");
  }
  maxgates = max_gates_for_inputs(ninputs);
  done = 0;
  for (ngates = 0; ngates <= maxgates; ngates++) {
    printf("Trying with %d gates...\n", ngates);
    free(cp);
    cp = newcircuit(ninputs, ngates);
    if (!cp) {  /* out of memory, probably; how likely is that?! */
      fprintf(stderr, "For %d inputs and %d gates", ninputs, ngates);
      perror("newcircuit");
      return 3;
    }
    reset_circuit(cp);
    printf("\n");
    do {
      if (test_circuit(cp, argv[1])) {
          //nicely_print_circuit(cp);
          printcircuit(cp);
          //enumtable(cp, 0, &printentry);
	done = 1;
      }
    } while (increment_circuit(cp));
    if (done) return 0;  /* no need to try more complex circuits... */
  }
  assert(0);  /* should never happen */
}
