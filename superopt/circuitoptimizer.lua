local bit = require('bit')
local bnot   = bit.bnot
local band   = bit.band
local lshift = bit.lshift

function find_circuits(wanted, ninputs, max_gates)
   local inputs = tabulate_inputs(ninputs)
   local mask = lshift(1, lshift(1, ninputs)) - 1

   function vname(i)
      if i < ninputs then
         return string.char(65 + i) -- uppercase A-Z for inputs
      else
         return string.char(97 + i) -- lowercase a-z for gates
      end
   end

   function formula(linput, rinput, nwires)
      local s = ''
      for w = ninputs, nwires-1 do
         if s ~= '' then s = s .. '; ' end
         s = string.format('%s%s = ~(%s %s)',
                           s, vname(w), vname(linput[w]), vname(rinput[w]))
      end
      return s
   end

   function compute(left_input, right_input)
      return bnot(band(left_input, right_input))
   end

   function find_for_n(ngates)
      local nwires = ninputs + ngates
      local linput = {}
      local rinput = {}
      local wire   = {}
      local found  = false
      for i, input in ipairs(inputs) do
         wire[i-1] = inputs[i]
      end

      function sweeping(w)
         for ll = 0, w-1 do
            local llwire = wire[ll]
            linput[w] = ll
            if w+1 == nwires then
               for rr = 0, ll do
                  local last_wire = compute(llwire, wire[rr])
                  if band(mask, last_wire) == wanted then
                     found = true
                     rinput[w] = rr
                     print(formula(linput, rinput, nwires))
                  end
               end
            else
               for rr = 0, ll do
                  wire[w] = compute(llwire, wire[rr])
                  rinput[w] = rr
                  sweeping(w + 1)
               end
            end
         end
      end

      sweeping(ninputs)
      return found
   end
   
   do
      print('Trying 0 gates...')
      assert(ninputs <= string.len('ABCDEF'))
      local names  = '01' .. string.sub('ABCDEF', 1, ninputs)
      local inputs = append({0, mask}, inputs)
      for i, input in ipairs(inputs) do
         if wanted == input then
            local name = string.sub(names, i, i)
            print(string.format('%s = %s', vname(ninputs), name))
            return true
         end
      end
   end
   for ngates = 1, max_gates do
      print(string.format('Trying %d gates...', ngates))
      assert(ninputs + ngates <= 26) -- vnames must be distinct
      if find_for_n(ngates) then return true end
   end
   return false
end

function tabulate_inputs(ninputs)
   if ninputs == 0 then
      return {}
   else
      local shift = lshift(1, ninputs-1)
      function replicate(iv)
         return iv + lshift(iv, shift)
      end
      return cons(lshift(1, shift) - 1,
                  map(replicate, tabulate_inputs(ninputs-1)))
   end
end

function cons(x, xs)
   local result = {x}
   for _, x1 in ipairs(xs) do
      result[#result+1] = x1
   end
   return result
end

function append(xs, ys)
   local result = {}
   for _, x in ipairs(xs) do result[#result+1] = x end
   for _, y in ipairs(ys) do result[#result+1] = y end
   return result
end

function map(f, xs)
   local result = {}
   for _, x in ipairs(xs) do
      result[#result+1] = f(x)
   end
   return result
end

function print_array(xs)
   print('{')
   for i, x in ipairs(xs) do
      print(' '..i..': '..x)
   end
   print('}')
end
