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

   function formula(gates_l, gates_r)
      local s = ''
      for i = ninputs, #gates_l do
         if s ~= '' then s = s + '; ' end
         s = s + string.format('%s = ~(%s %s)', vname(i), vname(L), vname(R))
      end
      return s
   end

   function compute(left_input, right_input)
      return bnot(band(left_input, right_input))
   end

   function find_for_n(ngates)
      return false
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
   for _, x in ipairs(xs) do
      print(x)
   end
end
