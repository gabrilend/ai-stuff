# Issue 032: Project Donation/Support Links System

## Current Behavior

No mechanism exists for supporters to indicate which projects they find most valuable or interesting. Donation platforms typically aggregate all contributions into a single pool, losing the signal of supporter interest in specific projects.

## Intended Behavior

Implement a multi-link donation/support system that allows supporters to:
1. **Split donations** across multiple projects according to their interest
2. **Signal attention** to specific projects without obligating the developer to prioritize them
3. **Choose allocation** freely among all available projects in the collection

### Philosophy

Attention can be a powerful motivator, but this system explicitly **does not** create any obligation for the developer to follow funding signals. Supporters can choose how to allocate their contributions to express interest, but the developer maintains complete creative autonomy over which projects receive development time.

This is about providing a feedback mechanism, not a directive one.

## Suggested Implementation Steps

### 1. Support Link Configuration Format
Define a configuration format for project support links:
```yaml
# In project metadata or dedicated support-links.yaml
support:
  enabled: true
  description: "Support this project's development"
  links:
    - platform: github-sponsors
      url: https://github.com/sponsors/username?project=project-name
      label: "GitHub Sponsors"
    - platform: ko-fi
      url: https://ko-fi.com/username
      label: "Ko-fi"
    - platform: patreon
      url: https://patreon.com/username
      tier_tag: project-name
      label: "Patreon"
    - platform: custom
      url: https://example.com/donate
      label: "Direct Donation"
```

### 2. Project-Level Support Files
Create support configuration in each project:
```
project-name/
├── SUPPORT.md          # Human-readable support information
└── .support.yaml       # Machine-readable configuration (optional)
```

**SUPPORT.md Format:**
```markdown
# Supporting This Project

If you find this project useful or interesting, consider supporting its development.

## Donation Options
- [GitHub Sponsors](https://github.com/sponsors/...)
- [Ko-fi](https://ko-fi.com/...)
- [Patreon](https://patreon.com/...)

## Note
Your support signals interest but doesn't obligate any particular development direction.
I work on projects that inspire me - your contribution is appreciated as encouragement,
not as a contract.
```

### 3. Aggregation System
Create a delta-version utility to aggregate and display support options:
```bash
#!/bin/bash
# scripts/list-support-links.sh
# Discovers and aggregates support links across all projects

# Features:
# - Scan all projects for SUPPORT.md or .support.yaml
# - Generate unified support page/listing
# - Provide statistics on which projects have support configured
# - Output formats: markdown, HTML, JSON
```

### 4. Support Link Discovery
Integrate with existing project listing utility (Issue 023):
```bash
# Extend list-projects.sh with support link discovery
./list-projects.sh --with-support-links
./list-projects.sh --format json --include support

# Example output:
# {
#   "name": "adroit",
#   "path": "/home/ritz/programming/ai-stuff/adroit",
#   "support": {
#     "enabled": true,
#     "links": [...]
#   }
# }
```

### 5. Unified Support Page Generator
Create a script to generate a unified support/donation page:
```bash
# scripts/generate-support-page.sh
# Generates HTML or Markdown page listing all project support options

# Output: A single page where supporters can:
# - See all projects at a glance
# - Read brief descriptions
# - Choose which project(s) to support
# - Access platform-specific links
```

### 6. Statistics and Reporting (Optional)
If platforms provide APIs, aggregate donation statistics:
- Track which projects receive attention
- Generate interest reports (for developer reference only)
- Visualize support distribution

## Integration Points

### With Project Metadata System (Issue 026)
Support links can be stored as part of project metadata:
```yaml
metadata:
  name: "Project Name"
  description: "..."
  support:
    enabled: true
    links: [...]
```

### With Repository README
Generate support section for main README:
```markdown
## Support These Projects

| Project | Description | Support |
|---------|-------------|---------|
| adroit | AI assistant | [Support](link) |
| progress-ii | Game engine | [Support](link) |
```

## Configuration File Specification

### .support.yaml Schema
```yaml
# Required fields
enabled: boolean        # Whether support is enabled for this project

# Optional fields
description: string     # Custom description for supporters
message: string         # Thank you / philosophy message
links:                  # Array of support link objects
  - platform: string    # Platform identifier
    url: string         # Full URL to support page
    label: string       # Display label
    tier_tag: string    # Optional: platform-specific tag for tracking
```

### Supported Platforms
- `github-sponsors` - GitHub Sponsors
- `ko-fi` - Ko-fi
- `patreon` - Patreon
- `liberapay` - Liberapay
- `open-collective` - Open Collective
- `buymeacoffee` - Buy Me a Coffee
- `paypal` - PayPal.me
- `custom` - Any custom URL

## Acceptance Criteria

- [ ] Support link configuration format defined and documented
- [ ] SUPPORT.md template created for projects
- [ ] Discovery script finds support configurations across all projects
- [ ] Aggregation utility generates unified support listing
- [ ] Integration with project listing utility completed
- [ ] At least one project has support links configured as example

## Related Issues

- 023-create-project-listing-utility.md - Base utility for project discovery
- 026-project-metadata-system.md - Metadata storage integration
- 024-external-project-directory-configuration.md - Multi-directory support

## Metadata

- **Priority**: Low (enhancement, not core functionality)
- **Complexity**: Low-Medium
- **Estimated Time**: 2-3 hours
- **Dependencies**: Issue 023 (project listing utility)
- **Impact**: Supporter engagement, feedback mechanism

## Notes

This system is explicitly designed as a **signal** mechanism, not a **directive** one. The developer retains complete autonomy over project priorities regardless of support distribution. This distinction should be clearly communicated to potential supporters.

The philosophy section in SUPPORT.md files is important - it sets expectations that support is appreciation and encouragement, not a service contract or feature request system.
