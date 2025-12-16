# Neocities Poetry Modernization Project

## Project Summary

This project modernizes the ritzmenardi.com website by creating an intelligent poetry recommendation system. The system processes 6,860 poems from words.pdf and generates similarity-based recommendations using local LLM embeddings through a comprehensive Lua-based similarity engine.

## Current Status: **Phase 5 Advanced Discovery & Optimization 🔄**

**Completed Systems:**
- ✅ Complete poem extraction and validation (6,860 poems)
- ✅ Advanced similarity engine with incremental caching
- ✅ Per-model embedding storage system supporting multiple models
- ✅ Robust network error handling and retry mechanisms
- ✅ Interactive bash CLI with real-time progress monitoring
- ✅ Comprehensive cache management and flush operations
- ✅ Complete HTML generation system with similarity navigation
- ✅ Golden poem identification and collection features
- ✅ JavaScript-free responsive design for mobile/desktop
- ✅ Data integrity improvements and infrastructure optimization

**Current Phase:** Dual system implementation (similarity + diversity) and similarity algorithm research

**Next Phase:** Visual content integration and user experience enhancements

## Key Features

1. **Poem Extraction ✅**: Successfully extracted 6,860 individual poems from words.pdf
2. **Embedding Generation ✅**: Multi-model support (EmbeddingGemma:latest, text-embedding-ada-002, all-MiniLM-L6-v2)
3. **Similarity Engine ✅**: Cosine similarity calculation with intelligent caching
4. **Incremental Processing ✅**: Smart detection of existing embeddings for efficient updates
5. **HTML Generation ✅**: Complete static HTML system with ~6400 related/different pages
6. **Golden Poem Features ✅**: Fediverse-prioritized golden poem identification and collection
7. **Responsive Design ✅**: Mobile-optimized interface without JavaScript dependencies
8. **Advanced Discovery 🔄**: Dual exploration system (simple similarity + progressive centroid diversity) and algorithm research (Phase 5)
9. **Visual Content Integration 📋**: Image placement and content warning systems (Phase 6)
10. **Export Systems 📋**: PDF generation with words-pdf styling (Phase 6)

## Technical Architecture

- **Processing Backend**: Lua-based similarity engine with comprehensive CLI tools
- **Embedding Models**: Multiple model support via Ollama (EmbeddingGemma:latest, etc.)
- **Storage System**: Per-model JSON caching with automatic migration
- **Network Resilience**: Exponential backoff retry with configurable error thresholds
- **Data Flow**: words.pdf → extracted poems → per-model embeddings → similarity matrix → HTML pages

## System Capabilities

- **Incremental Processing**: Only processes new/changed poems for efficiency
- **Model Isolation**: Separate storage for different embedding models
- **Error Recovery**: Robust handling of network issues and service interruptions
- **Cache Management**: Flush operations with backup and selective cleaning
- **Real-time Monitoring**: Live progress bars with accurate time estimates
- **Dual Exploration System**: Simple similarity ranking for focused discovery + progressive centroid diversity for expansive exploration
- **Cross-Navigation**: Seamless switching between similarity and diversity exploration modes

## Source Materials

- Poetry source: /home/ritz/programming/ai-stuff/words-pdf
- Website backup: /home/ritz/neocities
- Ollama installation: /home/ritz/programs/ollama