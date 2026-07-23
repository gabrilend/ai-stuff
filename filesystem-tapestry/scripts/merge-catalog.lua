-- merge-catalog.lua — staple the per-root shards into one catalog.
-- A named step (rather than an inline -e) so run.sh stays readable and the merge
-- lives where the rest of the code lives.
DIR = os.getenv("TAPESTRY_DIR")
    or "/home/ritz/programming/ai-stuff/filesystem-tapestry"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/libs/?.lua;" .. package.path
local cfg   = require("00-config")
local store = require("04-catalog-store")
store.merge_shards(cfg.paths.tmp, cfg.paths.catalog)
