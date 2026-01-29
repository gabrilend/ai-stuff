function main()
   local function run_file(file)
       local f = assert(loadfile(file))
       return f()
   end
   
-- if you want to change the main() file, you need to create a child. It can't
-- be reloaded while the system is running. sadface.

VAR           = {}
THREADS       = { count = 1, running = {}, silent = {} }
THREADS.count = love.system.getProcessorCount()
        DIR = "/home/ritz/programming/raleigh2"
  BUILD_DIR = DIR .. "/build"

  os.execute("touch "  .. BUILD_DIR)
  os.execute("rm -dr " .. BUILD_DIR)
  os.execute("mkdir "  .. BUILD_DIR)

for i = 1, THREADS.count do
   os.execute("mkdir " .. BUILD_DIR .. "/" .. i)
   os.execute("cp "   ..   DIR .. "/src/heart.lua"
              " " .. BUILD_DIR .. "/" .. i
             )
end

   local THREADS.channels    = {}; for i = 1, THREADS.count do
         THREADS.channels[i] = {
                         out = love.thread.newChannel("thread_" .. i .. "_out"),
                          in = love.thread.newChannel("thread_" .. i .. "_in")
                               }   end

local thread_code = [[

local data = require("data")
local          id = ...
local  in_channel = "thread_" ..  id .. "_in"
local out_channel = "thread_" ..  id .. "_out"

local task   = 0
local args   = {}
local result = {}
while true do
   task = in_channel:demand()
   for i = 1, data.FUNCTIONS[task].arg_count do
      args[i] = in_channel:demand()
   end
   result = data.FUNCTIONS[task].run(args, in_channel, out_channel)
   out_channel:push(result)
end
                    ]]

   for i = 1, numThreads do
      local thread = love.thread.newThread(thread_code)
            thread:start(i)
   end

   
                             local next_file = io.open("build/main.lua", "rw")
                                if next_file then
                   local content = next_file:read("*a")
                                   next_file:close()
   
local current_file = --[[ ----------------> ]] io.open("build/main.lua", "w")
      current_file:write(content)
      current_file:close()
   
       print("[Buffer updated] Next buffer promoted to current.")
   else
       print("[No update] buffer_next.lua not found.")
   end

end

function love.keyreleased(key)
   local commands = {
              ["q"] = function() love.event.quit() end,
          ["space"] = function() main() end,
                    }
        (commands[key] or function() print("no function") end)()
end

main()

