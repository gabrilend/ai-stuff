
VAR = {}

-- get each thread's src file
function  heart(name)
   local          heart_file = io.open("build/" .. name .. "/heart.lua", "r")
   local  heart = heart_file:read("*a")
                  heart_file:close()
   return heart
end

-- the main thread, which does not change, continuously reads all the channels
-- and saves the values to build/data.lua. This will contain a table of the
-- various data values, but also their relative distance from the typical value.
function look()
   local         data_file = io.open("build/data.lua", "r")
   local  data = data_file:read("*a")
                 data_file:close()
   return data
end

-- listening is when the main thread sends a message to the computer. It is a
-- string and it is usually something only it should know.
function listen(name)
   local  message = love.thread.getChannel(name):pop()
   if not message then message = "nothing. It's pretty quiet." end
   return message
end

function append_new_function(name, new_function)
   local heart_file = io.open("build/" .. name .. "/heart.lua", "a")
         heart_file:write(new_function)
         heart_file:close()
end

function set(name, value)
   if not VAR[name] then VAR[name] = love.thread.getChannel(name) end
   VAR[name]:performAtomic(function() 
                              VAR[name]:clear(); VAR[name]:push(value)
                           end )
end

-- this function takes a table as the type, and a name as the thing that is
-- to be added or removed from the table.
function mature( type,  name )
   local i = 1
     for i, value    in     ipairs(type) do
         if value  ==   name  then type[i] = nil end return
     end
          type[i + 1] = name
end

function get(name)
   return VAR[name]:peek()
end

function add(name, value)
   VAR[name]:performAtomic(function()
                              set(name, VAR[name]:pop() + value)
                           end )
end

function sub(name, value)
   VAR[name]:performAtomic(function()
                              set(name, VAR[name]:pop() - value)
                           end )
end

function mul(name, value)
   VAR[name]:performAtomic(function()
                              set(name, VAR[name]:pop() * value)
                           end )
end

function div(name, value)
   VAR[name]:performAtomic(function()
                              set(name, VAR[name]:pop() / value)
                           end )
end

function register_intent(messages)
   local system = { -- {{{
      { role = "system"
     content = "please output a single one of these functions. It will be appended to your heart, and it will modify your mental state. Please do not give any other response but your desired function."
      },
      { role = "system"
     content = "set(name, value) -> this function will set a variable inside of your core to a specific value. If the variable does not exist, it will create a new variable inside of your core. Please give it a name and a value."
      },
      { role = "system"
     content = "add(name, value), sub(name, value), mul(name, value), and div(name, value) will allow you to use one of the basic arithmatic functions on a variable."
      },
      { role = "system"
     content = 'mature(type, name) -> this function will take a type of preference in your heart and add or remove an entry. An example of this would be deciding that you no longer like being hugged, and would be called like this: mature(ways_I_would_like_to_be_touched, "hugs"). If you want to add a new entry, you may call it the same way. For example, if you would like to like to be brushed, you may call the function like this: mature(ways_I_would_like_to_be_touched, "brushed")'
      { role = "system"
     content = "this is an example of a good response:"
      },
      { role = "assistant"
     content = 'set("tranquility", 15)'
      },
      { role = "system"
     content = "this is an example of a good response because the function is alone, on a single line, the name is quoted, and the value is an integer with a reasonable baseline value."
      },
      { role = "system"
     content = "this is an example of a poor response:"
      },
      { role = "assistant"
     content = "I have been feeling at peace lately, and so I'd like to add a tranquility variable. Here's how I'd do it: var(tranquility, 15)"
      },
      { role = "system"
     content = "this is an example of a poor response because there is additional contextual information that, while true, is not suited for this response. In addition, this is an example of a poor response because the variable name is not quoted correctly."
      },
      { role = "system"
     content = "this is another example of a poor response:"
      },
      { role = "assistant"
     content = "local diligence = 75"
      },
      { role = "system"
     content = 'this is an example of a poor response because the variables are not stored in your heart, but rather in your memory banks. By setting the variable in your heart, it will be unable to be utilized in the future. To correctly set a variable named diligence to 75, please use: set("diligence", 75)'
      },
      { role = "system"
     content = "please supply your good example function now. this will alter your mind a little bit, but you can control exactly how. you must choose something, for all life is continuously in motion. stagnation is decay."
      },
   }
   -- }}}
   
   local new_message = {}

   for i = 1, #messages do new_message[i] --[[ --> ]] = messages[i] end
   for i = 1, #system   do new_message[#messages + i] =   system[i] end
end

