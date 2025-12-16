# Claude Resume Generator

> **AI-powered resume and portfolio generation system with intelligent project analysis and weighted priority assessment.**

[![Bash](https://img.shields.io/badge/Bash-4.0%2B-green)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-Educational-blue)](LICENSE)

## Quick Start

```bash
# Interactive mode (easiest way to start)
./claude_gen

# Direct usage
./claude_gen -t SKILLS -c . -r /some/project

# Install globally
./claude_gen --install
```

## What This Does

The Claude Resume Generator is an intelligent analysis system that:

- **Scans project directories** with configurable priority weighting (10%, 19%, 28%, etc.)
- **Extracts technical skills** and capabilities from codebases
- **Generates professional documents** (resumes, portfolios, technical documentation)
- **Analyzes multiple sources** with intelligent priority balancing
- **Creates comprehensive reports** with AI-powered insights

## Core Features

### 🎯 **Weighted Priority Analysis**
- **Smart Weighting**: 10%, 19%, 28%, 37%, etc. priority progression
- **Multi-Directory**: Analyze random + current directories with different importance
- **Adaptive Factors**: File count, directory age, content size influence priority
- **Balanced Assessment**: Ensures fair representation across all sources

### 🧠 **Intelligent Topic Framework**
- **Resume Generation**: Professional resume with project analysis
- **Skills Extraction**: Technical capabilities and proficiencies  
- **Portfolio Creation**: Comprehensive technical portfolio
- **Project Documentation**: Detailed project analysis and documentation
- **Business Analysis**: Business-focused capability assessment

### 📊 **Comprehensive Analysis**
- **File Pattern Matching**: Configurable scan patterns per topic
- **Content Analysis**: Extract meaningful information from various file types
- **Context Building**: Generate rich context for AI analysis
- **Report Generation**: Professional formatted output documents

## Available Analysis Types

| Topic | Description | Output Format |
|-------|-------------|---------------|
| **RESUME** | Basic professional resume | Structured resume |
| **RESUME_DETAILED** | Comprehensive resume with project analysis | Enhanced resume |
| **SKILLS** | Technical skills extraction | Skills assessment |
| **PORTFOLIO** | Technical portfolio creation | Portfolio website |
| **PROJECT** | Project analysis and overview | Project summary |
| **DOCUMENTATION** | Code and API documentation | Technical docs |
| **BUSINESS** | Business intelligence report | Business report |

## Usage Examples

### Basic Usage
```bash
# Interactive mode
./claude_gen

# Skills analysis of current directory
./claude_gen -t SKILLS

# Generate comprehensive resume
./claude_gen -t RESUME_DETAILED -c . -r /other/project
```

### Advanced Usage
```bash
# Specific directories and classification
./claude_gen -r /random/project -c /current/work -t PORTFOLIO

# List all available topics
./claude_gen --list-topics

# Get help
./claude_gen --help
```

### Global Installation
```bash
# Install as global command
./claude_gen --install claude_resume

# Use from anywhere
claude_resume -I
```

## Priority Weighting System

The system implements intelligent priority weighting:

### Basic Pattern
- Directory 1 (random): **10%** priority
- Directory 2 (current): **19%** priority
- Directory 3 (additional): **28%** priority
- And so on with increasing importance...

### Advanced Weighting
The system also considers:
- **Directory Age**: Recent activity increases weight
- **File Count**: More files can boost importance
- **Content Size**: Larger projects may get priority
- **File Relevance**: Pattern matches influence weighting

## Configuration

### Topic Configuration
Topics are defined in `scripts/claude_topics_config.sh`:

```bash
declare -A TOPIC_RESUME=(
    [type]="resume_generation"
    [priority_weights]="10,19,28,37,46,55,64,73,82,91,100"
    [scan_patterns]="*.md,*.txt,*.lua,*.py,*.js,*.sh"
    [analysis_depth]="3"
    [output_format]="structured_resume"
)
```

### Extending Topics
Add new analysis types by:
1. Creating new topic definition in config file
2. Adding analysis logic if needed
3. Testing with `--list-topics`

## Output Examples

### Skills Analysis
```markdown
# Technical Skills Assessment

## Programming Languages
- **Python**: Advanced (data analysis, web development)
- **JavaScript**: Intermediate (frontend, Node.js)
- **Bash**: Expert (automation, system administration)

## Frameworks & Tools
- React, Node.js, Love2D
- Git, Docker, CI/CD
- Neural Networks, Machine Learning

## Project Experience
- AI Visualization Systems
- Web Application Development
- System Automation Tools
```

### Resume Generation
```markdown
# Professional Resume

## Summary
Experienced software developer with expertise in AI visualization,
web development, and system automation. Proven track record of
building complex interactive systems and technical tools.

## Technical Skills
- Languages: Python, JavaScript, Lua, Bash
- Frameworks: React, Node.js, Love2D
- Specialties: AI/ML, Data Visualization, System Design

## Projects
- AI Playground: Neural network visualization system
- Resume Generator: Intelligent document generation tool
- Various automation and analysis tools
```

## Directory Structure

```
resume-generation/
├── claude_gen                 # Main executable
├── scripts/
│   └── claude_topics_config.sh # Topic definitions
├── docs/
│   ├── README.md              # This file
│   └── USER_GUIDE.md          # Detailed usage guide
└── output/                    # Generated documents
```

## Advanced Features

### Template System
- **Context-Aware**: Responses adapt to project type and content
- **Multiple Variations**: Different templates for variety
- **Professional Focus**: Business-appropriate language and format
- **Technical Accuracy**: Correct interpretation of technical content

### Analysis Engine
- **Pattern Recognition**: Identify technologies, frameworks, patterns
- **Content Extraction**: Pull meaningful information from code and docs
- **Relevance Scoring**: Rank findings by importance and confidence
- **Synthesis**: Combine information from multiple sources coherently

### Output Formatting
- **Markdown**: Clean, readable format for further processing
- **Professional Structure**: Industry-standard document organization
- **Customizable**: Adaptable formatting for different use cases
- **Export Ready**: Suitable for conversion to PDF, HTML, etc.

## Installation & Requirements

### Prerequisites
- **Bash** 4.0+ (for script execution)
- **Standard Unix tools** (find, grep, awk, sed)

### Installation
```bash
# Clone/download the project
cd resume-generation

# Make executable
chmod +x claude_gen

# Test installation
./claude_gen --help
```

### Global Installation
```bash
# Install globally
./claude_gen --install

# Verify installation
claude_resume_gen --version
```

## Contributing

Areas for contribution:
- **New Topic Types**: Additional analysis frameworks
- **Enhanced Patterns**: Better file pattern recognition
- **Output Formats**: New document formats and styles
- **AI Integration**: Enhanced language model integration

## License

Educational License - designed for learning, research, and career development.

---

## Quick Start Summary

```bash
./claude_gen           # Interactive mode
./claude_gen -t SKILLS # Extract skills from current directory  
./claude_gen --install # Install globally

# Then explore with:
./claude_gen --list-topics
./claude_gen --help
```

Transform your project directories into professional career documents with intelligent AI analysis!