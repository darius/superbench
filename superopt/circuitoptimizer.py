"""
A superoptimizer for combinational NAND circuits.

Based on Kragen Sitaker's in C, but vectorized and doesn't do
don't-cares. (It could by masking the output before comparing it to
the target.)

TODO: 
  * support don't-cares
  * eliminate more equivalent circuits without checking them
  * also skip circuits with unused outputs
"""

import math
import operator
import string

def superopt(truth_table, max_gates=None):
    """Given a truth table's outputs as a string, print out any
    small-enough NAND-gate circuits that compute that function."""
    ninputs = int(math.log(len(truth_table), 2))
    assert (1 << ninputs) == len(truth_table)
    find_circuits(int(truth_table, 2), ninputs, max_gates)

def find_circuits(wanted, ninputs, max_gates=None):
    """Given a truth table's output bitvector and #inputs, print
    out its circuits as above."""
    if max_gates is None: max_gates = 5
    inputs = make_inputs_vector(ninputs)
    mask = (1 << (1 << ninputs)) - 1

    def find_for_n(ngates):
        "Find any specified circuits with exactly ngates gates."
        circuit = [None] * ngates
        values = inputs + [None] * ngates
        found = [False]
        def searching(gate):
            "Try all possible inputs for all gates at index >= gate."
            if gate == ngates:
                if (mask & values[-1]) == wanted:
                    found[0] = True
                    print formula(circuit)
            else:
                for L in range(ninputs + gate):
                    for R in range(L + 1): # (NAND gates are symmetric)
                        circuit[gate] = (L, R)
                        values[ninputs + gate] = ~(values[L] & values[R])
                        searching(gate + 1)
        searching(0)
        return found[0]

    def formula(circuit):
        "Describe circuit for a human."
        return '; '.join(('%s = ~(%s %s)'
                          % (vname[i+ninputs], vname[L], vname[R]))
                       for i, (L, R) in enumerate(circuit))

    vname = string.ascii_uppercase[:ninputs] + string.ascii_lowercase[ninputs:]

    print 'Trying 0 gates...'
    for name, input in zip('01' + vname, [0, mask] + inputs):
        if wanted == input:
            print '%s = %s' % (vname[ninputs], name)
            return
    for ngates in range(1, max_gates+1):
        print 'Trying %d gates...' % ngates
        assert ninputs + ngates <= len(vname)
        if find_for_n(ngates):
            return

def make_inputs_vector(ninputs):
    """An inputs vector is a list of ninputs bitstrings. It holds all
    possible input patterns 'transposed': that is, the kth test case
    can be formed out of bit #k of each the list's elements, one
    element per circuit input:
    [[(input >> k) & 1 for input in result] for k in range(1 << ninputs)]
    Transposed is more useful because we can compute all test cases in
    parallel using bitwise operators."""
    # TODO: Prove correctness. I just hacked this by generalizing an example.
    inputs = []
    bits = mask = (1 << (1 << ninputs)) - 1
    for i in range(ninputs-1, -1, -1):
        bits ^= bits >> (1 << i)
        inputs.append(mask ^ bits)
    return inputs

## ['%x' % i for i in make_inputs_vector(5)]
#. ['ffff', 'ff00ff', 'f0f0f0f', '33333333', '55555555']

## superopt('0101')
#. Trying 0 gates...
#. c = B
#. 
## superopt('0110')
#. Trying 0 gates...
#. Trying 1 gates...
#. Trying 2 gates...
#. Trying 3 gates...
#. Trying 4 gates...
#. c = ~(B A); d = ~(c A); e = ~(c B); f = ~(e d)
#. c = ~(B A); d = ~(c B); e = ~(c A); f = ~(e d)
#. 

if __name__ == '__main__':
    from sys import argv
    if len(argv) == 2:
        superopt(argv[1])
    elif len(argv) == 3:
        superopt(argv[1], int(argv[2]))
    else:
        assert False
