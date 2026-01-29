print("Running current buffer...")

-- Example function that writes new code to the next buffer
function write_next_buffer()
    local f = io.open("build/main.lua", "w")
    file = f:read("*a")
    f:write([[
print("Running updated buffer...")

function new_feature()
    print("This is a new feature added by the previous run.")
end

new_feature()
    ]])
    f:close()

    print("Wrote next buffer. Restart to load new code.")
end

    write_next_buffer()
