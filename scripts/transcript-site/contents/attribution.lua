-- attribution.lua
-- Copyright (C) 2026 gabrilend. SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Decides which conversation made each commit, by evidence, and folds the
-- commits into the groups the table of contents draws.
--
-- Part of the table of contents (contents/). It reads no transcript itself:
-- the builder hands it the evidence, gathered from the conversations, as
-- plain tables.
--
-- BY EVIDENCE, NEVER BY POSITION. An earlier rule gave a run of commits to the
-- conversation whose transcript the run's last commit touched. That clumped
-- commits by "everything since a transcript was last saved", which a reader
-- cannot see; it hung one project's first 220 commits off a one-turn
-- transcript because the first commit to touch any transcript was a bulk
-- import; and it broke when the archive was re-dated and old names pointed
-- nowhere. Evidence is what a conversation itself wrote down.
--
-- THE RULES, tried in the order a project lists them (issue 035b):
--
--   recorded  a transcript holds a "*[commit] <hash>..." line for the
--             commit's source. The exporter writes that line at the moment
--             the commit was made, so it is the exact place, and the commit
--             lands on it.
--   subject   history was rewritten and the hash moved, but exactly one
--             transcript records a commit with the same subject. Lands on
--             that line.
--   saved     the commit touched exactly one main conversation's transcript,
--             a helper's counting as its parent's. The commit routine saves
--             the committing conversation's transcript with its work, so
--             this is evidence, but it names no line: the commit lands on
--             the page's top.
--
-- double-diaper-dungeon lists only "recorded"; every other project, all three.

local M = {}

-- {{{ local function by_recorded()
-- The commit's source, matched against the commit lines the transcripts
-- hold. A recorded hash can be seven characters or nine, depending on the
-- day it was written, so the table is keyed by the first seven and the rest
-- of the recorded hash is checked against the source.
local function by_recorded(commit, evidence)
  local found = evidence.by_hash[commit.source:sub(1, 7)]
  if found and commit.source:sub(1, #found.hash) == found.hash then
    return found.key, found.anchor
  end
  return nil
end
-- }}}

-- {{{ local function by_subject()
-- The commit's subject, when exactly one recorded commit line carries it.
-- Two transcripts recording the same subject is no evidence for either.
local function by_subject(commit, evidence)
  local same = evidence.by_subject[commit.subject]
  if same and #same == 1 then
    return same[1].key, same[1].anchor
  end
  return nil
end
-- }}}

-- {{{ local function by_saved()
-- The one main conversation whose transcript the commit touched. A helper's
-- transcript stands for its parent's. Touching none, or several (a bulk
-- import, an archive rebuild), is no evidence.
local function by_saved(commit, evidence)
  local mains, count, only = {}, 0, nil
  for _, path in ipairs(commit.transcripts) do
    local owner = evidence.parent_of[path] or path
    if evidence.is_main[owner] and not mains[owner] then
      mains[owner] = true
      count = count + 1
      only = owner
    end
  end
  if count == 1 then
    return only, nil
  end
  return nil
end
-- }}}

-- The rules by name, so a project's list is a list of names and a new rule is
-- one more row.
local RULES = {
  recorded = by_recorded,
  subject = by_subject,
  saved = by_saved,
}

M.DEFAULT_RULES = { "recorded", "subject", "saved" }

-- {{{ function M.check_rules()
-- Refuses a rule name this file does not know, before anything is read. A
-- misspelt rule would otherwise be skipped and the page would quietly link
-- fewer commits.
function M.check_rules(rules)
  for _, name in ipairs(rules) do
    if not RULES[name] then
      error("no attribution rule called " .. tostring(name))
    end
  end
end
-- }}}

-- {{{ function M.attribute()
-- Sets, on each commit:
--
--   conversation  string, the transcript key that made it, or nil
--   anchor        string, the id of the line it lands on, or nil (the
--                 page's top, or no page)
--   how           string, the name of the rule that decided, or nil
--
-- `evidence` is built by the builder:
--
--   by_hash     seven hex digits (string) -> { key, anchor, hash }
--               (the first transcript in name order, when several record it)
--   by_subject  subject (string) -> list of { key, anchor }
--   parent_of   helper transcript path (string) -> its parent's
--   is_main     transcript path (string) -> true for a main conversation
--
-- `rules` is a list of rule names (strings), tried in order.
function M.attribute(commits, evidence, rules)
  M.check_rules(rules)
  for _, commit in ipairs(commits) do
    commit.conversation, commit.anchor, commit.how = nil, nil, nil
    for _, name in ipairs(rules) do
      local key, anchor = RULES[name](commit, evidence)
      if key then
        commit.conversation, commit.anchor, commit.how = key, anchor, name
        break
      end
    end
  end
end
-- }}}

-- {{{ function M.group()
-- Folds the attributed commits into the groups the page draws: a stretch of
-- consecutive commits from the same conversation (or with none) is one group,
-- { conversation = <key or nil>, commits = <list> }.
--
-- Consecutive, not all-of-one-conversation-together, because the page is the
-- order things happened in. When two sessions ran side by side their commits
-- interleave, and the page shows that as the conversations taking turns
-- rather than pretending one finished before the other began.
function M.group(commits)
  local groups = {}
  local current = nil
  for _, commit in ipairs(commits) do
    if not current or current.conversation ~= commit.conversation then
      current = { conversation = commit.conversation, commits = {} }
      groups[#groups + 1] = current
    end
    current.commits[#current.commits + 1] = commit
  end
  return groups
end
-- }}}

return M
