# Claude Resume Generator Usage Guide

## Overview

The Claude Resume Generator is an intelligent system that scans project directories and synthesizes thoughts about various topics using Claude functions. It implements a weighted priority system where directories receive different importance levels (10%, 19%, 28%, etc.) and includes a flexible framework for storing and processing different types of analysis topics.

## Quick Start

### Basic Usage
```bash
# Interactive mode (easiest)
./claude_gen

# Direct usage with specific parameters
./claude_gen -t SKILLS -r /some/random/dir -c .

# Show available topics
./claude_gen --list-topics

# Get help
./claude_gen --help
```

### Installation as Global Function
```bash
# Install globally (adds to ~/.bashrc)
./claude_gen --install

# Use from anywhere (after restart or source ~/.bashrc)
claude_resume_gen -I

# Uninstall
./claude_gen --uninstall
```

## Topic Framework

The system supports extensible topics, each with their own:

- **Scan Patterns**: Which file types to analyze
- **Priority Weights**: How to weight different directories 
- **Analysis Depth**: How deep to scan directory structure
- **Output Format**: What type of analysis to generate
- **Focus Areas**: What aspects to emphasize

### Available Topics

1. **RESUME** - Professional resume generation
2. **RESUME_DETAILED** - Comprehensive resume with detailed analysis
3. **PORTFOLIO** - Technical portfolio generation  
4. **DOCUMENTATION** - Code and API documentation
5. **BUSINESS** - Business intelligence report
6. **LEARNING** - Personalized learning path
7. **SECURITY** - Security assessment report
8. **PROJECT** - Basic project analysis
9. **SKILLS** - Technical skills extraction

## Priority Weighting System

The system implements intelligent priority weighting:

### Basic Pattern
- Directory 1 (random): 10% priority
- Directory 2 (current): 19% priority  
- Directory 3: 28% priority
- Directory 4: 37% priority
- And so on...

### Advanced Weighting Factors
The system also considers:
- **Directory Age**: Newer directories get higher weight
- **File Count**: More files can increase weight
- **Content Size**: Larger projects may get priority boost
- **Project Activity**: Recent modifications boost priority

## Command Line Interface

### Core Options
```bash
-I, --interactive           # Run in interactive mode
-r, --random-dir DIR        # Specify random directory to analyze
-c, --current-dir DIR       # Specify current directory to analyze  
-t, --topic TOPIC           # Specify analysis topic
```

### Management Options
```bash
--install [FUNC_NAME]       # Install global bash function
--uninstall [FUNC_NAME]     # Uninstall global bash function
--list-topics               # List all available topics
-h, --help                  # Show help message
```

## Interactive Mode

When you run `./claude_gen` or `./claude_gen -I`, the system guides you through:

1. **Topic Selection**: Choose from available analysis types
2. **Directory Selection**: Specify which directories to analyze
3. **Configuration Review**: Confirm your choices
4. **Analysis Execution**: Generate the results

## Output Examples

### Resume Generation
```markdown
# Professional Resume Analysis

## Technical Skills
- Programming Languages: Lua, Python, JavaScript, Shell Scripting
- Frameworks: Love2D, Neural Networks, UI Systems
- Development Practices: Version Control, Documentation, Testing

## Project Experience
- AI Playground: Interactive neural network visualization
- Layout Management: Draggable UI panel system
- LLM Integration: Real-time narration system

## Key Strengths
- Full-stack development capabilities
- Technical documentation skills
- Problem-solving and system design
```

### Skills Analysis  
```markdown
# Technical Skills Assessment

## Core Programming
- **Lua**: Advanced (game development, scripting)
- **Shell Scripting**: Expert (automation, system tools)
- **Python**: Intermediate (data analysis, AI/ML)

## Specialized Knowledge
- Neural Network Implementation
- UI/UX Design and Layout Systems
- Real-time Visualization Systems
- API Design and Integration

## Development Tools
- Version Control Systems
- Documentation Frameworks
- Testing and Validation
```

## Extending the Framework

### Adding New Topics

1. Edit `scripts/claude_topics_config.sh`
2. Define a new `TOPIC_YOURNAME` associative array:

```bash
declare -A TOPIC_YOURNAME=(
    [type]="your_analysis_type"
    [name]="Display Name"
    [description]="What this topic analyzes"
    [priority_weights]="10,20,30,40,50,60,70,80,90,100"
    [scan_patterns]="*.ext1,*.ext2,pattern/*"
    [analysis_depth]="3"
    [context_window]="5000"
    [output_format]="your_output_format"
    [sections]="section1,section2,section3"
    [focus_areas]="focus1,focus2,focus3"
)
```

3. The system automatically detects and uses new topics

### Customizing Priority Weights

Topics can use different priority patterns:
- Linear: `"10,20,30,40,50,60,70,80,90,100"`
- Exponential: `"10,19,28,37,46,55,64,73,82,91,100"`
- Custom: Any comma-separated percentage values

## Integration with Claude API

Currently uses mock responses for demonstration. To integrate with real Claude API:

1. Modify the `call_claude_api()` function in `claude_resume_generator.sh`
2. Add your Claude API credentials and endpoint
3. Implement proper HTTP request handling
4. Parse and format the actual Claude responses

## File Structure

```
ai-playground/
├── claude_gen                          # Main wrapper script
├── scripts/
│   ├── claude_resume_generator.sh       # Core generator system
│   └── claude_topics_config.sh          # Topic definitions
├── claude_resume_YYYYMMDD_HHMMSS.md    # Generated outputs
└── CLAUDE_GENERATOR_USAGE.md           # This documentation
```

## Best Practices

### For Resume Generation
- Ensure project directories contain comprehensive README files
- Include documentation of your technical decisions
- Maintain clear project structure with meaningful file names
- Keep code well-commented and organized

### For Portfolio Creation
- Include visual assets (screenshots, diagrams) 
- Document project outcomes and impact
- Show progression and learning over time
- Highlight unique or innovative solutions

### For Skills Assessment
- Organize code by technology and complexity
- Include examples of different programming paradigms
- Demonstrate testing and documentation practices
- Show collaboration and version control usage

## Troubleshooting

### Common Issues

**Script not found**: Ensure you're running from the project directory
```bash
cd /path/to/ai-playground
./claude_gen
```

**Permission denied**: Make sure scripts are executable
```bash
chmod +x claude_gen scripts/*.sh
```

**No content found**: Check that target directories contain relevant files
```bash
# Verify files exist in target directory
ls -la /target/directory/
```

**Topic not recognized**: Use `--list-topics` to see available options
```bash
./claude_gen --list-topics
```

### Debug Mode

Enable detailed logging by modifying the log level in the script or running with verbose output:
```bash
bash -x ./claude_gen -t RESUME
```

## Future Enhancements

- Real Claude API integration
- Web interface for easier interaction  
- Export to different formats (PDF, JSON, XML)
- Integration with Git for automatic project discovery
- Machine learning for improved content analysis
- Template customization system
- Multi-language support for international resumes