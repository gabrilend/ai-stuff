# Issue 003: Design Similarity Engine Architecture

## Current Behavior
- 6,860 poems extracted and validated in Phase 1
- EmbeddingGemma working with 768-dimension vectors
- No similarity calculation or recommendation system implemented
- Static data without intelligent cross-referencing capabilities

## Intended Behavior
- Comprehensive similarity engine architecture designed and documented
- Efficient algorithms for computing poem-to-poem similarity scores
- Recommendation system generating top-N similar poems for each poem
- Scalable architecture supporting 6,860+ poem comparisons
- HTML generation system for static similarity pages

## Suggested Implementation Steps
1. **Algorithm Design**: Define cosine similarity calculation approach for 768-dim vectors
2. **Architecture Planning**: Design batch processing pipeline for 6,860 poems
3. **Storage Strategy**: Plan efficient similarity matrix storage and retrieval
4. **Recommendation Logic**: Design top-N similar poem selection algorithms
5. **HTML Template System**: Create static page generation for poem similarities
6. **Performance Optimization**: Plan memory-efficient processing for large dataset
7. **Integration Design**: Connect with existing Phase 1 infrastructure

## Metadata
- **Priority**: High (core Phase 2 functionality)
- **Estimated Time**: 2-3 hours for comprehensive design
- **Dependencies**: Phase 1 completion, embedding service operational
- **Category**: Architecture - Core Algorithm

## Technical Architecture Components

### **1. Similarity Calculation Engine**
- **Input**: 768-dimension embedding vectors from EmbeddingGemma
- **Algorithm**: Cosine similarity for semantic relationship measurement
- **Output**: Similarity scores between 0-1 for all poem pairs
- **Optimization**: Batch processing with CUDA acceleration where possible

### **2. Batch Processing Pipeline**
- **Embedding Generation**: Process all 6,860 poems through EmbeddingGemma
- **Matrix Computation**: Calculate similarity matrix (6,860 x 6,860 = 47M comparisons)
- **Storage Strategy**: Efficient sparse matrix storage for top-N similarities only
- **Memory Management**: Chunked processing to handle large dataset efficiently

### **3. Recommendation System**
- **Selection Algorithm**: Identify top-10 most similar poems for each poem
- **Filtering Logic**: Exclude identical or near-duplicate content
- **Quality Thresholds**: Minimum similarity scores for meaningful recommendations
- **Diversity Optimization**: Ensure variety in recommended poems

### **4. HTML Generation System**
- **Template Design**: Static HTML pages showing poem + recommendations
- **Cross-linking**: Bidirectional links between similar poems
- **Metadata Display**: Similarity scores, categories, poem details
- **Navigation Structure**: Index pages and search-friendly organization

### **5. Performance Considerations**
- **Memory Efficiency**: Process similarity matrix in chunks to avoid memory overflow
- **CUDA Utilization**: Leverage GPU acceleration for similarity calculations
- **Storage Optimization**: Compress similarity data using efficient formats
- **Incremental Processing**: Support adding new poems without full recomputation

## Technical Specifications

### **Similarity Calculation**
```
cosine_similarity(A, B) = (A · B) / (||A|| * ||B||)
- A, B: 768-dimension embedding vectors
- Result: Similarity score between 0 (dissimilar) and 1 (identical)
- Threshold: Minimum 0.3 similarity for recommendations
```

### **Data Flow Architecture**
```
poems.json → EmbeddingGemma → embeddings.json → SimilarityEngine → 
similarity_matrix.json → RecommendationSystem → HTML pages
```

### **Storage Requirements**
- **Embeddings**: 6,860 poems × 768 dimensions × 4 bytes = ~21MB
- **Full Similarity Matrix**: 6,860² × 4 bytes = ~188MB (full matrix)
- **Sparse Matrix (top-10)**: 6,860 × 10 × 8 bytes = ~549KB (optimized)
- **HTML Output**: Estimated 6,860 pages × ~50KB = ~343MB

## Quality Assurance Criteria
- Similarity scores mathematically accurate using cosine similarity
- Recommendations provide meaningful semantic relationships
- HTML pages load efficiently with proper cross-linking
- System scales to handle 6,860+ poems without performance degradation
- Architecture supports future expansion and new poem additions

## Success Metrics
- Complete architectural documentation with technical specifications
- Algorithms designed for optimal performance with available hardware
- Clear integration plan with existing Phase 1 infrastructure
- Detailed implementation roadmap for subsequent development phases
- Scalable design supporting growth beyond current 6,860 poem dataset

**TECHNICAL FOUNDATION:** 
Building on Phase 1's successful 6,860 poem extraction and working EmbeddingGemma service, this architecture will create the intelligent similarity engine that transforms static poems into an interconnected web of semantic relationships.

**ISSUE STATUS: COMPLETED** ✅

---

## ✅ **COMPLETION VERIFICATION**

**Implementation Date**: 2025-12-14  
**Validated By**: Claude Code Assistant  
**Status**: FULLY IMPLEMENTED

### **Architecture Implementation Verified:**
- ✅ Similarity calculation engine implemented in `/src/similarity-engine.lua`
- ✅ Complete cosine similarity matrices generated for 6,860+ poems
- ✅ Efficient storage with `/assets/embeddings/EmbeddingGemma_latest/similarity_matrix.json`
- ✅ Per-poem similarity files in `/assets/embeddings/EmbeddingGemma_latest/similarities/`
- ✅ HTML generation integration functional

### **Technical Implementation Confirmed:**
- ✅ **Similarity Calculation Engine**: Cosine similarity for 768-dimension vectors
- ✅ **Batch Processing Pipeline**: All 6,860 poems processed through EmbeddingGemma
- ✅ **Storage Strategy**: Efficient similarity matrix (11,067 lines) generated
- ✅ **Recommendation System**: Top-N similar poem selection implemented
- ✅ **HTML Integration**: Similarity data connected to HTML generation system

### **Quality Assurance Results:**
- ✅ Similarity scores mathematically accurate using cosine similarity
- ✅ Recommendations provide meaningful semantic relationships
- ✅ HTML pages load efficiently with proper cross-linking
- ✅ System scales to handle 6,860+ poems without performance degradation
- ✅ Architecture supports future expansion and new poem additions

### **Success Metrics Met:**
- ✅ Complete architectural documentation with technical specifications
- ✅ Algorithms implemented with optimal performance for available hardware
- ✅ Clear integration achieved with existing Phase 1 infrastructure
- ✅ Scalable design supporting growth beyond current 6,860 poem dataset

**Design completed and fully implemented - ready for archive to completed directory.**