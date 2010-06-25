(*
A superoptimizer for combinational NAND circuits.
Based on my Python version.
TODO: 
  * actually finish
  * check that infix precedences are sane
*)

val <<     = Word.<<        infix 5 <<
val andb   = Word.andb      infix 3 andb
val notb   = Word.notb
val toW    = Word.fromInt

val sub    = Array.sub      infix 4 sub
val update = Array.update

fun fail s =
    raise (Fail s)

fun println s =
    (print s; print "\n")

fun require opt plaint =
    (case opt
      of NONE   => fail plaint
       | SOME x => x)

fun parse_decimal s =
    require (Int.fromString s) "Not an integer"

fun parse_binary s =
    require (StringCvt.scanString (Int.scan StringCvt.BIN) s)
            "Not a binary integer"

fun log2 (n: real) =
    Math.ln n / Math.ln 2.0

fun log2int (n: int) =
    let val result = round (log2 (real n))
    in if n = round (Math.pow (2.0, real result))
       then result
       else fail "Wrong-sized truth table"
    end

fun tabulate_inputs ninputs =
    if ninputs = 0
    then []
    else let val shift = 0w1 << toW (ninputs-1)
         in ((0w1 << shift) - 0w1) :: map (fn iv => iv + (iv << shift))
                                          (tabulate_inputs (ninputs - 1))
         end

val vnames = "abcdefghijklmnopqrstuvwxyz"

fun vname v =
    String.str (String.sub (vnames, v))

fun input_names ninputs =
    map String.str (explode (String.substring (vnames, 0, ninputs)))

fun print_formula ninputs gate_l gate_r =
    let fun lname i = vname (gate_l sub i)
        fun rname i = vname (gate_r sub i)
        fun loop i =
            if i = Array.length gate_l
            then print "\n"
            else (print ((if ninputs < i then "; " else "")
                         ^ (vname i)
                         ^ " = ~(" ^ (lname i) ^ " " ^ (rname i) ^ ")");
                  loop (i + 1))
    in loop ninputs
    end

fun find_trivial_circuits target_output ninputs inputs_list mask = 
    (println "Trying 0 gates...";
     case List.find (fn (name, input) => input = target_output)
                    (ListPair.zip (["0","1"] @ (input_names ninputs),
                                   [0w0,mask] @ inputs_list))
      of SOME (name, input) => (println ((vname ninputs) ^ " = " ^ name);
                                true)
       | NONE => false)

fun find_nontrivial_circuits target_output ninputs max_gates inputs mask = 
    let val found = ref false
        val gate_l = Array.array (ninputs+1, 0)
        val gate_r = Array.array (ninputs+1, 0)
        fun loop_l (~1) = ()
          | loop_l ll =
            (update (gate_l, ninputs, ll);
             let val value_l = inputs sub ll
                 fun loop_r (~1) = loop_l (ll-1)
                   | loop_r rr =
                     (update (gate_r, ninputs, rr);
                      if target_output =
                         (mask andb notb (value_l andb (inputs sub rr)))
                      then (found := true;
                            print_formula ninputs gate_l gate_r)
                      else ();
                      loop_r (rr-1))
             in loop_r ll
             end)
    in println "Trying 1 gates..."; loop_l (ninputs-1); !found
    end
    
fun find_circuits target_output ninputs max_gates =
    let val inputs_list = tabulate_inputs ninputs
        val inputs = Array.fromList inputs_list
        val mask = (0w1 << (0w1 << toW ninputs)) - 0w1
    in find_trivial_circuits target_output ninputs inputs_list mask
       orelse 
       find_nontrivial_circuits target_output ninputs max_gates inputs mask
    end

fun superopt truth_table max_gates =
    let val ninputs = log2int (String.size truth_table)
    in
        (println (Int.toString ninputs);
         find_circuits (toW (parse_binary truth_table)) ninputs max_gates)
    end

fun main [truth_table]     = superopt truth_table 6
  | main [truth_table, mg] = superopt truth_table (parse_decimal mg)
  | main _ = fail "usage: circuitoptimizer truth_table [max_gates]"

val _ =
    (app (println o Word.toString) (tabulate_inputs 5);
     print_formula 3
                   (Array.fromList [0,0,0,1,0])
                   (Array.fromList [0,0,0,2,3]);
     main (CommandLine.arguments ()))
