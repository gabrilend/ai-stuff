// JASS Edge Cases Test Fixture

// Empty lines


// Multiple empty lines




// Consecutive operators without spaces
a+b-c*d/e

// Keywords as part of identifiers (should be identifiers, not keywords)
functionName
ifCondition
loopCounter
returnValue
localVariable
callbackFunction

// Very long identifier
abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789

// Identifiers starting with underscore
_private
_test_123
_

// Mixed whitespace (spaces and tabs)
	set x = 5
    set y = 10

// Operators adjacent to literals
1+2
x*5
a==b

// Nested parentheses
((a+b)*c)

// Array access
myArray[0]
myArray[i+1]

// Function calls
call MyFunc()
call MyFunc(a, b, c)
call MyFunc(1, "hello", 'hfoo')

// Complex expression
set result = (a + b) * (c - d) / e
