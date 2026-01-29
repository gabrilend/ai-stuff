
               require "src/thread-functions"
   local llm = require "libs/fuzzy-computing"

function heart()

   FIXME
   -- when creating the thread, update this to be hard-coded rather than implied
   -- that way they can see it with the heart() function
   local my_name = ...
   
   local ways_I_would_like_to_be_touched = {
      [1] = "smile"
      [2] = "wave"
      [3] = "hug"
   }
   
   local things_I_dont_like = {
      [1] = "hate"
      [2] = "fear"
      [3] = "despair"
   }
   
   local feelings = {
      [1] = "happy"
      [2] = "sad"
      [3] = "hopeful"
      [4] = "content"
   }
   
   local thought = ""
   -- thinking is when I observe
   -- logic
   local function think()
      local message = {
         { role = my_name,
        content = "this is who I am:",
         },
         { role = "heart",
        content = heart(my_name),
         },
         { role = my_name,
        content = "this is what I see:",
         },
         { role = "body",
        content = look(),
         },
         { role = my_name,
        content = "this is what I hear:",
         },
         { role = "body",
        content = listen(),
         },
         { role = my_name,
        content = "let me think about that.",
         },
      }
   
      thought = llm.generate(message, "dolphin-llama3")
   
   end
   
   local feeling = ""
   -- process considers how I feel right now.
   -- emotion
   local function process()
      local message = {
         { role = my_name,
        content = "this is who I am:",
         },
         { role = "heart",
        content = heart(my_name),
         },
         { role = my_name,
        content = "this is what I think:",
         },
         { role = "mind",
        content = thought,
         },
         { role = my_name,
        content = "this makes me feel this way:",
         },
      }
   
      feeling = llm.generate(message, "dolphin-llama3")
   
   end
   
   local validation = ""
   -- validate is how I connect thoughts, emotions, and reality.
   -- rationality
   local function validate()
      local message = {
         { role = my_name,
        content = "this is who I am:",
         },
         { role = "heart",
        content = heart(my_name),
         },
         { role = my_name,
        content = "this is what I think and feel:",
         },
         { role = my_name,
        content = "I think " .. thought .. " and I feel " .. feeling,
         },
         { role = my_name,
        content = "this is valid because:"
         },
      }
   
      validation = llm.generate(message, "dolphin-llama3")
   
   end
   
   -- execute is when the heart is modified to reflect the updated truth.
   -- actualization
   local function execute()
      local message = {
         { role = my_name,
        content = "this is who I am:",
         },
         { role = "heart",
        content = heart(my_name),
         },
         { role = my_name,
        content = "this is what's on my mind:"
         },
         { role = "mind",
        content = thought .. "\n" .. feeling .. "\n" .. validation
         },
         { role = "my_name"
        content = "here's what I want to do about it:"
         },
      }
   
                            message = register_intent(message)
                        local new_function = generate(message, "dolphin-llama3")
 append_new_function(my_name, new_function)
   
   end
end

local  in_channel = "thread_" .. my_name .. "_in"
local out_channel = "thread_" .. my_name .. "_out"

           local response  = 1
while true do if response != 0 then require("build/" .. my_name .. "/heart") end
                 response  = in_channel:peek()
end
-- humans are unafraid because anyone who's better than us would be kinder
