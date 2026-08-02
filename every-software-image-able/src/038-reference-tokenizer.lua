-- 038-reference-tokenizer.lua
--
-- Turning text into the numbers a model works in, and back. Written plainly on
-- the host, for the same reason the arithmetic was (035): so that the assembly
-- version has something to be judged by.
--
-- For a general: a model never sees letters. It works entirely in numbers, and
-- something has to agree with it about which number means which piece of text.
-- That agreement is a table published beside the model, and this is the code
-- that uses it.
--
-- WHY IT IS NOT DERIVABLE. The weights contain a row per token saying what
-- that token MEANS, and nothing anywhere saying which string it IS. The two
-- are different facts and only one of them is in the model. So the table
-- travels with the weights (issue 101) and this walks it.
--
-- WHY IT MATTERS MORE THAN IT LOOKS. A subtly wrong tokenizer does not fail.
-- It produces a model that seems mildly stupid -- slightly worse at everything,
-- for no visible reason -- and nobody suspects the right thing for weeks. The
-- awkward cases are where implementations differ from one another, which is
-- why the test beside this one is mostly awkward cases.

local M = {}

-- {{{ M.load(tokens, merges)
-- Builds the lookups. Encoding needs to find a pair's rank quickly and
-- decoding needs to find a token's text quickly, and those are different
-- questions, so they get different tables.
function M.load(tokens, merges)
  local by_number = {}
  local by_text = {}
  for index, text in ipairs(tokens) do
    local number = index - 1
    by_number[number] = text
    -- first wins: if a vocabulary somehow lists the same text twice, the
    -- lower number is the one a model was trained with.
    if by_text[text] == nil then by_text[text] = number end
  end

  -- rank IS position in the merge table -- the earlier a rule appears, the
  -- more strongly it applies. Stored as one key per pair so a lookup is one
  -- step rather than a search.
  local rank = {}
  for index, pair in ipairs(merges) do
    rank[pair[1] .. "," .. pair[2]] = index
  end

  return { by_number = by_number, by_text = by_text, rank = rank,
           count = #tokens, merge_count = #merges }
end
-- }}}

-- {{{ M.encode(vocabulary, text)
-- Text in, token numbers out.
--
-- Start from the smallest pieces the vocabulary knows -- single bytes -- then
-- repeatedly join whichever adjacent pair has the strongest rule, until no
-- rule applies to anything left. The order is what matters: joining a weaker
-- pair first can make a stronger one impossible, and the result would differ
-- from what the model was trained on.
function M.encode(vocabulary, text)
  local pieces = {}

  -- Every byte must be representable on its own or there is text this
  -- vocabulary cannot say. Refusing is right: silently dropping a byte
  -- produces a model that misreads a document rather than one that complains.
  for index = 1, #text do
    local byte = text:sub(index, index)
    local number = vocabulary.by_text[byte]
    if number == nil then
      return nil, "no token for the byte " .. string.byte(byte)
        .. " at position " .. index
    end
    pieces[#pieces + 1] = number
  end

  while #pieces > 1 do
    -- find the strongest rule that applies anywhere in what is left
    local best_rank, best_at = nil, nil
    for at = 1, #pieces - 1 do
      local found = vocabulary.rank[pieces[at] .. "," .. pieces[at + 1]]
      if found and (best_rank == nil or found < best_rank) then
        best_rank, best_at = found, at
      end
    end
    if best_at == nil then break end

    -- the joined pair must itself be a token, or the rule describes something
    -- the vocabulary cannot hold.
    local joined = vocabulary.by_number[pieces[best_at]]
      .. vocabulary.by_number[pieces[best_at + 1]]
    local number = vocabulary.by_text[joined]
    if number == nil then
      return nil, "a merge rule makes '" .. joined .. "', which is not in the vocabulary"
    end

    pieces[best_at] = number
    table.remove(pieces, best_at + 1)
  end

  return pieces
end
-- }}}

-- {{{ M.decode(vocabulary, numbers)
-- Token numbers in, text out. A lookup and a concatenation, and much easier
-- than the other direction -- which is why it is built first: a machine that
-- can print what it just thought is a machine somebody can watch.
function M.decode(vocabulary, numbers)
  local parts = {}
  for index, number in ipairs(numbers) do
    local text = vocabulary.by_number[number]
    if text == nil then
      return nil, "no token numbered " .. number .. " (position " .. index .. ")"
    end
    parts[#parts + 1] = text
  end
  return table.concat(parts)
end
-- }}}

-- {{{ M.byte_vocabulary(extra)
-- A vocabulary that can say anything: one token per possible byte, then
-- whatever longer pieces are wanted on top.
--
-- Real vocabularies are built this way too -- every byte first, so no document
-- is unsayable, then the common sequences learned from a corpus.
function M.byte_vocabulary(extra)
  local tokens, merges = {}, {}
  for byte = 0, 255 do tokens[#tokens + 1] = string.char(byte) end

  for _, piece in ipairs(extra or {}) do
    tokens[#tokens + 1] = piece
  end

  -- a rule for each longer piece, joining its first byte to the rest. Enough
  -- to exercise merging without pretending to be a trained vocabulary.
  local number_of = {}
  for index, text in ipairs(tokens) do
    if number_of[text] == nil then number_of[text] = index - 1 end
  end
  for _, piece in ipairs(extra or {}) do
    if #piece >= 2 then
      local head, tail = piece:sub(1, 1), piece:sub(2)
      if number_of[head] and number_of[tail] then
        merges[#merges + 1] = { number_of[head], number_of[tail] }
      end
    end
  end

  return tokens, merges
end
-- }}}

return M
