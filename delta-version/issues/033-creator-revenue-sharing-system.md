# Issue 033: Creator Revenue Sharing System

## Current Behavior

No system exists for managing revenue sharing between content creators and original IP holders. Projects like Warcraft 3 map creation exist in a space where:

### Current Issues
- No mechanism to compensate original game developers for derivative work
- Creators cannot easily monetize custom maps or modifications
- No transparent system for tracking and distributing revenue shares
- Original creators have no formal channel to receive recognition or compensation

## Intended Behavior

Create a revenue sharing framework that enables:

1. **Map/Content Sales**: Allow creators to sell Warcraft 3 maps and other derivative content
2. **Revenue Holding System**: Hold revenue portions designated for original creators (Blizzard/original developers)
3. **Transparent Allocation**: Track revenue with clear attribution of ownership stakes
4. **Consent-Based Distribution**: Only distribute funds when original creators explicitly claim them
5. **Reinvestment Option**: Allow original creators to redirect funds toward new projects for users

### Philosophy
- Original creators are notified but not obligated to claim funds
- Unclaimed funds are held indefinitely, never spent unilaterally
- Any redistribution requires explicit creator consent with stated intentions
- "Stay in game design" - keep funds within the creative ecosystem

## Suggested Implementation Steps

### 1. Revenue Configuration Format
```lua
-- -- {{{ revenue_config
-- Configuration for revenue sharing percentages
local revenue_config = {
    creator_share = 0.70,      -- Map creator receives 70%
    original_holder = 0.20,    -- Original IP holder (held in escrow)
    platform_fee = 0.10,       -- Platform maintenance
    escrow_policy = "hold_indefinitely"
}
-- }}}
```

### 2. Revenue Tracking Database Schema
```lua
-- -- {{{ define_revenue_schema
local function define_revenue_schema()
    return {
        transactions = {
            id = "string",
            content_id = "string",         -- Which map/content sold
            amount = "number",
            creator_portion = "number",
            holder_portion = "number",
            timestamp = "number",
            status = "string"              -- pending, distributed, held
        },
        escrow = {
            holder_id = "string",
            total_held = "number",
            contact_attempts = "table",
            claimed = "boolean",
            claim_instructions = "string"  -- What to do with funds if claimed
        }
    }
end
-- }}}
```

### 3. Notification System
```lua
-- -- {{{ notify_original_creator
local function notify_original_creator(holder_info, revenue_info)
    -- Generate notification with:
    -- - Amount available for claim
    -- - Source attribution (which content generated revenue)
    -- - Claim instructions
    -- - Option to redirect to new projects

    local notification = {
        type = "revenue_available",
        amount = revenue_info.holder_portion,
        source = revenue_info.content_id,
        message = "Funds held on your behalf. Claim at your discretion.",
        options = {
            "claim_direct",
            "redirect_to_projects",
            "decline_permanently"
        }
    }

    return send_notification(holder_info.contact, notification)
end
-- }}}
```

### 4. Escrow Management Utility
```bash
#!/bin/bash
# Revenue escrow management utility

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"

# -- {{{ show_escrow_status
show_escrow_status() {
    local holder_id="$1"
    echo "=== Escrow Status for: $holder_id ==="
    echo "Total Held: \$$(get_held_amount "$holder_id")"
    echo "Sources: $(get_revenue_sources "$holder_id")"
    echo "Status: Awaiting claim (no expiration)"
}
# }}}
```

## Implementation Details

### Content Registration
Each sellable content item must be registered with:
- Creator identity (the map maker)
- Original IP holder identification (e.g., Blizzard Entertainment)
- Revenue split configuration
- Contact information for holder (if known)

### Legal Considerations
- This system is for voluntary revenue sharing
- Does not replace or circumvent licensing requirements
- Original creators must be informed of the system's existence
- All transactions should be logged for transparency

### Integration Points
- Could integrate with Issue 032 (Project Donation/Support Links)
- Uses similar philosophy of attention as encouragement, not obligation

## Related Documents
- `032-project-donation-support-links.md` - Related donation/support system
- `docs/roadmap.md` - Phase 4 mentions project self-reporting systems

## Tools Required
- Database or file-based storage for transaction records
- Notification system (email or other contact method)
- Payment processing integration (future phase)
- Legal documentation templates

## Metadata
- **Priority**: Low
- **Complexity**: High
- **Dependencies**: Issue 032 (conceptual alignment)
- **Impact**: Enables ethical monetization of derivative content with creator recognition

## Success Criteria
- Revenue configuration format documented and implemented
- Transaction tracking system stores all revenue events
- Escrow system holds funds indefinitely without automatic expiration
- Notification system can contact original creators when contact info available
- Clear documentation of claim process and redirection options
- Original creators can redirect funds to "new projects for users" as specified
