-- 054-riscv-words.lua
--
-- A two-pass emitter for RISC-V payloads: it lays out instructions, counts
-- bytes, and encodes every branch as a raw instruction word with the offset
-- already inside it.
--
-- For a general: on this one architecture, the assembler refuses to finish
-- branch arithmetic itself -- it leaves a note asking a linker to fill in the
-- distance, and this project deliberately has no linker, so the note is
-- dropped and a zero is left behind. A branch to a label becomes a branch to
-- nowhere, silently. The way out is to count the distance ourselves and write
-- the finished number directly into the instruction. Counting is possible
-- because compressed instructions are switched off, which makes every
-- instruction exactly four bytes.
--
-- Proven empirically before this was written: with `.option norelax` and
-- `.option norvc`, a `bnez` to a label, a `beq` to a label, and even a branch
-- to `. + 12` ALL leave R_RISCV_BRANCH relocations behind, and llvm-objdump
-- shows the instruction bytes still pointing at themselves. The note in 019
-- about "NO SYMBOL REFERENCES AT ALL" is exactly right, and this file is that
-- note turned into a tool -- issue 102 needs real control flow on this
-- architecture, and hand-counting offsets across hundreds of instructions is
-- how off-by-one machines get built.
--
-- WHAT MAY BE EMITTED THROUGH :op. Only real instructions that assemble to
-- exactly four bytes. Pseudo-instructions with data-dependent expansions (li,
-- la, lla) and label-consuming forms (j, bnez, beqz, call, tail, ret) are
-- refused loudly, because one of them slipping through breaks every offset
-- after it.

local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local M = {}

-- {{{ M.REGISTER -- name to number, for encoding branch words
M.REGISTER = {
  zero = 0, ra = 1, sp = 2, gp = 3, tp = 4,
  t0 = 5, t1 = 6, t2 = 7,
  s0 = 8, fp = 8, s1 = 9,
  a0 = 10, a1 = 11, a2 = 12, a3 = 13, a4 = 14, a5 = 15, a6 = 16, a7 = 17,
  s2 = 18, s3 = 19, s4 = 20, s5 = 21, s6 = 22, s7 = 23,
  s8 = 24, s9 = 25, s10 = 26, s11 = 27,
  t3 = 28, t4 = 29, t5 = 30, t6 = 31,
}
-- }}}

-- {{{ BRANCH_FUNCT3 -- the condition field of a conditional branch
local BRANCH_FUNCT3 = {
  beq = 0, bne = 1, blt = 4, bge = 5, bltu = 6, bgeu = 7,
}
-- }}}

-- {{{ FORBIDDEN_IN_OP -- mnemonics that must go through the emitter instead
--
-- Each of these either expands to a data-dependent number of instructions or
-- swallows a label and produces a relocation. Both break the byte counting
-- this whole tool exists to do.
local FORBIDDEN_IN_OP = {
  li = "use :load_constant, which chooses its expansion deterministically",
  la = "address something with the anchor register and a counted offset",
  lla = "address something with the anchor register and a counted offset",
  j = "use :jump, which encodes the offset itself",
  jal = "use :jump, which encodes the offset itself",
  bnez = "use :branch('bne', reg, 'zero', label)",
  beqz = "use :branch('beq', reg, 'zero', label)",
  blez = "use :branch with explicit registers",
  bgez = "use :branch with explicit registers",
  bltz = "use :branch with explicit registers",
  bgtz = "use :branch with explicit registers",
  call = "there is nothing to call; this is a payload, not a program with a runtime",
  tail = "there is nothing to call; this is a payload, not a program with a runtime",
  ret = "a payload never returns",
}
-- }}}

-- {{{ local function encode_conditional(funct3, rs1, rs2, delta)
-- The B-type layout scatters the offset across the word:
--   bit 31 <- offset bit 12      bits 30..25 <- offset bits 10..5
--   bits 11..8 <- offset bits 4..1    bit 7 <- offset bit 11
-- Offsets are measured in bytes from the branch itself and must be even.
local function encode_conditional(funct3, rs1, rs2, delta)
  local imm12 = band(rshift(delta, 12), 1)
  local imm11 = band(rshift(delta, 11), 1)
  local imm10_5 = band(rshift(delta, 5), 0x3f)
  local imm4_1 = band(rshift(delta, 1), 0xf)
  return bor(
    lshift(imm12, 31),
    lshift(imm10_5, 25),
    lshift(rs2, 20),
    lshift(rs1, 15),
    lshift(funct3, 12),
    lshift(imm4_1, 8),
    lshift(imm11, 7),
    0x63)
end
-- }}}

