# Similarity Algorithm Research for Poetry Embeddings

**Research Date**: December 12, 2025  
**Project**: Neocities Poetry Modernization  
**Scope**: Comprehensive analysis of similarity algorithms for 768-dimensional poetry embeddings  
**Dataset**: 6,860 poems with EmbeddingGemma vectors  

## Executive Summary

This research analyzes similarity algorithms suitable for comparing poetry embeddings, evaluating 12 distinct algorithms across computational efficiency, semantic sensitivity, and practical applicability for the neocities poetry project.

### **Key Findings:**
- **Cosine similarity** remains optimal baseline for normalized embeddings
- **Jensen-Shannon divergence** offers superior semantic analysis for probability distributions
- **Information-theoretic measures** show highest poetry-specific suitability
- **Distance metrics** provide computational efficiency but lower semantic sensitivity

### **Recommended Implementation Priority:**
1. **Tier 1**: Cosine similarity (✅ implemented), Jensen-Shannon divergence, Soft cosine
2. **Tier 2**: Euclidean distance, Manhattan distance, Pearson correlation  
3. **Tier 3**: KL divergence, Angular distance, Normalized euclidean
4. **Tier 4**: Chebyshev distance, Spearman correlation, Minkowski distance

---

## Algorithm Analysis

### **Algorithm 1: Cosine Similarity** ✅ **IMPLEMENTED**

#### Mathematical Definition
- **Formula**: `cos(θ) = (A·B) / (||A|| × ||B||)`
- **Domain**: Real-valued vectors of equal dimension
- **Range**: [-1, 1] where 1 = identical, 0 = orthogonal, -1 = opposite

#### Characteristics
- **Symmetry**: Symmetric
- **Triangle Inequality**: Does not satisfy (not a distance metric)
- **Sensitivity**: Direction/orientation of vectors
- **Robustness**: Magnitude-invariant, robust to scaling

#### Computational Complexity
- **Time**: O(n) for n-dimensional vectors
- **Space**: O(1) additional memory
- **Scalability**: Excellent for large datasets

#### Text/Embedding Suitability
- **High-Dimensional Performance**: Excellent (designed for high-dim spaces)
- **Semantic Sensitivity**: Very good for normalized embeddings
- **Typical Use Cases**: Document similarity, recommendation systems, NLP
- **Poetry-Specific Considerations**: Ideal for semantic similarity, magnitude-independent

#### Implementation Notes
- **Preprocessing Required**: Vectors should be normalized for optimal results
- **Numerical Considerations**: Numerically stable, handles zero vectors gracefully
- **Parameter Tuning**: No parameters required

#### Research References
- **Key Papers**: Foundational to information retrieval and NLP
- **Practical Applications**: Word2Vec, GloVe, BERT similarity
- **Benchmarks**: Standard baseline for text similarity tasks

---

### **Algorithm 2: Jensen-Shannon Divergence**

#### Mathematical Definition
- **Formula**: `JS(P,Q) = ½[KL(P||M) + KL(Q||M)]` where `M = ½(P + Q)`
- **Domain**: Probability distributions (positive values, sum to 1)
- **Range**: [0, 1] where 0 = identical, 1 = maximally different

#### Characteristics
- **Symmetry**: Symmetric (unlike KL divergence)
- **Triangle Inequality**: Satisfies triangle inequality when square-rooted
- **Sensitivity**: Distribution shape and probability mass allocation
- **Robustness**: More stable than KL divergence, handles zero probabilities better

#### Computational Complexity
- **Time**: O(n) for n-dimensional distributions
- **Space**: O(n) for intermediate calculations
- **Scalability**: Excellent, suitable for large-scale similarity matrices

#### Text/Embedding Suitability
- **High-Dimensional Performance**: Excellent with proper normalization
- **Semantic Sensitivity**: Outstanding for semantic distribution comparison
- **Typical Use Cases**: Document clustering, topic modeling, semantic analysis
- **Poetry-Specific Considerations**: Captures semantic topic distributions, excellent for thematic similarity

#### Implementation Notes
- **Preprocessing Required**: Convert embeddings to probability distributions (softmax normalization)
- **Numerical Considerations**: Add small epsilon (1e-10) to prevent log(0)
- **Parameter Tuning**: Normalization temperature parameter

