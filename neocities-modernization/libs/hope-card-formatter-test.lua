#!/usr/bin/env luajit
-- Test suite for hope-card-formatter.lua
-- Tests the conversion of poems to words-pdf format

local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. "/libs/?.lua;" .. package.path

local formatter = require("hope-card-formatter")

-- Test counter
local tests_run = 0
local tests_passed = 0
local tests_failed = 0

-- {{{ test helper functions
local function assert_equal(actual, expected, test_name)
    tests_run = tests_run + 1
    if actual == expected then
        tests_passed = tests_passed + 1
        print(string.format("✅ PASS: %s", test_name))
        return true
    else
        tests_failed = tests_failed + 1
        print(string.format("❌ FAIL: %s", test_name))
        print(string.format("   Expected: %q", expected))
        print(string.format("   Got:      %q", actual))
        return false
    end
end

local function assert_true(condition, test_name)
    tests_run = tests_run + 1
    if condition then
        tests_passed = tests_passed + 1
        print(string.format("✅ PASS: %s", test_name))
        return true
    else
        tests_failed = tests_failed + 1
        print(string.format("❌ FAIL: %s", test_name))
        return false
    end
end

local function assert_contains(haystack, needle, test_name)
    tests_run = tests_run + 1
    if type(haystack) == "string" and haystack:find(needle, 1, true) then
        tests_passed = tests_passed + 1
        print(string.format("✅ PASS: %s", test_name))
        return true
    else
        tests_failed = tests_failed + 1
        print(string.format("❌ FAIL: %s", test_name))
        print(string.format("   Expected to find: %q", needle))
        print(string.format("   In: %q", tostring(haystack)))
        return false
    end
end
-- }}}

print("═══════════════════════════════════════════")
print("  Hope Card Formatter Test Suite")
print("═══════════════════════════════════════════")
print("")

-- Test 1: DASH_SEPARATOR constant
print("Test Group: Constants")
assert_equal(formatter.DASH_SEPARATOR, string.rep("-", 80),
    "DASH_SEPARATOR is exactly 80 dashes")
print("")

