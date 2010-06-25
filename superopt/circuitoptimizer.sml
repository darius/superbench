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

val toW = Word.fromInt

fun tabulate_inputs ninputs =
    if ninputs = 0
    then []
    else let val shift = 0w1 << toW (ninputs-1)
         in ((0w1 << shift) - 0w1) :: map (fn iv => iv + (iv << shift))
                                          (tabulate_inputs (ninputs - 1))
         end

fun main [truth_table]     = superopt truth_table 6
  | main [truth_table, mg] = superopt truth_table (intFromString mg)
  | main _ = fail "usage: circuitoptimizer truth_table [max_gates]"

val _ =
    (app (println o Word.toString) (tabulate_inputs 5);
     ())
(*
     main (CommandLine.arguments ())) *)