#### Research References
- **Key Papers**: Lin (1991) "Divergence measures based on the Shannon entropy"
- **Practical Applications**: Topic modeling, neural language models
- **Benchmarks**: Superior to KL divergence in symmetric similarity tasks

---

### **Algorithm 3: Euclidean Distance**

#### Mathematical Definition
- **Formula**: `d(A,B) = √(Σ(a_i - b_i)²)`
- **Domain**: Real-valued vectors of equal dimension
- **Range**: [0, ∞] where 0 = identical

#### Characteristics
- **Symmetry**: Symmetric
- **Triangle Inequality**: Satisfies triangle inequality (true metric)
- **Sensitivity**: Magnitude and direction differences
- **Robustness**: Sensitive to outliers and scale differences

#### Computational Complexity
- **Time**: O(n) for n-dimensional vectors
- **Space**: O(1) additional memory
- **Scalability**: Excellent computational performance

#### Text/Embedding Suitability
- **High-Dimensional Performance**: Good but affected by curse of dimensionality
- **Semantic Sensitivity**: Medium - captures overall differences but not semantic nuance
- **Typical Use Cases**: Clustering, nearest neighbor search, general ML
- **Poetry-Specific Considerations**: May be dominated by embedding magnitude rather than semantic content

#### Implementation Notes
- **Preprocessing Required**: Consider normalization for fair comparison
- **Numerical Considerations**: Numerically stable, watch for overflow in squared terms
- **Parameter Tuning**: No parameters, but normalization strategy matters

#### Research References
- **Key Papers**: Classical geometry and statistics literature
- **Practical Applications**: k-means clustering, kNN classification
- **Benchmarks**: Standard baseline for many ML tasks

---

### **Algorithm 4: Manhattan Distance (L1 Norm)**

#### Mathematical Definition
- **Formula**: `d(A,B) = Σ|a_i - b_i|`
- **Domain**: Real-valued vectors of equal dimension  
- **Range**: [0, ∞] where 0 = identical

#### Characteristics
- **Symmetry**: Symmetric
- **Triangle Inequality**: Satisfies triangle inequality
- **Sensitivity**: Absolute differences across all dimensions
- **Robustness**: More robust to outliers than Euclidean distance

#### Computational Complexity
- **Time**: O(n) for n-dimensional vectors
- **Space**: O(1) additional memory
- **Scalability**: Excellent, computationally efficient

#### Text/Embedding Suitability
- **High-Dimensional Performance**: Good, less affected by dimensionality than Euclidean
- **Semantic Sensitivity**: Medium - more robust but may miss subtle patterns
- **Typical Use Cases**: Sparse data, robust clustering, taxi-cab problems
- **Poetry-Specific Considerations**: Good for poems with distinct stylistic differences

#### Implementation Notes
- **Preprocessing Required**: Optional normalization
- **Numerical Considerations**: Extremely stable, no overflow concerns
- **Parameter Tuning**: No parameters required

#### Research References
- **Key Papers**: Taxicab geometry literature
- **Practical Applications**: Image processing, robust statistics
- **Benchmarks**: Often comparable to Euclidean for high-dimensional data

---

### **Algorithm 5: Pearson Correlation Coefficient**

#### Mathematical Definition
- **Formula**: `r = Σ((a_i - ā)(b_i - b̄)) / √(Σ(a_i - ā)² × Σ(b_i - b̄)²)`
- **Domain**: Real-valued vectors with non-zero variance
- **Range**: [-1, 1] where 1 = perfect positive correlation, -1 = perfect negative

#### Characteristics
- **Symmetry**: Symmetric
- **Triangle Inequality**: Does not satisfy (not a distance metric)
- **Sensitivity**: Linear relationships between vector components
- **Robustness**: Scale-invariant but sensitive to linear transformations

#### Computational Complexity
- **Time**: O(n) for n-dimensional vectors
- **Space**: O(1) additional memory  
- **Scalability**: Excellent performance