-- Test 2: wrap_line with short line
print("Test Group: Line Wrapping")
local short_line = "This is a short line"
local wrapped_short = formatter.wrap_line(short_line, 80)
assert_equal(#wrapped_short, 1, "Short line returns single element")
assert_equal(wrapped_short[1], short_line, "Short line unchanged")

-- Test 3: wrap_line with long line
local long_line = "This is a very long line that definitely exceeds eighty characters and needs to be wrapped properly at word boundaries"
local wrapped_long = formatter.wrap_line(long_line, 80)
assert_true(#wrapped_long > 1, "Long line gets wrapped into multiple lines")
for i, line in ipairs(wrapped_long) do
    assert_true(#line <= 80, string.format("Wrapped line %d is <= 80 chars", i))
end

-- Test 4: wrap_line with exact 80 characters
local exact_line = string.rep("x", 80)
local wrapped_exact = formatter.wrap_line(exact_line, 80)
assert_equal(#wrapped_exact, 1, "Exactly 80 chars stays on one line")

-- Test 5: wrap_line with 81 characters (single word)
local over_line = string.rep("x", 81)
local wrapped_over = formatter.wrap_line(over_line, 80)
assert_true(#wrapped_over >= 2, "81 char word gets hard-broken")
print("")

-- Test 6: format_poem_for_wordspdf with simple poem
print("Test Group: Poem Formatting")
local simple_poem = {
    id = 1,
    content = "Line one\nLine two\nLine three"
}
local formatted_simple = formatter.format_poem_for_wordspdf(simple_poem)
assert_contains(formatted_simple, "Line one", "Contains first line")
assert_contains(formatted_simple, "Line two", "Contains second line")
assert_contains(formatted_simple, "Line three", "Contains third line")

-- Test 7: format_poem_for_wordspdf with lines array
local array_poem = {
    id = 2,
    lines = {"First", "Second", "Third"}
}
local formatted_array = formatter.format_poem_for_wordspdf(array_poem)
assert_contains(formatted_array, "First", "Array poem contains first line")
assert_contains(formatted_array, "Second", "Array poem contains second line")

-- Test 8: format_poem_for_wordspdf with long line
local long_poem = {
    id = 3,
    content = "This is a line that definitely exceeds eighty characters in length and should be wrapped automatically"
}
local formatted_long = formatter.format_poem_for_wordspdf(long_poem)
for line in formatted_long:gmatch("[^\n]+") do
    assert_true(#line <= 80, "Long line poem wraps all lines to <= 80 chars")
end
print("")

-- Test 9: format_poems_to_string with multiple poems
print("Test Group: Multiple Poem Formatting")
local test_poems = {
    {id = 1, content = "Poem one\nFirst poem content"},
    {id = 2, content = "Poem two\nSecond poem content"},
    {id = 3, content = "Poem three\nThird poem content"}
}
local formatted_multiple = formatter.format_poems_to_string(test_poems)

assert_contains(formatted_multiple, "Poem one", "Contains first poem")
assert_contains(formatted_multiple, "Poem two", "Contains second poem")
assert_contains(formatted_multiple, "Poem three", "Contains third poem")

-- Count separator occurrences (should be 3 - one after each poem)
local separator_count = 0
for line in formatted_multiple:gmatch("[^\n]+") do
    if line == formatter.DASH_SEPARATOR then
        separator_count = separator_count + 1
    end
end
assert_equal(separator_count, 3, "Has correct number of separators (3)")
print("")

-- Test 10: format_poems_to_string with empty array
print("Test Group: Edge Cases")
local empty_formatted = formatter.format_poems_to_string({})
assert_equal(empty_formatted, "", "Empty poem array returns empty string")

-- Test 11: format_poem_for_wordspdf with nil
local nil_formatted = formatter.format_poem_for_wordspdf(nil)
assert_equal(nil_formatted, "", "Nil poem returns empty string")

-- Test 12: generate_hope_card_filename
local filename = formatter.generate_hope_card_filename(123, 200)
assert_equal(filename, "hope-card-0123-200poems.txt", "Generates correct filename")
print("")

-- Test 13: write_to_file and verify content
print("Test Group: File Operations")
local temp_file = "/tmp/hope-card-formatter-test.txt"
local test_write_poems = {
    {id = 1, content = "Test poem for file writing"},
    {id = 2, content = "Second test poem"}
}

local success, err = formatter.write_to_file(test_write_poems, temp_file)
assert_true(success, "File write succeeds")
assert_equal(err, nil, "No error message on success")

-- Verify file contents
if success then
    local file = io.open(temp_file, "r")
    if file then
        local content = file:read("*all")
        file:close()

        assert_contains(content, "Test poem for file writing", "File contains first poem")
        assert_contains(content, "Second test poem", "File contains second poem")
        assert_contains(content, formatter.DASH_SEPARATOR, "File contains separator")

        -- Clean up
        os.remove(temp_file)
    end
end
print("")

-- Test 14: write_to_file with invalid path
local fail_success, fail_err = formatter.write_to_file(test_write_poems, "/invalid/path/that/does/not/exist.txt")
assert_true(not fail_success, "Write to invalid path fails")
assert_true(fail_err ~= nil, "Error message provided on failure")
print("")

-- Summary
print("═══════════════════════════════════════════")
print(string.format("  Tests run:    %d", tests_run))
print(string.format("  Tests passed: %d", tests_passed))
print(string.format("  Tests failed: %d", tests_failed))
print("═══════════════════════════════════════════")

if tests_failed == 0 then
    print("✅ All tests passed!")
    os.exit(0)
else
    print("❌ Some tests failed")
    os.exit(1)
end
