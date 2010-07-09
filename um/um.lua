-- http://www.boundvariable.org/task.shtml

local bit = require('bit')
local bnot = bit.bnot
local band = bit.band
local lshift, rshift = bit.lshift, bit.rshift

function read_program()
   local program = {}
   local f = io.open(arg[1], 'rb')
   local bytes = f:read('*all')
   f:close()

   for i = 1, string.len(bytes), 4 do
      local function c(j)
         return string.byte(bytes, i+j)
      end
      local word = ((((c(0) * 256) + c(1)) * 256 + c(2)) * 256) + c(3)
      program[math.floor((i-1)/4)] = word
   end
   
   return program
end

function as_unsigned(n)
   if n < 0 then
      return n + 0x100000000
   else
      return n
   end
end

function divide(n, d)
   local q = math.floor(as_unsigned(n) / as_unsigned(d))
   if not(0 <= q and q <= 0xFFFFFFFF) then
      return 0
   else
      return q
   end
end

function zeroes(n)
   local result = {}
   for i = 0, n-1 do
      result[i] = 0
   end
   return result
end

local mem = {}
local program = read_program()
mem[0] = program
local freelist = {}
local pc = 0
local reg = zeroes(8)

while true do
   local inst = program[pc]
   pc = pc + 1

   local opcode = rshift(inst, 28)
   if opcode == 13 then      -- ortho
      local a = band(7, rshift(inst, 25))
      local val = band(inst, 0x1FFFFFF)
      reg[a] = val

   else
      local a = band(7, rshift(inst, 6))
      local b = band(7, rshift(inst, 3))
      local c = band(7, inst)

      if opcode == 0 then       -- cmov
         if reg[c] ~= 0 then
            reg[a] = reg[b]
         end

      elseif opcode == 1 then   -- index
         reg[a] = mem[reg[b]][reg[c]]

      elseif opcode == 2 then   -- amend
         mem[reg[a]][reg[b]] = reg[c]

      elseif opcode == 3 then   -- add
         reg[a] = band(reg[b] + reg[c], 0xFFFFFFFF)

      elseif opcode == 4 then   -- mul
         reg[a] = band(reg[b] * reg[c], 0xFFFFFFFF)

      elseif opcode == 5 then   -- div
         reg[a] = divide(reg[b], reg[c])

      elseif opcode == 6 then   -- nand
         reg[a] = bnot(band(reg[b], reg[c]))

      elseif opcode == 7 then   -- halt
         os.exit(0)

      elseif opcode == 8 then   -- alloc
         local i
         if #freelist == 0 then --XXX not sure this is right
            i = #mem+1
         else
            i = freelist[#freelist]
            freelist[#freelist] = nil
         end
         mem[i] = zeroes(reg[c])
         reg[b] = i

      elseif opcode == 9 then   -- aband
         mem[reg[c]] = nil
         freelist[#freelist+1] = reg[c]

      elseif opcode == 10 then  -- output
         io.write(string.char(reg[c]))
         io.flush()
         
      elseif opcode == 11 then  -- input
         local s = io.read(1)
         if s == nil then
            reg[c] = 0xFFFFFFFF
         else
            reg[c] = string.byte(s)
         end

      elseif opcode == 12 then  -- load
         if reg[b] ~= 0 then
            local arr = mem[reg[b]]
            program = {}
            for i = 0, #arr do
               program[i] = arr[i]
            end
            mem[0] = program
         end
         pc = reg[c]

      else
         io.write('Bad opcode\n')
         os.exit(1)

      end
   end
end
