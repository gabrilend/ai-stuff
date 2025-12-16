# Issue #001: Add neocities-modernization context support

## Current Behavior

The poem context generator currently only supports two content sources:
1. The compiled.txt file from `/mnt/mtwo/programming/ai-stuff/words-pdf/input/`
2. Random content via the `/home/ritz/words/view-random` script

The system can only generate context from personal messages, notes, and fediverse posts.

## Intended Behavior

The poem context generator should also be able to take in and process neocities-modernization context files as an alternative content source. This would allow for:
- Integration with neocities project content
- More diverse context sources for LLM personalization
- Flexibility to choose between different content types based on use case

## Suggested Implementation Steps

1. **Identify neocities-modernization context file format and location**
   - Examine existing neocities-modernization project structure
   - Understand the content format and organization
   - Document the file format specifications

2. **Add command line option for content source selection**
   - Add `-t, --type [words|neocities]` parameter to both Lua and Bash scripts
   - Update usage documentation and help text
   - Modify argument parsing functions

3. **Implement neocities content extraction function**
   - Create `get_neocities_content()` function parallel to `get_random_poem()`
   - Handle neocities-specific file format and structure
   - Ensure proper error handling and content validation

4. **Update content collection logic**
   - Modify `collect_poems()` function to support multiple content sources
   - Implement source-specific content selection and filtering
   - Maintain existing functionality for words content

5. **Add configuration and validation**
   - Validate neocities context file exists and is readable
   - Add appropriate error messages for missing dependencies
   - Update interactive mode to include source selection

6. **Testing and documentation**
   - Test with various neocities context files
   - Update script comments and usage examples
   - Verify both Lua and Bash implementations work consistently

## Priority
Medium - Enhancement to existing functionality

## Dependencies
- Access to neocities-modernization project files
- Understanding of neocities content structure and format

## Related Documents
- CLAUDE.md requirements for multi-language script implementations
- poem-context-generator script documentation

## Tools
- Existing poem-context-generator-simple.lua
- Existing poem-context-generator-simple.sh
- neocities-modernization project files