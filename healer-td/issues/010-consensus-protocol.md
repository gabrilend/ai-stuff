# Issue #010: Consensus Protocol (F005 partial)

**Priority**: High  
**Phase**: 4.2 (Multiplayer Integration)  
**Estimated Effort**: 5-6 days  
**Dependencies**: #009  

## Problem Description

Implement the distributed consensus protocol for multiplayer game state 
synchronization including leader election, state proposals, validation, 
voting, and Byzantine fault tolerance as specified in the architecture.

## Current Behavior

Message protocol exists but no distributed state management.

## Expected Behavior

Robust consensus protocol that maintains consistent game state across 
all players despite network issues, player disconnections, and malicious 
actors (up to 1/3 of players).

## Implementation Approach

### Consensus Manager
```lua
-- {{{ ConsensusManager
local ConsensusManager = {
  players = {},
  currentLeader = nil,
  currentTick = 0,
  pendingProposal = nil,
  votes = {},
  consensusTimeout = 1000, -- 1 second
  phase = "IDLE" -- IDLE, PROPOSAL, VOTING, COMMIT
}

-- {{{ init
function ConsensusManager:init(players)
  self.players = players
  self.currentLeader = self:electLeader(players)
  self.currentTick = 0
  self.votes = {}
  self.phase = "IDLE"
end
-- }}}

-- {{{ startConsensusRound
function ConsensusManager:startConsensusRound(actions)
  if self.phase ~= "IDLE" then
    return false, "Consensus already in progress"
  end
  
  self.currentTick = self.currentTick + 1
  self.phase = "PROPOSAL"
  
  if self:isLeader() then
    return self:proposeStateUpdate(actions)
  else
    return self:waitForProposal()
  end
end
-- }}}

-- {{{ proposeStateUpdate
function ConsensusManager:proposeStateUpdate(actions)
  -- Collect actions from all players
  local allActions = self:collectPlayerActions(actions)
  
  -- Calculate new state
  local newState = GameEngine:calculateNextState(allActions)
  
  -- Create proposal
  local proposal = {
    tick = self.currentTick,
    leader = self.currentLeader,
    state = newState,
    actions = allActions,
    checksum = self:calculateStateChecksum(newState),
    timestamp = socket.gettime()
  }
  
  self.pendingProposal = proposal
  self.phase = "VOTING"
  
  -- Broadcast proposal to all players
  return self:broadcastProposal(proposal)
end
-- }}}

-- {{{ handleProposal
function ConsensusManager:handleProposal(proposal, sender)
  if not self:validateProposal(proposal, sender) then
    return self:rejectProposal(proposal, "Invalid proposal")
  end
  
  if proposal.tick ~= self.currentTick then
    return self:rejectProposal(proposal, "Incorrect tick")
  end
  
  -- Validate state transition
  local isValid = self:validateStateTransition(proposal)
  
  local vote = {
    tick = proposal.tick,
    voter = self.playerId,
    decision = isValid and "ACCEPT" or "REJECT",
    reason = isValid and "Valid" or "Invalid state transition",
    timestamp = socket.gettime()
  }
  
  -- Send vote to leader
  return self:sendVote(vote, proposal.leader)
end
-- }}}
```

### Leader Election
```lua
-- {{{ LeaderElection
local LeaderElection = {}

-- {{{ electLeader
function LeaderElection:electLeader(players)
  -- Deterministic leader selection based on player IDs
  local sortedPlayers = {}
  for _, player in pairs(players) do
    table.insert(sortedPlayers, player)
  end
  
  table.sort(sortedPlayers, function(a, b)
    return a.id < b.id
  end)
  
  return sortedPlayers[1].id
end
-- }}}

-- {{{ rotateLeader
function LeaderElection:rotateLeader(currentLeader, players)
  local sortedPlayers = {}
  for _, player in pairs(players) do
    if player.connected then
      table.insert(sortedPlayers, player)
    end
  end
  
  table.sort(sortedPlayers, function(a, b)
    return a.id < b.id
  end)
  
  -- Find current leader position
  local currentIndex = 1
  for i, player in ipairs(sortedPlayers) do
    if player.id == currentLeader then
      currentIndex = i
      break
    end
  end
  
  -- Select next leader (wrap around)
  local nextIndex = (currentIndex % #sortedPlayers) + 1
  return sortedPlayers[nextIndex].id
end
-- }}}

-- {{{ handleLeaderFailure
function LeaderElection:handleLeaderFailure(failedLeader, players)
  -- Remove failed leader from active players
  if players[failedLeader] then
    players[failedLeader].connected = false
  end
  
  -- Elect new leader from remaining players
  local activePlayers = {}
  for id, player in pairs(players) do
    if player.connected then
      activePlayers[id] = player
    end
  end
  
  return self:electLeader(activePlayers)
end
-- }}}
```

