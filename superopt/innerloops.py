"""
Trying to code a superoptimizer efficiently and cleanly and with no
code duplication:

 * The inner loop should just increment a right-wire index, test that
   it's still in range, fetch its wire value, compute a function of
   the input wires (NAND in this case), and compare it to the target.

 * The function should be appear in just one place in the code -- it
   might be a fancier function in a fancier superoptimizer. (This
   requirement turns out to be silly, I guess. We need to encapsulate
   it in some kind of procedure called from multiple places no matter
   what, it seems, if the first requirement above is to be met. Let
   the bloody compiler inline it.)

 * The code should be as clean and minimal as possible.

Verdict: the nonrecursive solution is quite tricky code. I was hoping
it'd go nicer, since the recursive one needs a bit of code duplication
for the sake of a tight inner loop (and could take a bit of advantage
of more, by duplicating the "for ll" loop, too).

I'll have to go check the superoptimizer papers out there now and see
what everyone does in practice. I'd imagine the recursive one could
incorporate some of the algorithmic improvements more easily.

Surprise: recursive is ~4 times as fast in Python.

TODO: count down instead of up
"""

def tabulate_inputs(ninputs):
    """An inputs vector is a list of ninputs bitstrings. It holds all
    possible input patterns 'transposed': that is, the kth test case
    can be formed out of bit #k of each the list's elements, one
    element per circuit input:
    [[(input >> k) & 1 for input in result] for k in range(1 << ninputs)]
    Transposed is more useful because we can compute all test cases in
    parallel using bitwise operators."""
    if ninputs == 0: return []
    shift = 1 << (ninputs-1)
    return [(1 << shift) - 1] + [iv | (iv << shift)
                                 for iv in tabulate_inputs(ninputs-1)]

bench = False
if bench:
    ninputs = 3
    ngates  = 6
    wanted  = 0x67              # Vectorized target output
else:
    ninputs = 2
    ngates  = 2
    wanted  = 0xC

nwires  = ninputs + ngates
inputs  = tabulate_inputs(ninputs)
mask    = (1 << (1 << ninputs)) - 1

def compute(left_input, right_input):
    return ~(left_input & right_input)

def recursive_loop():
    linput = [0]*nwires
    rinput = [0]*(nwires-1)
    wire = inputs + [None]*(ngates-1)
    def outer(w):
        for ll in xrange(w):
            linput[w] = ll
            llwire = wire[ll]
            if w+1 == nwires:
                # Inner loop:
                for rr in xrange(ll+1):
                    last_wire = compute(llwire, wire[rr])
                    if last_wire & mask == wanted:
                        print linput, rinput + [rr], wire + [last_wire]
            else:
                for rr in xrange(ll+1):
                    wire[w] = compute(llwire, wire[rr])
                    rinput[w] = rr
                    outer(w + 1)
    outer(ninputs)

def loopy_loop():
    linput = [0]*nwires
    rinput = [0]*(nwires-1)   # (The last rinput value is computed elsewhere.)
    wire = inputs + [None]*(ngates-1) # (The last wire is computed elsewhere.)
    w = ninputs
    while True:
        # Reestablish the wire[] and last_foo invariants:
        for k in xrange(w, nwires-1):
            wire[k] = compute(wire[linput[k]], wire[rinput[k]])
        last_rinput = 0
        last_linput = linput[-1]
        last_wire_linput = wire[last_linput]
        # Inner loop:
        while True:
            last_wire = compute(last_wire_linput, wire[last_rinput])
            if last_wire & mask == wanted:
                print linput, rinput + [last_rinput], wire + [last_wire]
            # Increment the 'last digit':
            last_rinput += 1
            if last_linput < last_rinput:
                break
        # Propagate the 'carry':
        w = nwires-1
        while True:
            linput[w] += 1
            if linput[w] < w:
                break
            linput[w] = 0
            w -= 1
            if w < 0:
                return
            rinput[w] += 1
            if rinput[w] <= linput[w]:
                break
            rinput[w] = 0

## recursive_loop()
#. [0, 0, 0, 0] [0, 0, 0, 0] [3, 5, -4, -4]
#. [0, 0, 1, 0] [0, 0, 0, 0] [3, 5, -2, -4]
#. [0, 0, 1, 0] [0, 0, 1, 0] [3, 5, -6, -4]
#. 
## loopy_loop()
#. [0, 0, 0, 0] [0, 0, 0, 0] [3, 5, -4, -4]
#. [0, 0, 1, 0] [0, 0, 0, 0] [3, 5, -2, -4]
#. [0, 0, 1, 0] [0, 0, 1, 0] [3, 5, -6, -4]
#. 

if bench:
    recursive_loop()
    #loopy_loop()