#### Text/Embedding Suitability
- **High-Dimensional Performance**: Good for detecting linear patterns
- **Semantic Sensitivity**: Medium - captures linear semantic relationships
- **Typical Use Cases**: Feature selection, linear regression, correlation analysis
- **Poetry-Specific Considerations**: Good for detecting structural/stylistic patterns

#### Implementation Notes
- **Preprocessing Required**: Handle constant vectors (zero variance)
- **Numerical Considerations**: Stable with proper variance handling
- **Parameter Tuning**: No parameters required

#### Research References
- **Key Papers**: Classical statistics literature
- **Practical Applications**: Gene expression analysis, financial modeling
- **Benchmarks**: Standard for linear relationship detection

---

### **Algorithm 6: Kullback-Leibler (KL) Divergence**

#### Mathematical Definition
- **Formula**: `KL(P||Q) = Σ p_i × log(p_i / q_i)`
- **Domain**: Probability distributions (positive values, sum to 1)
- **Range**: [0, ∞] where 0 = identical distributions

#### Characteristics
- **Symmetry**: Asymmetric (KL(P||Q) ≠ KL(Q||P))
- **Triangle Inequality**: Does not satisfy
- **Sensitivity**: Information loss when approximating P with Q
- **Robustness**: Sensitive to zero probabilities, requires smoothing

#### Computational Complexity
- **Time**: O(n) for n-dimensional distributions
- **Space**: O(1) additional memory
- **Scalability**: Excellent with proper preprocessing

#### Text/Embedding Suitability
- **High-Dimensional Performance**: Excellent for probability distributions
- **Semantic Sensitivity**: Outstanding for semantic topic analysis
- **Typical Use Cases**: Information theory, variational inference, neural networks
- **Poetry-Specific Considerations**: Excellent for thematic content comparison

#### Implementation Notes
- **Preprocessing Required**: Convert to probability distributions, add smoothing
- **Numerical Considerations**: Add epsilon to prevent log(0), handle zero probabilities
- **Parameter Tuning**: Smoothing parameter, normalization temperature

#### Research References
- **Key Papers**: Kullback & Leibler (1951), information theory literature
- **Practical Applications**: Variational autoencoders, language modeling
- **Benchmarks**: Gold standard for distribution comparison

---

### **Algorithm 7: Angular Distance**

#### Mathematical Definition
- **Formula**: `d(A,B) = arccos(cosine_similarity(A,B)) / π`
- **Domain**: Non-zero real-valued vectors
- **Range**: [0, 1] where 0 = identical direction, 1 = opposite direction

#### Characteristics
- **Symmetry**: Symmetric
- **Triangle Inequality**: Satisfies triangle inequality
- **Sensitivity**: Angular separation between vectors
- **Robustness**: Magnitude-invariant, focuses on direction

#### Computational Complexity
- **Time**: O(n) plus arccos computation
- **Space**: O(1) additional memory
- **Scalability**: Good, slightly more expensive than cosine due to arccos

#### Text/Embedding Suitability
- **High-Dimensional Performance**: Excellent for normalized embeddings
- **Semantic Sensitivity**: Very good, captures semantic direction differences
- **Typical Use Cases**: Directional data analysis, spherical clustering
- **Poetry-Specific Considerations**: Good for semantic orientation comparison

#### Implementation Notes
- **Preprocessing Required**: Vector normalization recommended
- **Numerical Considerations**: Handle edge cases for arccos domain
- **Parameter Tuning**: No parameters required

#### Research References
- **Key Papers**: Directional statistics literature
- **Practical Applications**: Text analysis, computer vision
- **Benchmarks**: Often equivalent to cosine similarity with different scale

---

### **Algorithm 8: Soft Cosine Similarity**

#### Mathematical Definition
- **Formula**: Extends cosine similarity with term-term similarity matrix S
- **Domain**: Term vectors with similarity matrix between terms
- **Range**: [0, 1] typically, depends on similarity matrix

#### Characteristics
- **Symmetry**: Symmetric if similarity matrix is symmetric
- **Triangle Inequality**: Depends on similarity matrix properties
- **Sensitivity**: Semantic relationships between different terms/concepts
- **Robustness**: More robust to vocabulary differences

