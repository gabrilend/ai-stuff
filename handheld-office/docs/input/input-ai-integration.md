# Input System AI Integration

## Overview

This document describes how the core input system integrates with AI features including image generation, text completion, and smart assistance. AI services run on laptop daemons as secure proxies, with Anbernic devices sending encrypted bytecode instructions via WiFi Direct P2P.

**Data Flow**: Anbernic Device → WiFi Direct P2P → Encrypted Bytecode → Laptop Daemon → AI Service HTTP APIs

## Integration Architecture

### AI-Extended Input Manager

<details>
<summary>AI Extension Fields (click to expand)</summary>

```rust
// Additional fields in EnhancedInputManager for AI features
pub struct EnhancedInputManager {
    // ... core fields (see input-core-system.md)
    
    // WiFi Direct P2P for secure bytecode communication to laptop daemon
    pub wifi_direct: Option<WiFiDirectP2P>,
    pub laptop_daemon_connected: bool,
    pub available_image_files: Vec<ImageFileEntry>,
    pub pending_bytecode_requests: Vec<PendingBytecodeRequest>,
    pub images_directory: PathBuf,
}
```
</details>

### AI Input Modes

<details>
<summary>AI-Specific Modes (click to expand)</summary>

```rust
pub enum EnhancedInputMode {
    // ... core modes (see input-core-system.md)
    
    // AI-specific modes
    ImageMenu { submenu: ImageSubmenu },
    AIImagePrompt { prompt: String },
}

pub enum ImageSubmenu {
    Main,
    FileSelection { files: Vec<ImageFileEntry> },
    AIGeneration,
}
```
</details>

## AI Image Generation

### Image Prompt Mode

Enter AI image generation mode from any text input context:

```rust
// Trigger AI image prompt mode
input.enter_mode(EnhancedInputMode::AIImagePrompt { 
    prompt: String::new() 
})?;

// Build prompt with input system
let prompt_text = input.build_ai_prompt()?;

// Request image generation
let request_id = input.request_ai_image(prompt_text, ImageStyle::Default)?;

// Handle completion
match input.poll_ai_requests() {
    Some(AIResult::ImageReady { request_id, image_path }) => {
        input.insert_image_placeholder(image_path)?;
    },
    Some(AIResult::GenerationFailed { request_id, error }) => {
        input.show_error_message(&error)?;
    },
    None => { /* Still generating */ }
}
```

### Image Menu Navigation

<details>
<summary>Image Menu Controls (click to expand)</summary>

```
┌─ AI Image Menu ──────────────────┐
│ ○ Generate New Image             │
│ ○ Browse Generated Images (5)    │
│ ○ Import from File               │
│ ○ Share via P2P                  │
│                                  │
│ Recent Generations:              │
│ ○ sunset_landscape.png           │
│ ○ robot_character.png            │
│ ○ abstract_art.png               │
└──────────────────────────────────┘
```

**Controls:**
- **D-pad Up/Down**: Navigate menu options
- **A Button**: Select option
- **B Button**: Return to previous menu
- **L/R**: Switch between generated/imported images
</details>

### Image Placeholders

#### Inline Image References
```text
Here is the generated artwork: [IMG:sunset_landscape.png]

The robot design [IMG:robot_character.png] shows the concept.
```

#### Placeholder Management
- **Automatic Insertion**: AI completion creates placeholders
- **Manual Insertion**: User-triggered image placement
- **Batch Processing**: Multiple images in single request

## AI Text Assistance

### Smart Text Completion
```rust
// Enable AI text assistance
input.enable_ai_assistance(AIModel::Local)?;

// Request text completion
let context = input.get_text_context(50); // Last 50 characters
let suggestions = input.request_text_completion(context)?;

// Apply suggestion
if let Some(suggestion) = suggestions.first() {
    input.insert_text(&suggestion.text)?;
}
```

### Context-Aware Suggestions
- **Document Type Detection**: Adapt suggestions to content type
- **Style Consistency**: Match existing writing style
- **Technical Accuracy**: Domain-specific suggestions

## Workflow Integration