### State Validation
```lua
-- {{{ StateValidator
local StateValidator = {}

-- {{{ validateStateTransition
function StateValidator:validateStateTransition(proposal)
  local currentState = GameEngine:getCurrentState()
  local proposedState = proposal.state
  
  -- Validate tick progression
  if proposedState.tick != currentState.tick + 1 then
    return false, "Invalid tick progression"
  end
  
  -- Validate actions can produce this state
  local calculatedState = GameEngine:applyActions(
    currentState, 
    proposal.actions
  )
  
  if not self:statesEqual(calculatedState, proposedState) then
    return false, "State doesn't match actions"
  end
  
  -- Validate game rules
  if not self:validateGameRules(proposedState) then
    return false, "Game rule violation"
  end
  
  -- Validate resource constraints
  if not self:validateResources(proposedState) then
    return false, "Resource constraint violation"
  end
  
  return true
end
-- }}}

-- {{{ validateGameRules
function StateValidator:validateGameRules(state)
  -- Check tower placement rules
  for _, tower in pairs(state.towers) do
    if not self:isValidTowerPlacement(tower, state.map) then
      return false
    end
  end
  
  -- Check resource constraints
  for _, player in pairs(state.players) do
    if player.resources.gold < 0 or player.resources.lives < 0 then
      return false
    end
  end
  
  -- Check enemy spawning rules
  for _, enemy in pairs(state.enemies) do
    if not self:isValidEnemySpawn(enemy, state.currentWave) then
      return false
    end
  end
  
  return true
end
-- }}}

-- {{{ statesEqual
function StateValidator:statesEqual(state1, state2)
  -- Deep comparison of game states
  local checksum1 = self:calculateStateChecksum(state1)
  local checksum2 = self:calculateStateChecksum(state2)
  
  return checksum1 == checksum2
end
-- }}}

-- {{{ calculateStateChecksum
function StateValidator:calculateStateChecksum(state)
  -- Create deterministic checksum of game state
  local stateString = Serializer:serializeGameState(state)
  return self:sha256(stateString)
end
-- }}}
```

### Voting System
```lua
-- {{{ VotingSystem
local VotingSystem = {
  requiredMajority = 0.67, -- 2/3 majority
  voteTimeout = 5000 -- 5 seconds
}

-- {{{ collectVotes
function VotingSystem:collectVotes(proposal)
  local votes = {}
  local startTime = socket.gettime()
  
  while socket.gettime() - startTime < self.voteTimeout do
    local vote = self:receiveVote()
    if vote and vote.tick == proposal.tick then
      votes[vote.voter] = vote
      
      -- Check if we have enough votes to decide
      if self:canDecide(votes, proposal) then
        break
      end
    end
  end
  
  return votes
end
-- }}}

-- {{{ canDecide
function VotingSystem:canDecide(votes, proposal)
  local totalPlayers = self:getActivePlayerCount()
  local acceptVotes = 0
  local rejectVotes = 0
  
  for _, vote in pairs(votes) do
    if vote.decision == "ACCEPT" then
      acceptVotes = acceptVotes + 1
    elseif vote.decision == "REJECT" then
      rejectVotes = rejectVotes + 1
    end
  end
  
  local acceptRatio = acceptVotes / totalPlayers
  local rejectRatio = rejectVotes / totalPlayers
  
  -- Can decide if we have majority or enough votes to prevent majority
  return acceptRatio >= self.requiredMajority or 
         rejectRatio > (1 - self.requiredMajority)
end
-- }}}

-- {{{ tallyVotes
function VotingSystem:tallyVotes(votes)
  local acceptCount = 0
  local rejectCount = 0
  local totalVotes = 0
  
  for _, vote in pairs(votes) do
    totalVotes = totalVotes + 1
    if vote.decision == "ACCEPT" then
      acceptCount = acceptCount + 1
    elseif vote.decision == "REJECT" then
      rejectCount = rejectCount + 1
    end
  end
  
  local totalPlayers = self:getActivePlayerCount()
  local acceptRatio = acceptCount / totalPlayers
  
  return {
    accept = acceptCount,
    reject = rejectCount,
    total = totalVotes,
    players = totalPlayers,
    acceptRatio = acceptRatio,
    consensus = acceptRatio >= self.requiredMajority
  }
end
-- }}}
```