-- {{{ local function encode_jump(rd, delta)
-- The J-type layout, scattered differently:
--   bit 31 <- offset bit 20      bits 30..21 <- offset bits 10..1
--   bit 20 <- offset bit 11      bits 19..12 <- offset bits 19..12
local function encode_jump(rd, delta)
  local imm20 = band(rshift(delta, 20), 1)
  local imm10_1 = band(rshift(delta, 1), 0x3ff)
  local imm11 = band(rshift(delta, 11), 1)
  local imm19_12 = band(rshift(delta, 12), 0xff)
  return bor(
    lshift(imm20, 31),
    lshift(imm10_1, 21),
    lshift(imm11, 20),
    lshift(imm19_12, 12),
    lshift(rd, 7),
    0x6f)
end
-- }}}

-- {{{ M.new() -- a program being laid out
function M.new()
  local program = {
    -- each entry: { kind, bytes, ... } -- bytes decided at emit time, which
    -- is what makes the second pass a plain sum rather than a fixed point.
    entries = {},
    labels = {},
  }

  -- {{{ program:label(name)
  function program:label(name)
    if self.labels[name] then
      error("054-riscv-words: label '" .. name .. "' placed twice")
    end
    self.labels[name] = true
    self.entries[#self.entries + 1] = { kind = "label", bytes = 0, name = name }
  end
  -- }}}

  -- {{{ program:op(text)
  -- One real instruction, four bytes, passed to the assembler verbatim.
  function program:op(text)
    local mnemonic = text:match("^%s*([%w.]+)")
    if mnemonic and FORBIDDEN_IN_OP[mnemonic] then
      error("054-riscv-words: '" .. mnemonic .. "' would break the byte count -- "
            .. FORBIDDEN_IN_OP[mnemonic])
    end
    self.entries[#self.entries + 1] = { kind = "op", bytes = 4, text = text }
  end
  -- }}}

  -- {{{ program:branch(kind, rs1, rs2, label)
  function program:branch(kind, rs1, rs2, label)
    local funct3 = BRANCH_FUNCT3[kind]
      or error("054-riscv-words: no conditional branch called '" .. tostring(kind) .. "'")
    local a = M.REGISTER[rs1] or error("054-riscv-words: no register called '" .. tostring(rs1) .. "'")
    local b = M.REGISTER[rs2] or error("054-riscv-words: no register called '" .. tostring(rs2) .. "'")
    self.entries[#self.entries + 1] = {
      kind = "branch", bytes = 4,
      funct3 = funct3, rs1 = a, rs2 = b, target = label,
      spelled = kind .. " " .. rs1 .. ", " .. rs2 .. ", " .. label,
    }
  end
  -- }}}

  -- {{{ program:jump(label)
  -- An unconditional jump that links nothing: jal zero, offset.
  function program:jump(label)
    self.entries[#self.entries + 1] = {
      kind = "jump", bytes = 4, target = label,
      spelled = "j " .. label,
    }
  end
  -- }}}

  -- {{{ program:load_constant(register, value)
  -- li with its expansion chosen here, so the byte count is known the moment
  -- it is emitted. Small values are one addi; anything else is lui plus
  -- addiw, the standard 32-bit build. Values outside 32 bits are refused --
  -- nothing in a payload needs one, and a silent longer expansion would
  -- shift every offset after it.
  function program:load_constant(register, value)
    if value ~= math.floor(value) then
      error("054-riscv-words: load_constant wants a whole number, got " .. tostring(value))
    end
    if value < -2147483648 or value > 2147483647 then
      error("054-riscv-words: " .. tostring(value) .. " does not fit in 32 bits")
    end
    if value >= -2048 and value <= 2047 then
      self:op("addi " .. register .. ", zero, " .. value)
      return
    end
    -- hi rounds toward the value so lo lands in addiw's signed range.
    local hi = math.floor((value + 0x800) / 0x1000)
    local lo = value - hi * 0x1000
    -- lui takes the raw twenty-bit field; a negative hi wraps around.
    self:op("lui " .. register .. ", " .. band(hi, 0xfffff))
    if lo ~= 0 then
      self:op("addiw " .. register .. ", " .. register .. ", " .. lo)
    end
  end
  -- }}}

  -- {{{ program:address(register, label, base_register)
  -- The address of a label, as base register plus a counted offset. Three
  -- instructions ALWAYS -- lui, addiw, add -- even when the offset is small
  -- enough for fewer, because the offset is not known until the second pass
  -- and a size that depended on it would move every label it is measuring.
  function program:address(register, label, base_register)
    self.entries[#self.entries + 1] = {
      kind = "address", bytes = 12,
      register = register, target = label, base = base_register,
    }
  end
  -- }}}

  -- {{{ program:shorts(text)
  -- A string as UTF-16 halfwords with a terminator, for the firmware console.
  function program:shorts(text)
    self.entries[#self.entries + 1] = {
      kind = "shorts", bytes = (#text + 1) * 2, text = text,
    }
  end
  -- }}}

  -- {{{ program:align(to)
  function program:align(to)
    self.entries[#self.entries + 1] = { kind = "align", bytes = nil, to = to }
  end
  -- }}}

  -- {{{ program:resolve() -- assign offsets, encode branches, return assembly
  function program:resolve()
    -- first pass: where everything is. Alignment padding is the one entry
    -- whose size depends on its position, so sizes are settled here.
    local at = 0
    local offset_of = {}
    for _, entry in ipairs(self.entries) do
      if entry.kind == "align" then
        local remainder = at % entry.to
        entry.bytes = remainder == 0 and 0 or entry.to - remainder
      elseif entry.kind == "label" then
        offset_of[entry.name] = at
      end
      entry.offset = at
      at = at + entry.bytes
    end

    -- second pass: spell it out, with every branch a finished word.
    local out = {
      "  .option norvc",     -- four bytes per instruction, no exceptions
      "  .option norelax",   -- and no resizing behind the count's back
      "  .globl _start",
      "_start:",
    }
    for _, entry in ipairs(self.entries) do
      if entry.kind == "label" then
        out[#out + 1] = "# " .. entry.name .. ":"
      elseif entry.kind == "op" then
        out[#out + 1] = "  " .. entry.text
      elseif entry.kind == "branch" or entry.kind == "jump" then
        local target = offset_of[entry.target]
        if not target then
          error("054-riscv-words: branch to '" .. entry.target .. "', which is nowhere")
        end
        local delta = target - entry.offset
        local word
        if entry.kind == "branch" then
          if delta < -4096 or delta > 4094 then
            error("054-riscv-words: conditional branch to '" .. entry.target
                  .. "' is " .. delta .. " bytes away, past the +-4KB a branch reaches"
                  .. " -- branch over a jump instead")
          end
          word = encode_conditional(entry.funct3, entry.rs1, entry.rs2, delta)
        else
          if delta < -1048576 or delta > 1048574 then
            error("054-riscv-words: jump to '" .. entry.target .. "' is " .. delta
                  .. " bytes away, past the +-1MB a jump reaches")
          end
          word = encode_jump(0, delta)
        end
        -- the finished number, with what it means beside it. %08x keeps the
        -- sign bit readable; bit operations hand back signed numbers.
        out[#out + 1] = string.format("  .word 0x%08x    # %s  (%+d)",
                                      band(word, 0xffffffff) % 2^32, entry.spelled,
                                      delta)
      elseif entry.kind == "address" then
        local target = offset_of[entry.target]
        if not target then
          error("054-riscv-words: address of '" .. entry.target .. "', which is nowhere")
        end
        -- the same split load_constant uses: hi rounds toward the value so
        -- lo lands in addiw's signed range.
        local hi = math.floor((target + 0x800) / 0x1000)
        local lo = target - hi * 0x1000
        out[#out + 1] = "  lui " .. entry.register .. ", " .. band(hi, 0xfffff)
          .. "    # " .. entry.target .. " sits " .. target .. " bytes in"
        out[#out + 1] = "  addiw " .. entry.register .. ", " .. entry.register .. ", " .. lo
        out[#out + 1] = "  add " .. entry.register .. ", " .. entry.register
          .. ", " .. entry.base
      elseif entry.kind == "shorts" then
        for index = 1, #entry.text do
          out[#out + 1] = "  .short " .. entry.text:byte(index)
        end
        out[#out + 1] = "  .short 0"
      elseif entry.kind == "align" then
        if entry.bytes > 0 then
          out[#out + 1] = "  .space " .. entry.bytes
        end
      end
    end
    out[#out + 1] = ""
    return table.concat(out, "\n"), offset_of
  end
  -- }}}

  return program
end
-- }}}

return M
