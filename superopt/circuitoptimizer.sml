(*
A superoptimizer for combinational NAND circuits.
Based on my Python version.
TODO: 
  * check that infix precedences are sane
*)

val <<     = Word.<<        infix 5 <<
val andb   = Word.andb      infix 5 andb
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

fun find_for_ngates target_output ninputs ngates inputs mask = 
    let val found = ref false
        val n = ninputs + ngates
        val gate_l = Array.array (n, 0)
        val gate_r = Array.array (n, 0)
        val values = Array.tabulate (n, fn i => if i < ninputs
                                                then inputs sub i
                                                else 0w0)
        fun loop_gate gate =
            if gate+1 < n
            then let fun loop_l ll =
                         if ll < 0
                         then ()
                         else (update (gate_l, gate, ll);
                               let val llvalue = values sub ll
                                   fun loop_r rr =
                                       if rr < 0
                                       then loop_l (ll-1)
                                       else let val value =
                                                    notb (llvalue andb (values sub rr))
                                            in update (gate_r, gate, rr);
                                               update (values, gate, value);
                                               loop_gate (gate+1);
                                               loop_r (rr-1)
                                            end
                               in loop_r ll
                               end)
                 in loop_l (gate-1)
                 end
            else let fun loop_l ll =
                         if ll < 0
                         then ()
                         else let val llvalue = values sub ll
                                  fun loop_r rr =
                                      if rr < 0
                                      then loop_l (ll-1)
                                      else let val value =
                                                   notb (llvalue andb (values sub rr))
                                           in if target_output = value andb mask
                                              then (found := true;
                                                    update (gate_l, gate, ll);
                                                    update (gate_r, gate, rr);
                                                    print_formula ninputs gate_l gate_r)
                                              else ();
                                              loop_r (rr-1) 
                                           end
                              in loop_r ll
                              end
                 in loop_l (gate-1)
                 end
    in loop_gate ninputs; !found
    end
    
fun find_nontrivial_circuits target_output ninputs max_gates inputs mask = 
    let fun loop ngates =
            ngates <= max_gates
            andalso (println ("Trying " ^ (Int.toString ngates) ^ " gates...");
                     find_for_n ngates orelse loop (ngates+1))
        and find_for_n ngates =
            find_for_ngates target_output ninputs ngates inputs mask
    in loop 1
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
        find_circuits (toW (parse_binary truth_table)) ninputs max_gates
    end

fun main [truth_table]     = superopt truth_table 6
  | main [truth_table, mg] = superopt truth_table (parse_decimal mg)
  | main _ = fail "usage: circuitoptimizer truth_table [max_gates]"

val _ =
     main (CommandLine.arguments ())
