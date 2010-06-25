(*
A superoptimizer for combinational NAND circuits.

Based on my Python version.

TODO: actually finish
*)

val << = Word.<<     infix 5 <<

fun fail s =
    raise (Fail s)

fun println s =
    (print s; print "\n")

fun intFromString s =
    (case Int.fromString s
      of NONE => fail "Not an integer"
       | SOME n => n)

fun log2 (n: real) =
    Math.ln n / Math.ln 2.0

fun log2int (n: int) =
    let val result = Real.round (log2 (Real.fromInt n))
    in if n = Real.round (Math.pow (2.0, Real.fromInt result))
       then result
       else fail "Wrong-sized truth table"
    end

fun superopt truth_table max_gates =
    let val ninputs = log2int (String.size truth_table)
    in (* find_circuits foo ninputs max_gates *)
        println (Int.toString ninputs)
    end

fun tabulate_inputs ninputs =
    let val inputs = []
        val mask = (0w1 << (0w1 << ninputs)) - 0w1
        val bits = mask
    in bits
    end

fun main [truth_table]     = superopt truth_table 6
  | main [truth_table, mg] = superopt truth_table (intFromString mg)
  | main _ = fail "usage: circuitoptimizer truth_table [max_gates]"

val _ =
    (println (Word.toString (tabulate_inputs 0w4));
     ())
(*     main (CommandLine.arguments ())) *)
