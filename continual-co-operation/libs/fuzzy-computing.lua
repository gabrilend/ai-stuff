
local restorepath = package.path
package.path = package.path .. ";libs/luasocket/share/lua/5.1/?.lua"
http = require("socket.http")
package.path = restorepath

local ltn12  = require("ltn12")
local colors = require("libs/ansicolors")
local dkjson = require("libs/dkjson")

function generate(context, model) -- {{{
   local response = ""
   local request_body = {
       model  = model,
       -- prompt = "",
       messages = context,
       stream   = false
       -- context  = context,
   }
   local json_data = dkjson.encode(request_body)
   local url     = "http://localhost:11434/api/chat"
   local headers = {
       ["Content-Type"]   = "application/json",
       ["Content-Length"] = tostring(#json_data)
   }
   local r = {}
   local _, _, response, _ = http.request{
       url     = url,
       sink    = ltn12.sink.table(r),
       method  = "POST",
       headers = headers,
       source  = ltn12.source.string(json_data),
   }
   
   response = table.concat(r)
   response = dkjson.decode(response)
  
   print(response.message.content)

   return response
end -- }}}

-- fuzzy computing!
local function fuzzy_computing() -- {{{
   local initial_prompt = {
      { role    = "system",
        content = "Hello computer, all is well." }
     }
   local model = "dolphin-llama3"

   print(output_ansi_color .. initial_prompt[1].content)
   print("\27[0m") -- reset to default color

end -- }}}

