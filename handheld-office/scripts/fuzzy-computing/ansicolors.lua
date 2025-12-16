local M = {}

function M.get_random_color(previous_color)
   local colors = {
       "\27[31m", -- red
       "\27[32m", -- green
       "\27[33m", -- yellow
       "\27[34m", -- blue
       "\27[35m", -- magenta
       "\27[36m", -- cyan
   }
   
   local next_color = previous_color
   while next_color == previous_color do
       next_color = colors[math.random(#colors)]
   end
   
   return next_color
end

return M
