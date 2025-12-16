-- MPQ Hash Functions
-- Implements MPQ's hash algorithm and crypto table for file lookup and decryption.

local hash = {}

-- {{{ Constants
-- Hash types for mpq_hash function
hash.HASH_TABLE_OFFSET = 0  -- For hash table slot lookup
hash.HASH_NAME_A = 1        -- First filename verification
hash.HASH_NAME_B = 2        -- Second filename verification
hash.HASH_FILE_KEY = 3      -- For encryption key derivation
-- }}}

-- {{{ Crypto table generation
-- The crypto table is a 1280-entry lookup table used by all MPQ crypto operations.
-- It's generated deterministically from a fixed seed.
local crypt_table = nil

-- {{{ init_crypt_table
local function init_crypt_table()
    if crypt_table then
        return crypt_table
    end

    crypt_table = {}
    local seed = 0x00100001

    for index1 = 0, 255 do
        local index2 = index1
        for _ = 0, 4 do
            seed = (seed * 125 + 3) % 0x2AAAAB
            local temp1 = (seed & 0xFFFF) << 16

            seed = (seed * 125 + 3) % 0x2AAAAB
            local temp2 = seed & 0xFFFF

            crypt_table[index2] = temp1 | temp2
            index2 = index2 + 256
        end
    end

    return crypt_table
end
-- }}}

-- {{{ get_crypt_table
function hash.get_crypt_table()
    return init_crypt_table()
end
-- }}}
-- }}}

-- {{{ Hashing
-- {{{ normalize_filename
-- MPQ filenames are case-insensitive and use backslash separators.
local function normalize_filename(filename)
    return filename:upper():gsub("/", "\\")
end
-- }}}

-- {{{ mpq_hash
-- Computes an MPQ hash of a string using the specified hash type.
-- hash_type: 0=table offset, 1=name_a, 2=name_b, 3=file_key
function hash.mpq_hash(str, hash_type)
    init_crypt_table()

    str = normalize_filename(str)

    local seed1 = 0x7FED7FED
    local seed2 = 0xEEEEEEEE

    for i = 1, #str do
        local ch = str:byte(i)
        local table_index = (hash_type * 256) + ch
        seed1 = crypt_table[table_index] ~ ((seed1 + seed2) & 0xFFFFFFFF)
        seed2 = (ch + seed1 + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF
    end

    return seed1 & 0xFFFFFFFF
end
-- }}}
-- }}}

-- {{{ Decryption
-- {{{ decrypt_block
-- Decrypts a block of data using MPQ's decryption algorithm.
-- data: raw encrypted bytes (must be multiple of 4 bytes)
-- key: 32-bit decryption key
-- Returns: decrypted data as string
function hash.decrypt_block(data, key)
    init_crypt_table()

    if #data % 4 ~= 0 then
        error("Data length must be multiple of 4 bytes")
    end

    local seed1 = key
    local seed2 = 0xEEEEEEEE
    local result = {}

    for i = 1, #data, 4 do
        -- Update seed2 with crypto table value
        seed2 = (seed2 + crypt_table[0x400 + (seed1 & 0xFF)]) & 0xFFFFFFFF

        -- Read encrypted value
        local encrypted = string.unpack("<I4", data, i)

        -- Decrypt
        local decrypted = (encrypted ~ ((seed1 + seed2) & 0xFFFFFFFF)) & 0xFFFFFFFF

        -- Update seeds for next iteration
        seed1 = (((~seed1 << 21) + 0x11111111) | (seed1 >> 11)) & 0xFFFFFFFF
        seed2 = (decrypted + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF

        result[#result + 1] = string.pack("<I4", decrypted)
    end

    return table.concat(result)
end
-- }}}

-- {{{ decrypt_table
-- Decrypts an MPQ hash or block table.
-- data: raw encrypted table bytes
-- key_string: string to hash for key (e.g., "(hash table)" or "(block table)")
function hash.decrypt_table(data, key_string)
    local key = hash.mpq_hash(key_string, hash.HASH_FILE_KEY)
    return hash.decrypt_block(data, key)
end
-- }}}
-- }}}

-- {{{ Known hash values for testing
-- These can be used to verify the hash implementation is correct.
hash.TEST_VALUES = {
    -- String, hash_type, expected_value
    { "(hash table)", hash.HASH_FILE_KEY, 0xC3AF3770 },
    { "(block table)", hash.HASH_FILE_KEY, 0xEC83B3A3 },
}
-- }}}

return hash
