
local restorepath = package.path
local restorepath_cpath = package.cpath
package.path = package.path .. ";./share/lua/5.1/?.lua"
package.cpath = package.cpath .. ";./lib/lua/5.1/?.so"
http = require("socket.http")
package.path = restorepath
package.cpath = restorepath_cpath

local ltn12  = require("ltn12")
local colors = require("ansicolors")
local dkjson = require("dkjson")

local M = {}

function M.generate(context, model) -- {{{
   local response = ""
   local request_body = {
       model    = model,
       messages = context,
       stream   = false
   }
   local json_data = dkjson.encode(request_body)
   local url     = "http://localhost:11434/api/chat"
   local headers = {
       ["Content-Type"]   = "application/json",
       ["Content-Length"] = tostring(#json_data)
   }
   local r = {}
   local result, status_code, response_headers, status_text = http.request{
       url     = url,
       sink    = ltn12.sink.table(r),
       method  = "POST",
       headers = headers,
       source  = ltn12.source.string(json_data),
       timeout = 30,  -- 30 second timeout
   }
   
   if not result then
       error("HTTP request failed: " .. tostring(status_code))
   end
   
   response = table.concat(r)
   
   if response == "" then
       error("Empty response from Ollama API")
   end
   
   local decoded_response, err = dkjson.decode(response)
   
   if not decoded_response then
       error("Failed to decode JSON response: " .. (err or "unknown error") .. "\nResponse: " .. response)
   end
   
   if decoded_response.error then
       error("Ollama API error: " .. decoded_response.error)
   end
   
   if not decoded_response.message then
       error("No message in response: " .. response)
   end
   
   if not decoded_response.message.content then
       error("No content in message: " .. response)
   end
   
   print(decoded_response.message.content)

   return decoded_response
end -- }}}

return M