### Byzantine Fault Tolerance
```lua
-- {{{ ByzantineFaultHandler
local ByzantineFaultHandler = {
  maxByzantineNodes = 0, -- Will be set to 1/3 of total players
  suspiciousActivity = {},
  banList = {}
}

-- {{{ detectByzantineBehavior
function ByzantineFaultHandler:detectByzantineBehavior(player, action)
  local playerId = player.id
  
  if not self.suspiciousActivity[playerId] then
    self.suspiciousActivity[playerId] = {
      invalidProposals = 0,
      contradictoryVotes = 0,
      timeouts = 0,
      lastSeen = socket.gettime()
    }
  end
  
  local activity = self.suspiciousActivity[playerId]
  
  if action.type == "INVALID_PROPOSAL" then
    activity.invalidProposals = activity.invalidProposals + 1
  elseif action.type == "CONTRADICTORY_VOTE" then
    activity.contradictoryVotes = activity.contradictoryVotes + 1
  elseif action.type == "TIMEOUT" then
    activity.timeouts = activity.timeouts + 1
  end
  
  -- Check if player should be considered Byzantine
  local suspicionScore = self:calculateSuspicionScore(activity)
  
  if suspicionScore > 100 then
    return self:markAsByzantine(playerId)
  end
  
  return false
end
-- }}}

-- {{{ calculateSuspicionScore
function ByzantineFaultHandler:calculateSuspicionScore(activity)
  local score = 0
  
  score = score + activity.invalidProposals * 30
  score = score + activity.contradictoryVotes * 20
  score = score + activity.timeouts * 10
  
  -- Time decay - reduce suspicion over time
  local timeSinceLastSeen = socket.gettime() - activity.lastSeen
  local decayFactor = math.max(0, 1 - (timeSinceLastSeen / 3600)) -- 1 hour decay
  
  return score * decayFactor
end
-- }}}

-- {{{ handleByzantineNode
function ByzantineFaultHandler:handleByzantineNode(playerId)
  -- Add to ban list
  self.banList[playerId] = {
    bannedAt = socket.gettime(),
    reason = "Byzantine behavior detected"
  }
  
  -- Remove from active players
  GameEngine:removePlayer(playerId)
  
  -- Trigger leader re-election if necessary
  if ConsensusManager.currentLeader == playerId then
    ConsensusManager.currentLeader = LeaderElection:handleLeaderFailure(
      playerId, 
      GameEngine:getActivePlayers()
    )
  end
  
  return true
end
-- }}}
```

### Recovery Mechanisms
```lua
-- {{{ ConsensusRecovery
local ConsensusRecovery = {}

-- {{{ handleConsensusFailure
function ConsensusRecovery:handleConsensusFailure(reason)
  if reason == "TIMEOUT" then
    return self:handleTimeout()
  elseif reason == "SPLIT_VOTE" then
    return self:handleSplitVote()
  elseif reason == "LEADER_FAILURE" then
    return self:handleLeaderFailure()
  elseif reason == "STATE_CORRUPTION" then
    return self:handleStateCorruption()
  end
  
  return false
end
-- }}}

-- {{{ handleTimeout
function ConsensusRecovery:handleTimeout()
  -- Increase timeout and retry
  ConsensusManager.consensusTimeout = 
    ConsensusManager.consensusTimeout * 1.5
  
  -- Rotate leader
  ConsensusManager.currentLeader = LeaderElection:rotateLeader(
    ConsensusManager.currentLeader,
    GameEngine:getActivePlayers()
  )
  
  return true
end
-- }}}

-- {{{ recoverFromDesync
function ConsensusRecovery:recoverFromDesync()
  -- Request full state from majority of players
  local stateRequests = {}
  local players = GameEngine:getActivePlayers()
  
  for playerId, player in pairs(players) do
    if playerId ~= self.playerId then
      local request = {
        type = "STATE_REQUEST",
        tick = ConsensusManager.currentTick,
        requestor = self.playerId
      }
      
      NetworkLayer:sendMessage(request, playerId)
      stateRequests[playerId] = request
    end
  end
  
  -- Collect state responses
  local stateResponses = self:collectStateResponses(stateRequests)
  
  -- Find consensus state
  local consensusState = self:findConsensusState(stateResponses)
  
  if consensusState then
    GameEngine:setState(consensusState)
    ConsensusManager.currentTick = consensusState.tick
    return true
  end
  
  return false
end
-- }}}
```

## Acceptance Criteria

- [ ] Leader election works deterministically across all players
- [ ] State proposals generated correctly by leader
- [ ] Proposal validation catches invalid state transitions
- [ ] Voting system requires 2/3 majority for consensus
- [ ] Byzantine behavior detection and handling functional
- [ ] Consensus failure recovery mechanisms work
- [ ] State synchronization maintains consistency
- [ ] Performance adequate for real-time gaming
- [ ] Network partition tolerance and recovery
- [ ] Malicious player isolation (up to 1/3 of players)
- [ ] Leader rotation on failure or timeout
- [ ] State corruption detection and recovery

## Technical Notes

### Performance Requirements
- Consensus round < 100ms for normal operation
- State validation < 10ms
- Byzantine detection < 5ms per check
- Memory usage < 20MB for consensus state

### Fault Tolerance
- Handles up to 1/3 Byzantine (malicious) players
- Recovers from network partitions
- Tolerates leader failures
- Detects and recovers from state corruption

## Test Cases

1. **Normal Consensus**
   - Successful consensus rounds
   - State consistency verification
   - Performance under load

2. **Leader Failure**
   - Leader timeout handling
   - Leader rotation
   - Consensus continuation

3. **Byzantine Behavior**
   - Invalid proposal detection
   - Malicious voting patterns
   - Player isolation

4. **Network Issues**
   - Partition tolerance
   - Message loss recovery
   - Desync recovery

5. **Edge Cases**
   - Simultaneous failures
   - Rapid player changes
   - State corruption scenarios

## Integration Points

- **Game Engine**: State management and validation
- **Network Layer**: Message distribution
- **Cryptographic System**: Authentication and integrity
- **Player Management**: Active player tracking

## Future Considerations

- Advanced Byzantine fault tolerance algorithms
- Performance optimizations for large player counts
- Hierarchical consensus for scalability
- Formal verification of consensus properties