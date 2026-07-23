-- {{{ neocities-sync.lua
-- The brains of the chunked, adaptive Neocities deploy: what to change, and how
-- big a bite to take. Pure logic with NO network and NO IO of its own -- the
-- actual HTTP calls and the clock are injected -- so the fiddly parts (the diff,
-- the batching, and the size-adaptation control loop) are unit-testable offline
-- against a mock API. The thin curl layer that really talks to neocities.org
-- lives in scripts/neocities-sync; this file decides what that layer is told.
--
-- General description (for a CEO): the old deploy tried to delete a whole folder
-- and upload thousands of files in single requests; the server timed out and the
-- run died. This module instead computes the SMALLEST set of changes (only files
-- that are stale or differ), groups them into right-sized batches, and -- like a
-- driver feeling for a speed limit -- speeds up while requests succeed and backs
-- off hard the moment the server pushes back, settling at a rate that holds.
--
-- Why this shape (lessons paid for): a single giant request times out (HTML error
-- page, not JSON); deleting a directory makes the server do unbounded work; and
-- treating "too big" and "too many requests" the same makes rate-limiting worse
-- (smaller batches => MORE requests). So the control loop distinguishes them.
-- }}}

local M = {}

-- {{{ function M.diff_delete(remote_paths, local_set)
-- Stale remote files = present on the live site but NOT in the local build. These
-- are all that a mirror needs to remove -- usually a handful, never the whole
-- tree -- so we never ask the server to delete a directory. Directories are
-- skipped (neocities prunes empty ones; deleting a dir path is the very thing
-- that timed out). remote_paths: array of { path=, is_directory= }. local_set:
-- set { [path]=true } of files the build produced. Returns an array of paths.
function M.diff_delete(remote_paths, local_set)
    local stale = {}
    for _, entry in ipairs(remote_paths) do
        if not entry.is_directory and not local_set[entry.path] then
            stale[#stale + 1] = entry.path
        end
    end
    table.sort(stale)
    return stale
end
-- }}}

-- {{{ function M.diff_upload(local_items, remote_by_path)
-- Files that need uploading = those whose content hash differs from the live copy
-- (or that the live site lacks). This is what makes a re-run resumable and cheap:
-- a second pass after a failure re-uploads only what did not land. local_items:
-- array of { remote=, abspath=, bytes=, sha1= }. remote_by_path: { [remote]=sha1 }.
-- Returns the subset of local_items still needing upload (largest first, so a too-
-- big batch is discovered early when the control loop is still calibrating).
function M.diff_upload(local_items, remote_by_path)
    local need = {}
    for _, item in ipairs(local_items) do
        if remote_by_path[item.remote] ~= item.sha1 then
            need[#need + 1] = item
        end
    end
    table.sort(need, function(a, b) return (a.bytes or 0) > (b.bytes or 0) end)
    return need
end
-- }}}

-- {{{ function M.take_batch(items, start, budget, max_count)
-- Greedily take items[start..] into one batch bounded by BOTH a cost budget and a
-- count cap. cost is item.cost (bytes for uploads; 1 for deletes -- so deletes are
-- count-limited and uploads are byte-limited, the constraint each operation
-- actually has). Always takes at least one item, even if it alone exceeds the
-- budget, so a single oversized file can still be attempted (and fail loudly)
-- rather than wedging the loop. Returns (batch_array, next_start).
function M.take_batch(items, start, budget, max_count)
    local batch = {}
    local sum = 0
    local i = start
    while i <= #items do
        local cost = items[i].cost or 1
        -- stop if adding this item would exceed a budget we have already filled
        if #batch > 0 and (sum + cost > budget or #batch >= max_count) then
            break
        end
        batch[#batch + 1] = items[i]
        sum = sum + cost
        i = i + 1
        if #batch >= max_count then break end
    end
    return batch, i
end
-- }}}

-- {{{ classify(status)
-- Map an HTTP status to the control loop's reaction. Kept in one table so the
-- policy is readable and testable in isolation:
--   ok        -> success; consider speeding up
--   throttle  -> 429 (rate limited): WAIT, do not shrink (shrinking => more
--                requests => worse). Honor Retry-After.
--   too_big   -> 413 / 5xx / a non-JSON body on a 200: the request was too large
--                or the server-side op timed out -> halve the batch and retry.
--   fatal     -> 400/401/403/404 and friends: a real error (auth, bad request);
--                stop, because retrying or resizing cannot fix it.
local function classify(status, ok_body)
    if status == 200 and ok_body then return "ok" end
    if status == 429 then return "throttle" end
    if status == 408 or status == 413 or status == 0   -- 0 = curl transport error
       or (status >= 500 and status <= 599)
       or (status == 200 and not ok_body) then         -- 200 but HTML/garbage body
        return "too_big"
    end
    return "fatal"
end
M._classify = classify
-- }}}

-- {{{ function M.run_adaptive(items, op, opts)
-- The AIMD control loop. Walks `items` front-to-back, forming a batch sized to the
-- current budget, handing it to op(batch) -> { status=, ok_body=, retry_after= },
-- and adjusting:
--   too_big  -> budget = max(floor, budget/2); retry the SAME items smaller.
--   throttle -> sleep(retry_after or growing backoff); retry; nudge the inter-
--               request delay up so we stop tripping it; budget unchanged.
--   ok       -> advance; after `grow_after` consecutive oks, budget *= grow (a
--               gentle additive-ish increase, capped) -- AIMD: ease up, slam down.
--   fatal    -> stop and report.
-- opts (all optional): budget, max_count, floor, grow, grow_after, max_budget,
-- base_delay, max_retries, sleep(fn), log(fn). Returns a stats table including the
-- converged budget so the caller can persist it for next time.
function M.run_adaptive(items, op, opts)
    opts = opts or {}
    local budget      = opts.budget      or 8 * 1024 * 1024   -- 8 MB / batch to start
    local max_count   = opts.max_count   or 200               -- and never > 200 files
    local floor       = opts.floor       or 1
    local grow        = opts.grow        or 1.5
    local grow_after  = opts.grow_after  or 3
    local max_budget  = opts.max_budget  or 64 * 1024 * 1024
    local base_delay  = opts.base_delay  or 0                 -- politeness between calls
    local max_retries = opts.max_retries or 8
    local sleep        = opts.sleep        or function() end
    local log          = opts.log          or function() end
    local on_batch_ok  = opts.on_batch_ok  or function() end  -- called(batch) after each accepted batch

    local stats = { requests = 0, ok = 0, throttled = 0, shrinks = 0, grows = 0,
                    done = 0, total = #items }
    local i = 1
    local streak = 0
    local delay = base_delay

    while i <= #items do
        local batch, nexti = M.take_batch(items, i, budget, max_count)
        local result, kind
        local attempt = 0
        repeat
            attempt = attempt + 1
            stats.requests = stats.requests + 1
            result = op(batch) or { status = 0 }
            kind = classify(result.status, result.ok_body)

            if kind == "throttle" then
                stats.throttled = stats.throttled + 1
                local wait = result.retry_after or math.min(60, 2 ^ attempt)
                delay = math.max(delay, 1)            -- become permanently politer
                log(string.format("throttled (429); waiting %ss [batch=%d]", wait, #batch))
                sleep(wait)
            elseif kind == "too_big" then
                stats.shrinks = stats.shrinks + 1
                streak = 0
                if #batch <= floor then
                    -- already at the smallest unit and still failing: not a size
                    -- problem we can chunk our way out of -- surface it.
                    return nil, string.format(
                        "request failed at minimum batch size (status %s) on %s",
                        tostring(result.status), tostring(batch[1] and (batch[1].remote
                        or batch[1]) or "?")), stats
                end
                budget = math.max(floor, math.floor(budget / 2))
                log(string.format("too big (status %s); halving budget -> %d",
                    tostring(result.status), budget))
                batch, nexti = M.take_batch(items, i, budget, max_count)  -- re-form smaller
            end
        until kind == "ok" or kind == "fatal" or attempt >= max_retries

        if kind == "fatal" then
            return nil, string.format("fatal API error (status %s)", tostring(result.status)), stats
        end
        if kind ~= "ok" then
            return nil, string.format("gave up after %d attempts (status %s)",
                attempt, tostring(result.status)), stats
        end

        -- success: advance past the batch
        stats.ok = stats.ok + 1
        stats.done = stats.done + #batch
        on_batch_ok(batch)          -- let callers update per-item progress displays
        i = nexti
        streak = streak + 1
        if streak >= grow_after and budget < max_budget then
            budget = math.min(max_budget, math.floor(budget * grow))
            stats.grows = stats.grows + 1
            streak = 0
            log(string.format("steady; raising budget -> %d", budget))
        end
        if delay > 0 then sleep(delay) end
    end

    stats.final_budget = budget
    return stats
end
-- }}}

return M
