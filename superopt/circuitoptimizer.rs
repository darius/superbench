// Crude first-cut port of circuitoptimizer.py

fn main() {
   let a = std::os::args();
   assert!(a.len() == 2 || a.len() == 3);
   let truth_table = a.get(1);
   let max_gates = if a.len() == 2 { 6 }
                   else { from_str(a.get(2).as_slice()).unwrap() };
   let ninputs = (truth_table.len() as f64).log2();
   assert!(ninputs == ninputs.floor());
   find_circuits(std::num::from_str_radix(truth_table.as_slice(), 2).unwrap(),
                 ninputs as uint,
                 max_gates)
}

struct Inputs {
   in1: uint,
   in2: uint
}

fn find_circuits(wanted: uint, ninputs: uint, max_gates: uint) {
   let inputs = tabulate_inputs(ninputs);
   let mask = (1u << (1u << ninputs)) - 1;
   println!("{} {} {} {} {}", wanted, ninputs, max_gates, inputs, mask);
   //   println("Trying 0 gates...");
   for ngates in range(1, max_gates + 1) {
      println!("Trying {} gates...", ngates);
      if find_for_n(wanted, ninputs, &inputs, mask, ngates) { break }
   }
}

fn find_for_n(wanted: uint, ninputs: uint, inputs: &Vec<uint>, mask: uint, ngates: uint) -> bool {
   let mut circuit: Vec<Inputs> = Vec::new();
   for _ in range(0, ngates) { circuit.push(Inputs { in1: 0, in2: 0 }) }
   let mut values = inputs.clone();
   for _ in range(0, ngates) { values.push(0) }
   searching(wanted, ninputs, mask, ngates, circuit.as_mut_slice(), values.as_mut_slice(), 0u)
}

fn searching(wanted: uint, ninputs: uint, mask: uint, ngates: uint, circuit: &mut [Inputs], values: &mut [uint], gate: uint) -> bool {
   let mut found = false;
   for in1 in range(0, ninputs + gate) {
      circuit[gate].in1 = in1;
      for in2 in range(0, in1 + 1) {
         circuit[gate].in2 = in2;
         values[ninputs + gate] = !(values[in1] & values[in2]);
         if gate + 1 < ngates {
            found |= searching(wanted, ninputs, mask, ngates, circuit, values, gate + 1);
         } else if (mask & values[ninputs + gate]) == wanted {  // XXX values[-1]?
            found = true;
            print_formula(ninputs, circuit);
         }
      }
   }
   found
}

fn print_formula(ninputs: uint, circuit: &[Inputs]) {
   let vname = "abcdefghijklmnopqrstuvwxyz";  // TODO: capitalize input vars
   for (i, inputs) in circuit.iter().enumerate() {
      print!("; ");
      print!("{} = ~({} {})", vname[ninputs+i], vname[inputs.in1], vname[inputs.in2]);
      // Oops, we're getting character codes instead of characters, above.
   }
   println!("");
}

fn tabulate_inputs(ninputs: uint) -> Vec<uint> {
   if ninputs == 0 {
      Vec::new()
   } else {
      let shift: uint = 1u << (ninputs - 1);
      let ivs = tabulate_inputs(ninputs - 1);
      let mut v = Vec::new();
      let v0: uint = (1u << shift) - 1;
      v.push(v0);
      for iv in ivs.iter() {
         v.push((iv | (iv << shift)) as uint)
      }
      v
   }
}
