-- 010-the-frame-cap.lua - holding the framerate to the player's chosen cap.
--
-- In plain terms: the player picks a maximum framerate, any whole number from
-- 0 to 240 (0 means no cap). After drawing each frame, the program waits until
-- that frame's time slot is over, so frames come out at exactly that rate.
-- Everything that moves is scaled by the real time between steps, so the game
-- runs at the same speed whatever the cap.
--
-- Waiting is done in two parts, because the operating system's sleep is only
-- accurate to about a millisecond: sleep until shortly before the deadline,
-- then check the clock in a tight loop for the last moment. Deadlines are
-- kept on an absolute schedule (each one a fixed slot after the last), so
-- small errors do not add up — unless a frame overran a whole slot, in which
-- case the schedule restarts from now rather than rushing to catch up.

local M = {}

M.LOWEST = 0
M.HIGHEST = 240

-- How long before the deadline to stop sleeping and start watching the clock.
M.SPIN_SECONDS = 0.002

-- {{{ function M.frame_budget()
-- Seconds per frame for a cap, or nil for "no cap" (0).
function M.frame_budget(cap)
    -- 0: no cap, no waiting
    if cap == 0 then
        return nil
    end
    return 1 / cap
end
-- }}}

-- {{{ function M.clamp_cap()
-- Keeps a cap a whole number within 0..240.
function M.clamp_cap(cap)
    cap = math.floor(cap + 0.5)
    -- below the range: the lowest
    if cap < M.LOWEST then
        return M.LOWEST
    end
    -- above the range: the highest
    if cap > M.HIGHEST then
        return M.HIGHEST
    end
    return cap
end
-- }}}

-- {{{ function M.next_deadline()
-- Given the last deadline, the budget, and the time now, the next deadline.
function M.next_deadline(last_deadline, budget, now)
    local deadline = last_deadline + budget
    -- fell more than a whole slot behind (a long frame, or the cap was just
    -- raised): restart the schedule from now instead of racing to catch up
    if deadline < now - budget then
        return now + budget
    end
    return deadline
end
-- }}}

-- {{{ function M.wait_until()
-- Waits until `deadline` (seconds on the given clock). `get_time` and
-- `sleep` are passed in (LÖVE's timer in the game) so this can be tested.
function M.wait_until(deadline, get_time, sleep)
    local remaining = deadline - get_time()
    -- far enough away to sleep for most of it
    if remaining > M.SPIN_SECONDS then
        sleep(remaining - M.SPIN_SECONDS)
    end
    -- the last moment: watch the clock
    while get_time() < deadline do
    end
end
-- }}}

return M