#### Computational Complexity
- **Time**: O(n²) due to similarity matrix operations
- **Space**: O(n²) for storing similarity matrix
- **Scalability**: Computationally expensive for large vocabularies

#### Text/Embedding Suitability
- **High-Dimensional Performance**: Excellent but computationally intensive
- **Semantic Sensitivity**: Outstanding - captures cross-term relationships
- **Typical Use Cases**: Document similarity with semantic awareness
- **Poetry-Specific Considerations**: Excellent for capturing poetic metaphors and semantic relationships

#### Implementation Notes
- **Preprocessing Required**: Construct term-term similarity matrix
- **Numerical Considerations**: Matrix operations require careful numerical handling
- **Parameter Tuning**: Similarity matrix construction parameters

#### Research References
- **Key Papers**: Sidorov et al. (2014) "Soft similarity and soft cosine measure"
- **Practical Applications**: Document retrieval, semantic text analysis
- **Benchmarks**: Superior to standard cosine for semantic tasks

---

### **Algorithm 9: Chebyshev Distance (L∞ Norm)**

#### Mathematical Definition
- **Formula**: `d(A,B) = max|a_i - b_i|`
- **Domain**: Real-valued vectors of equal dimension
- **Range**: [0, ∞] where 0 = identical

#### Characteristics
- **Symmetry**: Symmetric
- **Triangle Inequality**: Satisfies triangle inequality
- **Sensitivity**: Maximum difference across any single dimension
- **Robustness**: Extremely sensitive to single large differences

#### Computational Complexity
- **Time**: O(n) for n-dimensional vectors
- **Space**: O(1) additional memory
- **Scalability**: Excellent computational performance

#### Text/Embedding Suitability
- **High-Dimensional Performance**: Poor - dominated by single dimensions
- **Semantic Sensitivity**: Low - misses overall semantic patterns
- **Typical Use Cases**: Game theory, optimization, extreme difference detection
- **Poetry-Specific Considerations**: Not suitable for nuanced semantic comparison

#### Implementation Notes
- **Preprocessing Required**: Consider normalization to balance dimensions
- **Numerical Considerations**: Extremely stable computationally
- **Parameter Tuning**: No parameters required

#### Research References
- **Key Papers**: Optimization and game theory literature
- **Practical Applications**: Chess algorithms, minimax optimization
- **Benchmarks**: Rarely used for semantic similarity

---

### **Algorithm 10: Normalized Euclidean Distance**

#### Mathematical Definition
- **Formula**: `d(A,B) = √(Σ((a_i - b_i)/σ_i)²)` where σ_i is standard deviation
- **Domain**: Real-valued vectors with feature scaling information
- **Range**: [0, ∞] where 0 = identical

#### Characteristics
- **Symmetry**: Symmetric
- **Triangle Inequality**: Satisfies triangle inequality
- **Sensitivity**: Magnitude differences adjusted for feature variance
- **Robustness**: More robust to scale differences than standard Euclidean

#### Computational Complexity
- **Time**: O(n) for n-dimensional vectors
- **Space**: O(n) for storing normalization parameters
- **Scalability**: Good with preprocessing overhead

#### Text/Embedding Suitability
- **High-Dimensional Performance**: Better than standard Euclidean
- **Semantic Sensitivity**: Medium - improved by normalization
- **Typical Use Cases**: Standardized feature comparison, ML preprocessing
- **Poetry-Specific Considerations**: Good when embedding dimensions have different scales

#### Implementation Notes
- **Preprocessing Required**: Compute feature-wise statistics for normalization
- **Numerical Considerations**: Handle zero variance dimensions
- **Parameter Tuning**: Normalization strategy (global vs. local statistics)

#### Research References
- **Key Papers**: Statistical standardization literature
- **Practical Applications**: Machine learning preprocessing, data science
- **Benchmarks**: Often improves upon raw Euclidean distance

---

### **Algorithm 11: Spearman Rank Correlation**

#### Mathematical Definition
- **Formula**: Pearson correlation applied to rank-transformed data
- **Domain**: Real-valued vectors (converted to ranks)
- **Range**: [-1, 1] where 1 = perfect monotonic relationship

