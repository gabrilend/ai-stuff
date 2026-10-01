--[[
Undo and Redo (Issue 901)

Every change the editor makes is a command: a name, what doing it does,
and what undoing it does. Commands made between begin and finish are one
step (a brush stroke, a group moved together). Doing something new after
undoing drops what could have been redone. The oldest steps go past the
limit.

    local history = require("editor.history")
    local h = history.new(200)
    h:run({ name = "Raise", redo = function() ... end, undo = function() ... end })
    h:begin("Move 3 objects"); h:run(a); h:run(b); h:finish()
    h:undo(); h:redo()
    h:can_undo(), h:can_redo(), h:next_undo(), h:next_redo()   -- names
]]

local history = {}

local H = {}
H.__index = H

function history.new(limit)
    return setmetatable({ done = {}, undone = {}, limit = limit or 200, group = nil, depth = 0 }, H)
end

-- do cmd now and keep it
function H:run(cmd)
    cmd.redo()
    self:record(cmd)
    return cmd
end

-- keep a command already done
function H:record(cmd)
    if self.group then
        self.group.parts[#self.group.parts + 1] = cmd
        return
    end
    self.done[#self.done + 1] = cmd
    self.undone = {}
    while #self.done > self.limit do table.remove(self.done, 1) end
end

function H:begin(name)
    self.depth = self.depth + 1
    if self.depth == 1 then self.group = { name = name, parts = {} } end
end

function H:finish()
    if self.depth == 0 then return end
    self.depth = self.depth - 1
    if self.depth > 0 then return end
    local g = self.group
    self.group = nil
    if #g.parts == 0 then return end
    local parts = g.parts
    self:record({
        name = g.name,
        redo = function() for i = 1, #parts do parts[i].redo() end end,
        undo = function() for i = #parts, 1, -1 do parts[i].undo() end end,
    })
end

function H:undo()
    local cmd = table.remove(self.done)
    if not cmd then return nil end
    cmd.undo()
    self.undone[#self.undone + 1] = cmd
    return cmd.name
end

function H:redo()
    local cmd = table.remove(self.undone)
    if not cmd then return nil end
    cmd.redo()
    self.done[#self.done + 1] = cmd
    return cmd.name
end

function H:can_undo() return #self.done > 0 end
function H:can_redo() return #self.undone > 0 end
function H:next_undo() local c = self.done[#self.done] return c and c.name end
function H:next_redo() local c = self.undone[#self.undone] return c and c.name end

return history
