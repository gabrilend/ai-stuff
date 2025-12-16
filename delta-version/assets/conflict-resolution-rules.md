# Conflict Resolution Rules for Gitignore Unification

## Rule Hierarchy (Highest to Lowest Priority)

### 1. Security Patterns
- **Rule**: Never ignore security-sensitive files
- **Examples**: `*.key`, `*.pem`, `.env`, `secrets.json`
- **Resolution**: Always include, never override

### 2. Critical Build Artifacts
- **Rule**: Always ignore compiled/generated files
- **Examples**: `*.o`, `*.exe`, `target/`, `build/`
- **Resolution**: Include in universal section

### 3. Project-Specific Requirements
- **Rule**: Most restrictive pattern wins
- **Example**: If Project A needs `logs/` ignored but Project B needs `logs/important/` tracked
- **Resolution**: Use `logs/*` + `!logs/important/`

### 4. Universal Patterns
- **Rule**: Broad applicability patterns
- **Examples**: `.DS_Store`, `.vscode/`, `Thumbs.db`
- **Resolution**: Include in universal sections

### 5. Library Dependencies
- **Rule**: Lowest precedence, document only
- **Resolution**: Reference section only unless needed for main projects

## Specific Conflict Types

### Negation Conflicts
```
Pattern: *.log
Negation: !important.log
Resolution: Include both in order - negation overrides general rule
```

### Directory vs File Conflicts
```
File pattern: build
Directory pattern: build/
Resolution: Use directory pattern (build/) - more specific
```

### Scope Conflicts
```
Local: node_modules/
Recursive: **/node_modules/
Resolution: Use recursive pattern - covers all cases
```

### Specificity Conflicts
```
General: *.tmp
Specific: cache.tmp
Resolution: Keep general pattern only - specific is redundant
```

## Implementation Notes

- Apply rules in hierarchy order
- Document all resolution decisions
- Maintain attribution for troubleshooting
- Test resolved patterns against project files