#### Characteristics
- **Symmetry**: Symmetric
- **Triangle Inequality**: Does not satisfy
- **Sensitivity**: Monotonic relationships rather than linear
- **Robustness**: Robust to outliers and non-linear relationships

#### Computational Complexity
- **Time**: O(n log n) due to ranking operations
- **Space**: O(n) for storing ranks
- **Scalability**: More expensive due to sorting requirements

#### Text/Embedding Suitability
- **High-Dimensional Performance**: Good for ordinal relationships
- **Semantic Sensitivity**: Medium - captures ranking patterns
- **Typical Use Cases**: Non-parametric statistics, rank-based analysis
- **Poetry-Specific Considerations**: Good for stylistic ranking patterns

#### Implementation Notes
- **Preprocessing Required**: Rank transformation with tie handling
- **Numerical Considerations**: Handle tied ranks appropriately
- **Parameter Tuning**: Tie-breaking strategy

#### Research References
- **Key Papers**: Non-parametric statistics literature
- **Practical Applications**: Robust correlation analysis, ranking systems
- **Benchmarks**: Standard non-parametric alternative to Pearson

---

### **Algorithm 12: Minkowski Distance (Generalized)**

#### Mathematical Definition
- **Formula**: `d(A,B) = (Σ|a_i - b_i|^p)^(1/p)` where p is the order parameter
- **Domain**: Real-valued vectors, p ≥ 1
- **Range**: [0, ∞] where 0 = identical

#### Characteristics
- **Symmetry**: Symmetric
- **Triangle Inequality**: Satisfies triangle inequality for p ≥ 1
- **Sensitivity**: Depends on p parameter (p=1: Manhattan, p=2: Euclidean, p=∞: Chebyshev)
- **Robustness**: Varies with p parameter

#### Computational Complexity
- **Time**: O(n) for n-dimensional vectors
- **Space**: O(1) additional memory
- **Scalability**: Excellent, computational cost varies slightly with p

#### Text/Embedding Suitability
- **High-Dimensional Performance**: Depends on p parameter
- **Semantic Sensitivity**: Medium - flexible but requires parameter tuning
- **Typical Use Cases**: Flexible distance metric, parameter optimization
- **Poetry-Specific Considerations**: Allows optimization of distance function for poetry

#### Implementation Notes
- **Preprocessing Required**: Optional normalization
- **Numerical Considerations**: Handle fractional powers carefully
- **Parameter Tuning**: p parameter requires optimization for dataset

#### Research References
- **Key Papers**: Hermann Minkowski's work on metric spaces
- **Practical Applications**: Flexible ML distance functions
- **Benchmarks**: Generalizes Manhattan, Euclidean, and Chebyshev distances

---

## Algorithm Comparison Matrix

| Algorithm | Computational Cost | Semantic Sensitivity | Poetry Suitability | Implementation Difficulty | Numerical Stability |
|-----------|-------------------|---------------------|-------------------|-------------------------|-------------------|
| Cosine Similarity ✅ | O(n) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Easy | ⭐⭐⭐⭐⭐ |
| Jensen-Shannon | O(n) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Medium | ⭐⭐⭐⭐ |
| Euclidean Distance | O(n) | ⭐⭐⭐ | ⭐⭐⭐ | Easy | ⭐⭐⭐⭐⭐ |
| Manhattan Distance | O(n) | ⭐⭐⭐ | ⭐⭐⭐ | Easy | ⭐⭐⭐⭐⭐ |
| Pearson Correlation | O(n) | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Easy | ⭐⭐⭐⭐ |
| KL Divergence | O(n) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Hard | ⭐⭐⭐ |
| Angular Distance | O(n) | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Medium | ⭐⭐⭐⭐ |
| Soft Cosine | O(n²) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Hard | ⭐⭐⭐ |
| Chebyshev Distance | O(n) | ⭐⭐ | ⭐⭐ | Easy | ⭐⭐⭐⭐⭐ |
| Normalized Euclidean | O(n) | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Medium | ⭐⭐⭐⭐ |
| Spearman Correlation | O(n log n) | ⭐⭐⭐ | ⭐⭐⭐ | Medium | ⭐⭐⭐⭐ |
| Minkowski Distance | O(n) | ⭐⭐⭐ | ⭐⭐⭐ | Medium | ⭐⭐⭐⭐ |

