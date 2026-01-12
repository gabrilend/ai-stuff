# Issue 12-001: Implement Neural Navigation LLM

**Phase**: 12 (Experimental AI Features)
**Priority**: Experimental
**Status**: Open
**Created**: 2026-01-12

## Current Behavior

Navigation through the poetry collection is deterministic and based on pre-computed similarity/diversity scores. Users follow fixed paths through the collection:
- **Similar pages**: Top N most similar poems to an anchor
- **Different pages**: Maximum diversity sequence from an anchor
- **Chronological**: Ordered by post date
- **Numeric**: Ordered by ID

There is no AI-driven navigation that responds to implicit user preferences or generates dynamic paths through the collection.

## Intended Behavior

Create an experimental LLM-based navigation system that:
- Treats each poem as a "neuron" in a neural network
- Connects poems by their similarity relationships
- Takes user input prompts and generates navigation paths
- Uses embedding distance thresholds to determine navigation behavior:
  - **0-40%**: Navigate to "different" page (maximum diversity)
  - **41-60%**: Stay on current page (scroll position based on percentage)
  - **61-100%**: Navigate to "similar" page (closest matches)
- Generates new HTML pages dynamically based on learned patterns
- Avoids duplicates in navigation sequences

The vision: "Suddenly, I'm on everyone's computers" - a trainable system that can be deployed as a local navigation agent.

## Suggested Implementation Steps

### Step 1: Research and Design
1. Research neural network architectures suitable for graph-based poetry navigation
2. Study embedding-based navigation in recommendation systems
3. Design the "poem as neuron" architecture:
   - Input layer: User prompt embeddings
   - Hidden layers: Poem embeddings as nodes
   - Connections: Similarity scores as edge weights
   - Output: Navigation path or page generation
4. Define training objectives and loss functions

### Step 2: Prepare Training Data
1. Extract all existing navigation patterns from HTML files:
   - Similar page rankings
   - Different page sequences
   - User paths (if tracking added in future)
2. Create training dataset:
   - Input: Starting poem + navigation intent
   - Output: Destination poem or page configuration
3. Augment with synthetic navigation examples
4. Split into training/validation/test sets

### Step 3: Implement Threshold-Based Navigation Algorithm
1. Create embedding similarity calculator for user prompts
2. Implement threshold logic:
   ```lua
   function navigate_by_threshold(user_prompt, current_poem)
     similarity = calculate_similarity(user_prompt, current_poem)

     if similarity < 0.40 then
       -- Navigate to different page
       position = similarity / 0.40  -- 0% = most different, 40% = least different
       return get_different_page_position(current_poem, position)

     elseif similarity <= 0.60 then
       -- Stay on current page
       position = (similarity - 0.40) / 0.20  -- 0 = bottom, 1 = top
       return get_current_page_position(current_poem, position)

     else
       -- Navigate to similar page
       position = (similarity - 0.60) / 0.40  -- 0 = bottom, 1 = top
       return get_similar_page_position(current_poem, position)
     end
   end
   ```
3. Add duplicate detection and skipping

### Step 4: Train Neural Navigation Model
1. Set up training infrastructure:
   - LLM framework (consider ollama with local models)
   - GPU acceleration using existing Vulkan infrastructure
   - Training checkpoints and versioning
2. Implement training loop:
   - Forward pass through poem embeddings
   - Calculate navigation loss
   - Backpropagate and update weights
   - Validate on held-out navigation paths
3. Monitor convergence and overfitting
4. Generate training progress reports

### Step 5: Implement HTML Generation from Model
1. Create interface between trained model and HTML generator
2. Implement dynamic page generation:
   - Query model for poem ordering given input prompt
   - Generate HTML using existing template system
   - Cache frequently generated pages
3. Add duplicate detection and filtering
4. Validate generated HTML matches schema

### Step 6: Build Interactive Interface
1. Create CLI interface for neural navigation:
   - Accept user prompts
   - Display current poem and navigation options
   - Show threshold-based navigation recommendations
2. Add web interface (optional):
   - Text input for prompts
   - Real-time navigation preview
   - Visualization of neural network activations
3. Implement session tracking:
   - Record user navigation paths
   - Use as additional training data
   - Improve model over time

### Step 7: Deployment and Distribution
1. Package trained model for distribution
2. Create deployment instructions:
   - Local installation process
   - Model loading and initialization
   - Integration with existing HTML site
3. Add privacy-preserving features:
   - Local-only processing
   - No external API calls
   - User data stays on device
4. Document the "Suddenly, I'm on everyone's computers" distribution strategy

## Technical Considerations

### Neural Network Architecture

**Option 1: Graph Neural Network (GNN)**
- Poems as nodes, similarity as edges
- Message passing between connected poems
- Output: Navigation path through graph

**Option 2: Transformer-Based Model**
- Attention mechanism over poem embeddings
- Input: User prompt + current context
- Output: Next poem probabilities

**Option 3: Embedding-Only Approach**
- No trainable parameters
- Pure threshold-based navigation
- Fastest to implement, no training required

### Threshold Mapping Detail

