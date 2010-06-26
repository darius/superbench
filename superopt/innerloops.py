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

Verdict: the nonrecursive solution is horrible. It might go a little
bit faster with less overhead in the outer loops, but it has nothing
else to recommend it that I can see. (Though my version is more awful
than it needs to be, in defining a compute() in terms of inner-loop
variables instead of a compute(left_input_value, right_input_value).)

I was hoping it'd go nicer, since the recursive one needs a bit of
code duplication for the sake of a tight inner loop (and could take a
bit of advantage of more, by duplicating the "for ll" loop, too).

I'll have to go check the superoptimizer papers out there now and see
what everyone does in practice. I'd imagine the recursive one could
incorporate some of the algorithmic improvements more easily.

TODO: count down instead of up
TODO: compute(left, right) instead
"""

ninputs = 2
ngates  = 2
nwires  = ninputs + ngates
inputs  = [0x3, 0x5]            # Vectorized
mask    = (1 << (1 << ninputs)) - 1
wanted  = 0xC                   # Vectorized target output

def recursive_loop():
    linput = [0]*nwires
    rinput = [0]*nwires
    wire = inputs + [None]*(ngates-1)
    def outer(w):
        for ll in range(w):
            llwire = wire[ll]
            def compute(rr):
                return ~(llwire & wire[rr])
            if w+1 == nwires:
                # Inner loop:
                for rr in range(ll+1):
                    last_wire = compute(rr)
                    if last_wire & mask == wanted:
                        print linput, rinput, wire + [last_wire]
            else:
                for rr in range(ll+1):
                    wire[w] = compute(rr)
                    linput[w] = ll
                    rinput[w] = rr
                    outer(w + 1)
    outer(ninputs)

def loopy_loop():
    linput = [0]*nwires
    rinput = [0]*(nwires-1)   # (The last rinput value is computed elsewhere.)
    wire = inputs + [None]*(ngates-1) # (The last wire is computed elsewhere.)
    def compute():
        return ~(last_wire_linput & wire[last_rinput])
    w = ninputs
    while True:
        # Reestablish the wire[] and last_foo invariants:
        for k in range(w, nwires-1):
            last_wire_linput = wire[linput[k]]
            last_rinput = rinput[k]
            wire[k] = compute()
        last_rinput = 0
        last_linput = linput[-1]
        last_wire_linput = wire[last_linput]
        # Inner loop:
        while True:
            last_wire = compute()
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
