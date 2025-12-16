# Issue 007: Embedding Similarity Engine

## Current Behavior
The system lacks a centralized embedding calculation and similarity comparison engine that multiple features require.

## Intended Behavior
Create a robust embedding similarity engine that:
- Integrates with Ollama for embedding generation
- Provides efficient similarity calculations between poems/words
- Supports configurable similarity thresholds
- Caches embeddings for performance
- Serves both navigation and HTML generation features

## Suggested Implementation Steps
1. Research and integrate Ollama embedding API
2. Design embedding data structure and storage format
3. Implement embedding calculation for poems and individual words
4. Create similarity calculation algorithms (cosine similarity, etc.)
5. Build caching layer for computed embeddings
6. Add threshold configuration and filtering
7. Create API for other system components to use
8. Optimize for large-scale processing (~6487 poem sections)

## Related Documents
- Source: Derived from next-1 and next-4 requirements
- Related to: All embedding-dependent issues (001, 006)

## Metadata
- Priority: High
- Complexity: Advanced
- Dependencies: Ollama integration, storage system
- Estimated Effort: Large

## Implementation Notes
This is a foundational component required by multiple other issues. Should be implemented early in the development cycle to support dependent features.