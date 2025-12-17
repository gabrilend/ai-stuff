# Issue 034: Bug Bounty Reward System

## Current Behavior

Difficult bugs that require multiple revision attempts (3+) have no formal escalation path. There is no system for:

### Current Issues
- No mechanism to attract external expertise for persistent bugs
- No tracking of who solves difficult problems (expertise registry)
- No incentive structure beyond personal satisfaction
- Bug solving expertise is not recorded or consultable
- No connection between bug-fixing contributions and project ownership/investment

## Intended Behavior

Create a bug bounty system that:

1. **Auto-Escalation**: Automatically create bounties for bugs requiring 3+ revision attempts
2. **Expert Registry**: Track bug solvers as domain experts for future consultation
3. **Token Economy**: Fund bounties with cryptocurrency indexed to company stock value
4. **Exchange System**: Allow conversion between bounty tokens and traditional currency
5. **Extended Rewards**: Support bounties for feature requests and other contributions

### Philosophy
- Draw human attention to genuinely difficult problems
- Build a registry of proven expertise through demonstrated capability
- Align contributor incentives with project success (stock-indexed tokens)
- Create a "poker chip return kiosk" model for flexible value exchange

## Suggested Implementation Steps

### 1. Bug Difficulty Tracking
```lua
-- -- {{{ track_bug_attempts
local function track_bug_attempts(bug_id)
    local bug = bugs_db:get(bug_id)

    bug.revision_attempts = (bug.revision_attempts or 0) + 1

    if bug.revision_attempts >= 3 and not bug.bounty_created then
        create_bounty(bug_id, calculate_bounty_value(bug))
        bug.bounty_created = true
    end

    bugs_db:update(bug_id, bug)
    return bug
end
-- }}}
```

### 2. Bounty Creation System
```lua
-- -- {{{ create_bounty
local function create_bounty(bug_id, token_value)
    local bounty = {
        id = generate_bounty_id(),
        bug_id = bug_id,
        token_value = token_value,
        status = "open",
        created_at = os.time(),
        claimed_by = nil,
        expertise_tags = extract_expertise_tags(bug_id)
    }

    bounties_db:insert(bounty)

    -- Notify potential solvers
    broadcast_bounty(bounty)

    return bounty
end
-- }}}

-- -- {{{ calculate_bounty_value
local function calculate_bounty_value(bug)
    local base_value = 10  -- Base tokens

    -- Scale by difficulty indicators
    local multiplier = 1.0
    multiplier = multiplier + (bug.revision_attempts - 3) * 0.5  -- More attempts = higher value
    multiplier = multiplier + (bug.affected_users or 0) * 0.1   -- Impact scaling

    return math.floor(base_value * multiplier)
end
-- }}}
```

### 3. Expert Registry
```lua
-- -- {{{ register_expert
local function register_expert(user_id, bounty_id)
    local bounty = bounties_db:get(bounty_id)
    local expert = experts_db:get(user_id) or {
        id = user_id,
        bugs_fixed = {},
        expertise_tags = {},
        total_bounties_claimed = 0,
        consultation_available = true
    }

    -- Record the fix
    table.insert(expert.bugs_fixed, {
        bounty_id = bounty_id,
        bug_id = bounty.bug_id,
        fixed_at = os.time(),
        tags = bounty.expertise_tags
    })

    -- Aggregate expertise tags
    for _, tag in ipairs(bounty.expertise_tags) do
        expert.expertise_tags[tag] = (expert.expertise_tags[tag] or 0) + 1
    end

    expert.total_bounties_claimed = expert.total_bounties_claimed + 1

    experts_db:upsert(user_id, expert)
    return expert
end
-- }}}

-- -- {{{ consult_expert
local function consult_expert(topic_tags)
    -- Find experts with matching expertise
    local candidates = experts_db:query({
        expertise_tags = { ["$overlap"] = topic_tags },
        consultation_available = true
    })

    -- Sort by relevance (more bugs fixed in topic = more expertise)
    table.sort(candidates, function(a, b)
        local a_score = calculate_expertise_score(a, topic_tags)
        local b_score = calculate_expertise_score(b, topic_tags)
        return a_score > b_score
    end)

    return candidates
end
-- }}}
```

