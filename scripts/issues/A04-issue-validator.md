# Issue A04: Issue Validator

**Phase:** A - Infrastructure Tools
**Type:** Tool
**Priority:** Medium
**Dependencies:** None

---

## Current Behavior

Issue files are created manually with no automated validation. Missing sections,
malformed acceptance criteria, or invalid dependency references go undetected.

---

## Intended Behavior

A project-abstract validation tool that:
- Checks all issues have required sections
- Validates acceptance criteria format
- Verifies dependency references exist
- Detects orphaned sub-issues
- Reports warnings and errors
- Works across any project following the issue convention

---

## Suggested Implementation Steps

1. **Create shared script**
   ```
   /home/ritz/programming/ai-stuff/scripts/issue-validator.sh
   ```
   Symlinked into projects as `src/cli/issue-validator.sh`

2. **Define validation rules**
   ```bash
   # Required sections (configurable)
   REQUIRED_SECTIONS=(
       "Current Behavior"
       "Intended Behavior"
       "Suggested Implementation Steps"
       "Acceptance Criteria"
   )

   # Optional but recommended sections
   RECOMMENDED_SECTIONS=(
       "Related Documents"
       "Notes"
       "Technical Notes"
   )

   # Header fields
   REQUIRED_FIELDS=(
       "Phase"
       "Type"
       "Priority"
   )
   ```

3. **Implement section detection**
   ```bash
   # {{{ check_sections
   check_sections() {
       local file="$1"
       local missing=()

       for section in "${REQUIRED_SECTIONS[@]}"; do
           if ! grep -q "^## $section" "$file"; then
               missing+=("$section")
           fi
       done

       echo "${missing[@]}"
   }
   # }}}
   ```

4. **Implement acceptance criteria validation**
   ```bash
   # {{{ validate_acceptance_criteria
   validate_acceptance_criteria() {
       local file="$1"
       local errors=()

       # Extract acceptance criteria section
       local in_section=false
       local criteria_count=0

       while IFS= read -r line; do
           if [[ "$line" =~ ^##\ Acceptance\ Criteria ]]; then
               in_section=true
               continue
           fi

           if [[ "$in_section" == true ]]; then
               if [[ "$line" =~ ^## ]]; then
                   break
               fi

               # Check for checkbox format
               if [[ "$line" =~ ^-\ \[.\] ]]; then
                   ((criteria_count++))

                   # Validate checkbox format
                   if ! [[ "$line" =~ ^-\ \[(\ |x|X)\]\  ]]; then
                       errors+=("Malformed checkbox: $line")
                   fi
               fi
           fi
       done < "$file"

       if [[ $criteria_count -eq 0 ]]; then
           errors+=("No acceptance criteria found")
       fi

       echo "${errors[@]}"
   }
   # }}}
   ```

5. **Implement dependency validation**
   ```bash
   # {{{ validate_dependencies
   validate_dependencies() {
       local file="$1"
       local issues_dir="$2"
       local errors=()

       # Extract dependencies line
       local deps=$(grep -oP "(?<=Dependencies:\*\*\s).*" "$file")

       if [[ -n "$deps" ]]; then
           # Parse dependency IDs
           for dep in $(echo "$deps" | tr ',' '\n' | tr -d ' '); do
               # Skip "None" or phase references
               if [[ "$dep" == "None" ]] || [[ "$dep" =~ ^Phase ]]; then
                   continue
               fi

               # Check if dependency file exists
               local found=false
               for issue_file in "$issues_dir"/*.md "$issues_dir"/completed/*.md; do
                   if [[ "$(basename "$issue_file")" =~ ^$dep ]]; then
                       found=true
                       break
                   fi
               done

               if [[ "$found" == false ]]; then
                   errors+=("Missing dependency: $dep")
               fi
           done
       fi

       echo "${errors[@]}"
   }
   # }}}
   ```

6. **Implement sub-issue validation**
   ```bash
   # {{{ validate_subissues
   validate_subissues() {
       local issues_dir="$1"
       local errors=()

       # Find sub-issues (e.g., 102a, 102b)
       for subissue in "$issues_dir"/*[a-z]-*.md; do
           [[ -e "$subissue" ]] || continue

           local basename=$(basename "$subissue" .md)
           # Extract parent ID (e.g., 102 from 102a)
           local parent_id=$(echo "$basename" | grep -oP "^\d+")

           # Check parent exists
           local parent_found=false
           for parent in "$issues_dir"/${parent_id}-*.md; do
               if [[ -e "$parent" ]] && ! [[ "$parent" =~ [a-z]-.*\.md$ ]]; then
                   parent_found=true
                   break
               fi
           done

           if [[ "$parent_found" == false ]]; then
               errors+=("Orphaned sub-issue: $basename (no parent $parent_id)")
           fi
       done

       echo "${errors[@]}"
   }
   # }}}
   ```

