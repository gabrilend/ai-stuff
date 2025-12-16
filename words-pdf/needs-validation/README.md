# Needs Validation Directory

## Purpose

This directory serves as a **repository of symlinks** pointing to files that require user attention, validation, or review. It acts as a focused workspace for items that need human verification before proceeding with implementation or deployment.

## Usage Guidelines

### Core Principles
- **Maximum 3 active items** - Only 3 symlinks allowed at any time to maintain focus
- **Symlinks only** - This directory contains symbolic links, not actual files
- **User attention required** - All items here need human review, validation, or decision-making

### Workflow Process

1. **Addition**: When a file needs user validation, create a symlink here
2. **Review**: User examines the linked content and provides feedback/validation
3. **Resolution**: Based on user input, take appropriate action
4. **Cleanup**: Remove symlink once validation is complete

### Types of Content Requiring Validation

#### Export Comprehension Illustration
- Generated reports that summarize complex implementations
- Documentation that attempts to capture user requirements
- Status summaries that need accuracy verification

#### Directional Validation ("Right Coast")
- Implementation approaches that need strategic confirmation
- Architecture decisions requiring user approval
- Feature specifications that may need adjustment

#### Deployment Readiness
- Installation instructions requiring user testing
- Configuration guides needing environment-specific validation
- Integration procedures requiring user verification

## File Naming Convention

Use descriptive names that indicate:
- **Type**: `report-`, `guide-`, `implementation-`, `config-`
- **Subject**: Brief description of what needs validation
- **Priority**: Optional suffix like `-urgent` or `-review`

Example: `guide-web-chatbot-deployment-review`

## Symlink Management

### Creating Symlinks
```bash
# Create relative symlink to target file
ln -s ../path/to/target/file needs-validation/descriptive-name

# Example:
ln -s ../reports/implementation-status-report.md needs-validation/report-chatbot-implementation
```

### Removing Symlinks
```bash
# Remove symlink after validation complete
rm needs-validation/symlink-name
```

### Checking Current Status
```bash
# List current validation items
ls -la needs-validation/

# Verify symlink targets
file needs-validation/*
```

## Three-Item Limit Enforcement

**Why 3 Items Maximum?**
- Maintains focus on highest priority items
- Prevents validation backlog from becoming overwhelming
- Encourages timely resolution of pending items
- Ensures user attention is concentrated on critical decisions

**When Limit Reached:**
1. Prioritize existing items by urgency/importance
2. Complete validation on lower-priority items first
3. Remove completed symlinks before adding new ones
4. Consider if new item truly requires immediate validation

## Validation Status Tracking

### Implicit Status by Presence
- **Present in directory**: Needs validation
- **Absent from directory**: Validation complete or not required

### Optional Status Indicators
- Add suffix to symlink names: `-pending`, `-reviewed`, `-approved`
- Use file modification times to track validation age
- Document validation results in linked files themselves

## Integration with Project Workflow

### Issue Tracking Integration
- Link to specific issues that generated validation needs
- Reference validation outcomes in issue completion notes
- Create follow-up issues based on validation feedback

### Documentation Lifecycle
- Draft documents → `needs-validation/` → User review → Final version
- Implementation guides → Validation → Deployment approval
- Status reports → Review → Archive or revision

## Best Practices

1. **Clear Descriptions**: Use symlink names that clearly indicate what needs validation
2. **Timely Review**: Address items promptly to avoid stale validation queues
3. **Clean Resolution**: Always remove symlinks after validation is complete
4. **Documentation**: Note validation outcomes in appropriate project documentation
5. **Priority Management**: Keep only the most critical 3 items active

## Example Usage Scenarios

### Scenario 1: Implementation Report Review
```bash
# Implementation complete, needs user verification
ln -s ../reports/implementation-status-report.md needs-validation/report-chatbot-status-review

# User reviews report, provides feedback
# Developer updates report based on feedback
# Remove symlink after approval
rm needs-validation/report-chatbot-status-review
```

### Scenario 2: Deployment Guide Validation
```bash
# Created deployment instructions, needs user testing
ln -s ../docs/deployment-guide.md needs-validation/guide-deployment-test-required

# User tests deployment steps, identifies issues
# Developer fixes deployment procedure
# Remove symlink after successful validation
rm needs-validation/guide-deployment-test-required
```

### Scenario 3: Configuration Verification
```bash
# Generated config file needs environment-specific validation
ln -s ../config/system-settings.conf needs-validation/config-environment-check

# User validates settings for their specific environment
# Configuration approved for use
rm needs-validation/config-environment-check
```

---

**Remember**: This directory is a **workspace for active validation**, not permanent storage. Keep it clean and focused on the 3 most critical items requiring user attention.