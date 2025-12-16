
local restorepath = package.path
package.path = package.path .. ";libs/luasocket/share/lua/5.1/?.lua"
http = require("socket.http")
package.path = restorepath

local M = {}
local ltn12  = require("ltn12")
local dkjson = require("libs/dkjson")


function M.generate(context, model) -- {{{
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
  
   return response.message.content
end -- }}}

return M