### Document Enhancement
```rust
// AI-enhanced document workflow
pub fn enhance_document_with_ai(input: &mut EnhancedInputManager) -> Result<(), InputError> {
    // 1. Analyze current document
    let analysis = input.analyze_document_context()?;
    
    // 2. Suggest improvements
    let suggestions = input.get_ai_suggestions(analysis)?;
    
    // 3. Present options to user
    for suggestion in suggestions {
        match suggestion.suggestion_type {
            AISuggestion::ImagePlacement { position, prompt } => {
                input.insert_image_placeholder_at(position, prompt)?;
            },
            AISuggestion::TextExpansion { position, expansion } => {
                input.offer_text_expansion(position, expansion)?;
            },
            AISuggestion::StyleImprovement { range, alternative } => {
                input.offer_text_replacement(range, alternative)?;
            },
        }
    }
    
    Ok(())
}
```

### Multi-Modal Creation
1. **Text Input**: User writes document with placeholders
2. **AI Analysis**: System analyzes content for improvement opportunities  
3. **Image Generation**: AI creates images for placeholders
4. **Integration**: Images and text combined automatically
5. **Review**: User reviews and refines AI suggestions

## AI Service Architecture

### Local vs. Remote Processing

#### Local AI (On-Device)
```rust
pub enum LocalAICapability {
    TextCompletion,    // Small language models
    ImageAnalysis,     // Basic computer vision
    StyleSuggestions,  // Grammar and style checking
}
```

#### Remote AI (Laptop Daemon)
```rust
// Request processing via secure laptop daemon
pub struct RemoteAIRequest {
    pub request_type: AIRequestType,
    pub payload: Vec<u8>,
    pub relationship_id: RelationshipId, // Encrypted channel
}
```

### Service Selection
- **Capability Detection**: Determine available AI services
- **Performance Optimization**: Choose best service for task
- **Fallback Strategy**: Graceful degradation if AI unavailable

## Error Handling

### AI Service Failures
```rust
match input.request_ai_service(request) {
    Err(AIError::ServiceUnavailable) => {
        // Fall back to local processing or manual mode
        input.disable_ai_features();
        input.show_message("AI unavailable, continuing in manual mode");
    },
    Err(AIError::GenerationTimeout) => {
        // Cancel request and offer alternatives
        input.cancel_ai_request(request_id);
        input.offer_alternative_workflows()?;
    },
    Ok(response) => {
        // Process successful AI response
        input.handle_ai_response(response)?;
    }
}
```

### Content Filtering
- **Safety Checks**: Filter inappropriate content
- **Quality Control**: Validate AI output quality
- **User Override**: Allow manual content review

## Performance Optimization

### Request Batching
- **Multi-Request Processing**: Bundle related AI requests
- **Priority Queuing**: Critical requests first
- **Resource Management**: Limit concurrent AI operations

### Caching Strategy
- **Response Caching**: Store AI results for reuse
- **Prompt Optimization**: Efficient prompt construction
- **Model Loading**: Lazy loading of AI models

## Privacy & Security

### Data Protection
- **On-Device Processing**: Prefer local AI when possible
- **Encrypted Transmission**: Secure communication with laptop daemon
- **No Cloud Dependencies**: Maintain air-gapped operation

### Content Security
- **Input Validation**: Sanitize user prompts
- **Output Filtering**: Review AI-generated content
- **Audit Trail**: Log AI interactions for review

## Configuration

### AI Settings
<details>
<summary>AI Configuration Options (click to expand)</summary>

```rust
pub struct AIInputConfig {
    pub ai_assistance_enabled: bool,
    pub preferred_ai_service: AIService,
    pub image_generation_quality: ImageQuality,
    pub text_completion_aggressiveness: f32,
    pub content_filtering_level: ContentFilter,
    pub max_concurrent_requests: usize,
}
```
</details>

### User Preferences
- **AI Interaction Style**: Conservative vs. aggressive suggestions
- **Content Types**: Enable/disable specific AI features
- **Performance vs. Quality**: Trade-off preferences

## Related Documentation

- **Core Input**: `docs/input-core-system.md`
- **P2P Integration**: `docs/input-p2p-integration.md`
- **AI Image Service**: `docs/ai-image-keyboard.md`
- **Security**: `docs/cryptographic-architecture.md`

---

**Dependencies**: Core input system + AI services (local/remote)  
**Performance**: AI-dependent, optimized for handheld constraints  
**Privacy**: Local-first with encrypted remote options