7. **Implement naming convention check**
   ```bash
   # {{{ validate_naming
   validate_naming() {
       local file="$1"
       local basename=$(basename "$file" .md)
       local errors=()

       # Expected: {PHASE}{ID}-{description}
       # e.g., 204-parse-war3map-w3c
       if ! [[ "$basename" =~ ^[A-Z0-9]+[0-9]+-[a-z0-9-]+$ ]]; then
           errors+=("Non-standard filename: $basename")
       fi

       echo "${errors[@]}"
   }
   # }}}
   ```

8. **Implement report generation**
   ```bash
   # {{{ generate_report
   generate_report() {
       local issues_dir="$1"

       echo "╔════════════════════════════════════════════════════════════╗"
       echo "║               ISSUE VALIDATION REPORT                      ║"
       echo "╠════════════════════════════════════════════════════════════╣"

       local total_issues=0
       local valid_issues=0
       local warning_count=0
       local error_count=0

       for issue in "$issues_dir"/*.md; do
           [[ -e "$issue" ]] || continue
           ((total_issues++))

           local name=$(basename "$issue")
           local has_errors=false

           # Run all validations
           local missing_sections=$(check_sections "$issue")
           local criteria_errors=$(validate_acceptance_criteria "$issue")
           local dep_errors=$(validate_dependencies "$issue" "$issues_dir")
           local naming_errors=$(validate_naming "$issue")

           if [[ -n "$missing_sections" ]] || [[ -n "$criteria_errors" ]] ||
              [[ -n "$dep_errors" ]] || [[ -n "$naming_errors" ]]; then
               has_errors=true
               printf "║ ✗ %-56s ║\n" "$name"

               for error in $missing_sections; do
                   printf "║   └─ Missing: %-42s ║\n" "$error"
                   ((error_count++))
               done
               # ... other errors
           else
               ((valid_issues++))
               printf "║ ✓ %-56s ║\n" "$name"
           fi
       done

       echo "╠════════════════════════════════════════════════════════════╣"
       printf "║ Valid: %d/%d | Errors: %d | Warnings: %d                  ║\n" \
           $valid_issues $total_issues $error_count $warning_count
       echo "╚════════════════════════════════════════════════════════════╝"
   }
   # }}}
   ```

9. **Add CLI interface**
   ```bash
   # Modes:
   # -a, --all           Validate all issues
   # -f, --file FILE     Validate specific file
   # -q, --quiet         Only show errors
   # -v, --verbose       Show all checks
   # --fix               Auto-fix simple issues (add missing sections)
   # --json              Output JSON report
   # -I, --interactive   TUI mode
   ```

---

## Library Design

```bash
# As CLI
./issue-validator.sh -a

# As library
source /path/to/scripts/issue-validator.sh
issue_validator_init "$PROJECT_DIR"
errors=$(issue_validator_check_file "$file")
issue_validator_generate_report "$issues_dir"
```

### Exported Functions

| Function | Description |
|----------|-------------|
| `issue_validator_init` | Initialize with project directory |
| `issue_validator_check_sections` | Check for required sections |
| `issue_validator_check_criteria` | Validate acceptance criteria |
| `issue_validator_check_deps` | Validate dependency references |
| `issue_validator_check_naming` | Validate naming convention |
| `issue_validator_check_file` | Run all checks on a file |
| `issue_validator_generate_report` | Generate validation report |

---

## Output Example

```
╔════════════════════════════════════════════════════════════╗
║               ISSUE VALIDATION REPORT                      ║
╠════════════════════════════════════════════════════════════╣
║ ✓ 201-parse-war3map-doo.md                                 ║
║ ✓ 202-parse-war3map-units-doo.md                           ║
║ ✗ 203-parse-war3map-w3r.md                                 ║
║   └─ Missing: Related Documents                            ║
║ ✓ 204-parse-war3map-w3c.md                                 ║
║ ✗ 999-test-issue.md                                        ║
║   └─ Missing dependency: 998                               ║
║   └─ Non-standard filename                                 ║
╠════════════════════════════════════════════════════════════╣
║ Valid: 3/5 | Errors: 3 | Warnings: 0                       ║
╚════════════════════════════════════════════════════════════╝
```

---

## Related Documents

- CLAUDE.md (issue format requirements)
- issues/ (validation targets)
- /home/ritz/programming/ai-stuff/scripts/ (shared scripts)
- Issue A02 (progress dashboard - complementary)

---

## Acceptance Criteria

- [ ] Script lives in shared scripts directory
- [ ] Symlink created in project src/cli/
- [ ] Checks for required sections
- [ ] Validates acceptance criteria format
- [ ] Validates dependency references
- [ ] Detects orphaned sub-issues
- [ ] Validates naming convention
- [ ] Generates clear error report
- [ ] Supports quiet/verbose modes
- [ ] JSON output option
- [ ] Works as both CLI and library
- [ ] Project-abstract configuration

---

## Notes

This tool ensures issue quality and consistency. Run it as a pre-commit
hook or CI step to catch issues early.

Consider adding an `--fix` mode that can automatically add missing
sections with template content.

Could integrate with issue-splitter.sh to validate generated sub-issues.