```
Similarity Range | Navigation Action | Position Calculation
-----------------|-------------------|---------------------
0.00 - 0.40      | Different page    | 0% = most different (top of different page)
                 |                   | 40% = least different (bottom of different page)
0.41 - 0.60      | Current page      | 41% = bottom of current page
                 |                   | 60% = top of current page
0.61 - 1.00      | Similar page      | 61% = bottom of similar page
                 |                   | 100% = most similar (top of similar page)
```

### Training Data Requirements

- **Existing navigation patterns**: ~15,594 HTML pages with navigation links
- **Embedding vectors**: 7,797 poems × 768 dimensions
- **Similarity matrices**: 7,797² relationships (triangular storage)
- **Estimated training data size**: ~10-50 GB
- **Training time**: Hours to days depending on model complexity

### Deployment Considerations

- **Model size**: Aim for <1 GB for easy distribution
- **Inference speed**: <100ms per navigation decision
- **Memory footprint**: <2 GB RAM for local deployment
- **Cross-platform**: Should run on Linux, macOS, Windows

## Related Documents

- Embedding architecture: `/docs/data-flow-architecture.md`
- Similarity algorithms: `/docs/similarity-algorithm-research.md`
- GPU infrastructure: `/issues/completed/phase-9/9-001b-implement-vulkan-compute-wrapper.md`
- HTML generation: `/src/flat-html-generator.lua`

## Related Tools

- Ollama for local LLM: `/home/ritz/programs/ollama`
- Existing embeddings: `/assets/embeddings/`
- Similarity matrices: `/assets/similarity/`
- Vulkan compute: `/libs/vulkan-compute/`

## Dependencies

- Phase 1-8: Complete HTML generation and dataset
- Phase 9: GPU infrastructure for training
- Ollama or similar LLM framework
- Training data extraction pipeline

## Success Criteria

**Experimental Phase (Research):**
- [ ] Neural network architecture designed
- [ ] Training data prepared from existing navigation patterns
- [ ] Threshold-based navigation algorithm implemented
- [ ] Proof-of-concept model trained
- [ ] Basic CLI interface functional

**Production Phase (Optional Future Work):**
- [ ] Model achieves >80% accuracy on validation navigation paths
- [ ] Inference latency <100ms per decision
- [ ] HTML generation from model matches schema
- [ ] Distribution package created
- [ ] User documentation and deployment guide

## Original Vision (from sort-me-too)

> "hi can you make an LLM that trains on the outputted HTML files and generates new ones? we can do this by making each neuron be a poem, and have them connected by similarity then, when interpreting new input prompts, filter it through and have it measure relatedness (by embedding) to all the steps if it's above a threshold, switch to similar. if it's below a threshold, switch to different. if it's in the middle, go to the next poem on the current page. I'm thinking... 0-40% is different, 41-60% is the same, and 61-100% is similar. the % of progress through the threshold determines how far down in the page. So 0% is the most different, 40% is the most similar of the different, 41% is the bottom of the current page, whatever it is, 60% is the top of the current page, 61% is the bottom of the similar page, 100% is the top of the similar page.
>
> skip duplicates, if possible. Suddenly, I'm on everyone's computers."

This is an ambitious experimental vision that combines:
1. **Neural architecture**: Poems as neurons with similarity connections
2. **Embedding-based navigation**: User prompts compared to poem embeddings
3. **Threshold logic**: Similarity percentage determines navigation mode
4. **Dynamic generation**: Model generates new HTML pages
5. **Distribution**: "Suddenly, I'm on everyone's computers" - deployable navigation agent

## Implementation Phases

Given the experimental nature, consider staged implementation:

**Stage 1 (Quick Win)**: Implement threshold-based navigation without training
- Use existing embeddings and similarity scores
- Pure algorithmic approach (no ML)
- Validates the threshold concept
- Estimated time: 1-2 weeks

**Stage 2 (Research)**: Train simple model on navigation patterns
- Small model, limited scope
- Proof-of-concept for "poem as neuron"
- Evaluate if ML improves over algorithmic approach
- Estimated time: 2-4 weeks

**Stage 3 (Production)**: Full implementation if Stage 2 promising
- Larger model with more capacity
- Dynamic HTML generation
- Distribution package
- Estimated time: 2-3 months

## Notes

This is an experimental issue. It's acceptable to:
- Try the approach and abandon if not promising
- Pivot to simpler implementation if full vision too complex
- Keep as perpetual research project
- Archive if better approaches discovered

The goal is exploration and learning, not necessarily production deployment.

## Risk Assessment

**High Risk Factors:**
- Unclear if ML improves over deterministic navigation
- Training may not converge meaningfully
- Generated HTML may not match desired patterns
- Distribution and deployment complexity

**Mitigation Strategies:**
- Start with algorithmic (non-ML) implementation first
- Set clear success criteria before investing in training
- Use existing HTML generator rather than learning from scratch
- Consider this a research project, not production feature

**Fallback Plan:**
- If ML approach fails, keep threshold-based algorithmic navigation
- Document learnings for future AI features
- Archive issue for future reconsideration