**Legend**: ⭐⭐⭐⭐⭐ = Excellent, ⭐⭐⭐⭐ = Very Good, ⭐⭐⭐ = Good, ⭐⭐ = Fair, ⭐ = Poor

---

## Implementation Roadmap

### **Tier 1 (Immediate Implementation)**
1. **Cosine Similarity** ✅ - Already implemented, excellent baseline
2. **Jensen-Shannon Divergence** - High semantic sensitivity, symmetric
3. **Angular Distance** - Complementary to cosine, true metric

### **Tier 2 (Short-term Implementation)**
4. **Euclidean Distance** - Simple, interpretable baseline
5. **Manhattan Distance** - Robust alternative to Euclidean
6. **Pearson Correlation** - Linear relationship detection

### **Tier 3 (Medium-term Research)**
7. **KL Divergence** - Information-theoretic analysis
8. **Normalized Euclidean** - Scale-invariant improvements
9. **Soft Cosine Similarity** - Advanced semantic awareness

### **Tier 4 (Experimental/Research)**
10. **Minkowski Distance** - Parameter optimization research
11. **Spearman Correlation** - Non-parametric relationships
12. **Chebyshev Distance** - Extreme difference detection

---

## Poetry-Specific Recommendations

### **For Semantic Similarity (Theme/Content)**
1. **Jensen-Shannon Divergence** - Captures thematic distribution differences
2. **Soft Cosine Similarity** - Understands metaphoric relationships
3. **KL Divergence** - Information-theoretic semantic analysis

### **For Stylistic Similarity (Structure/Form)**
1. **Pearson Correlation** - Linear stylistic patterns
2. **Spearman Correlation** - Rank-based structural analysis
3. **Angular Distance** - Directional style differences

### **For General Purpose (Baseline)**
1. **Cosine Similarity** ✅ - Excellent all-around performance
2. **Euclidean Distance** - Simple, interpretable differences
3. **Manhattan Distance** - Robust general comparison

### **For Computational Efficiency**
1. **Manhattan Distance** - Fastest computation
2. **Euclidean Distance** - Good speed/accuracy balance
3. **Cosine Similarity** ✅ - Efficient with pre-normalized vectors

---

## Research Validation

### **Literature Review Sources**
- Information retrieval and similarity measure research (Salton & McGill)
- High-dimensional data analysis (Aggarwal et al.)
- Text similarity and semantic analysis (Mihalcea et al.)
- Embedding space analysis (Rogers et al.)
- Poetry computational analysis (Haider et al.)

### **Computational Feasibility Analysis**
- **Dataset**: 6,860 poems × 768-dimensional embeddings
- **Matrix Size**: 47M comparisons requiring efficient algorithms
- **Memory Requirements**: Must fit within reasonable computational constraints
- **Processing Time**: Target <1 hour per algorithm for full matrix generation

### **Numerical Stability Considerations**
- **Embedding Range**: Typical values [-1, 1] for normalized embeddings
- **Precision Requirements**: 4-decimal precision sufficient for similarity scores
- **Edge Cases**: Handle zero vectors, identical vectors, extreme values
- **Overflow Protection**: Monitor for computational overflow in distance calculations

---

## Conclusion

This research provides a comprehensive analysis of 12 similarity algorithms for poetry embeddings. **Jensen-Shannon divergence** and **soft cosine similarity** emerge as the most promising candidates for advanced semantic analysis, while **distance metrics** offer computational efficiency for large-scale processing.

The **implementation roadmap** prioritizes algorithms by their combination of semantic sensitivity, computational efficiency, and implementation complexity. **Cosine similarity** remains the gold standard baseline, with **Jensen-Shannon divergence** recommended as the next implementation priority for enhanced semantic analysis capabilities.

This research establishes the foundation for implementing a comprehensive similarity algorithm comparison system, enabling evidence-based selection of optimal algorithms for different poetry analysis tasks.

**Research Status**: ✅ **COMPLETED**  
**Next Step**: Implement Tier 1 algorithms based on these findings