### 4. Token Economy System
```lua
-- -- {{{ token_config
local token_config = {
    name = "BugBountyToken",
    symbol = "BBT",
    index_to = "company_stock_value",  -- Token value tracks stock
    exchange_rate_update = "daily",
    minimum_withdrawal = 10
}
-- }}}

-- -- {{{ token_operations
local token_ops = {
    -- Award tokens for bounty completion
    award = function(user_id, amount, reason)
        local wallet = wallets_db:get(user_id)
        wallet.balance = wallet.balance + amount
        wallet.history:insert({
            type = "award",
            amount = amount,
            reason = reason,
            timestamp = os.time()
        })
        wallets_db:update(user_id, wallet)
    end,

    -- Exchange tokens for currency at kiosk
    exchange = function(user_id, token_amount)
        local wallet = wallets_db:get(user_id)
        if wallet.balance < token_amount then
            return nil, "Insufficient balance"
        end

        local exchange_rate = get_current_exchange_rate()
        local currency_value = token_amount * exchange_rate

        wallet.balance = wallet.balance - token_amount
        wallets_db:update(user_id, wallet)

        return initiate_payout(user_id, currency_value)
    end
}
-- }}}
```

### 5. Exchange Kiosk Interface
```bash
#!/bin/bash
# Token exchange kiosk utility

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"

# -- {{{ show_kiosk_menu
show_kiosk_menu() {
    echo "=== Token Exchange Kiosk ==="
    echo "1. Check token balance"
    echo "2. Exchange tokens for dollars"
    echo "3. View exchange rate"
    echo "4. Transaction history"
    echo "5. View available bounties"
    echo "6. View feature requests"
    echo "q. Exit"
}
# }}}

# -- {{{ run_kiosk_interactive
run_kiosk_interactive() {
    while true; do
        show_kiosk_menu
        read -p "Select option: " choice
        case $choice in
            1) check_balance "$USER_ID" ;;
            2) exchange_tokens "$USER_ID" ;;
            3) show_exchange_rate ;;
            4) show_history "$USER_ID" ;;
            5) list_bounties ;;
            6) list_feature_requests ;;
            q|Q) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}
# }}}
```

### 6. Extended Bounty Types
```lua
-- -- {{{ bounty_types
local bounty_types = {
    bug_fix = {
        auto_create_threshold = 3,  -- revisions before auto-bounty
        base_value = 10,
        description = "Fix a persistent bug"
    },
    feature_request = {
        auto_create_threshold = nil,  -- Manual creation only
        base_value = 25,
        description = "Implement a requested feature"
    },
    documentation = {
        auto_create_threshold = nil,
        base_value = 5,
        description = "Improve documentation"
    },
    optimization = {
        auto_create_threshold = nil,
        base_value = 15,
        description = "Performance improvement"
    }
}
-- }}}
```

## Implementation Details

### Token-Stock Indexing
The token value is indexed to company stock ownership stake:
- If stock value increases, token purchasing power increases proportionally
- Aligns contributor incentives with long-term project success
- Creates real ownership connection without legal complexity of direct equity

### Expert Consultation Model
- More bugs fixed = more expertise accumulated
- Expertise is topic-specific (tracked via tags)
- Experts can be queried for advice on related issues
- Expertise score considers recency and relevance

### Kiosk Exchange Model
- "Poker chip return kiosk" metaphor - exchange game tokens for real value
- Supports multiple redemption types:
  - Bug bounties → dollars
  - Feature requests → tokens
  - Tokens → other project benefits

## Related Documents
- `033-creator-revenue-sharing-system.md` - Related monetization system
- `032-project-donation-support-links.md` - Donation/support infrastructure
- `docs/roadmap.md` - Phase 4 cross-project coordination

## Tools Required
- Database for bug tracking, bounties, experts, and wallets
- Cryptocurrency/token implementation (or mock for initial development)
- Exchange rate oracle (stock value tracking)
- Notification system for bounty broadcasts
- Kiosk interface (CLI and potentially web)

## Metadata
- **Priority**: Low
- **Complexity**: High
- **Dependencies**: Bug tracking system, Issue 033 (conceptual alignment)
- **Impact**: Incentivizes community contributions, builds expert network, creates ownership alignment

## Success Criteria
- Bugs auto-escalate to bounties after 3+ failed revision attempts
- Expert registry tracks solvers and their domain expertise
- Token system awards, tracks, and allows exchange of bounty rewards
- Kiosk interface provides exchange and balance checking
- Feature requests and other contribution types can have bounties
- Expert consultation system returns relevant experts for topics
- Exchange rate mechanism ties tokens to project value indicator
