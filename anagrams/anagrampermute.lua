-- For each input line, write out the permutation of its words
-- that's most likely, according to a bigram model.

function main()
   for line in io.lines() do
      local words, score = pick_best_permutation(split(line))
      print(string.format('%g %s', -log2(score), table.concat(words, ' ')))
   end
end

function pick_best_permutation(words)
   local best_score = -1
   local best_perm = nil
   local function check_permutation(perm)
      local score = bigram_score(perm)
      if best_score < score then
         best_score = score
         best_perm = perm
      end
   end
   permute(words, check_permutation)
   return best_perm, best_score
end

function bigram_score(words)
   local P = 1
   local prev = '<s>'
   for i, word in ipairs(words) do
      P = P * cPw(word, prev)
      prev = word
   end
   return P
end


-- Probability distribution
-- ported from Norvig

function load_pdist(filename)
   local pdist = {}
   local total = 0
   for line in io.lines(filename) do
      local i, j, key, count = line:find('([^\t]+)\t(%d+)')
      assert(i)
      count = 0 + count
      pdist[key:lower()] = count
      total = total + count
   end
   pdist.N = total
   function pdist:P(key)
      local count = self[key]
      if count == nil then
         return 10 / (self.N * 10^#key)
      else
         return count / self.N
      end
   end
   return pdist
end

NT = 1024908267229 + 1e10 -- Number of tokens -- contractions added
Pw = load_pdist('contractionmodel.unigram')
Pw.N = NT
Pw2 = load_pdist('contractionmodel.bigram')
Pw2.N = NT

function cPw(word, prev)
   local prev_count = Pw[prev]
   if prev_count == nil then return Pw:P(word) end
   local count = Pw2[prev..' '..word]
   if count == nil then return Pw:P(word) end
   return count / prev_count
end


-- Enumerate permutations
-- (Bad, slow first attempt)

function permute(xs, receiver)
   if #xs <= 1 then
      receiver(xs)
   else
      for i, xi in ipairs(xs) do
         local head = {xi}
         local function join(ps)
            receiver(append(head, ps))
         end
         permute(skip_at(xs, i), join)
      end
   end
end

function append(xs, ys)
   local result = {}
   array_copy(result, 1,     xs, 1, #xs)
   array_copy(result, #xs+1, ys, 1, #ys)
   return result
end

function skip_at(xs, i)
   local result = {}
   array_copy(result, 1, xs, 1, i-1)
   array_copy(result, i, xs, i+1, #xs)
   return result
end

function array_copy(dst, di, src, si, sj)
   for i = 0, sj-si+1 do dst[di+i] = src[si+i] end
end


-- Utilities

local LOG2 = math.log(2)

function log2(x)
   return math.log(x) / LOG2
end

function split(str, pat)
   return array_from_iter(isplit(str, pat))
end

function array_from_iter(iter)
   local result = {}
   for element in iter do result[#result+1] = element end
   return result
end

function isplit(str, pat)
   pat = pat or '%s+'
   local st, g = 1, str:gmatch("()("..pat..")")
   local function getter(segs, seps, sep, cap1, ...)
      st = sep and seps + #sep
      return str:sub(segs, (seps or 0) - 1), cap1 or sep, ...
   end
   return function() if st then return getter(st, g()) end end
end
