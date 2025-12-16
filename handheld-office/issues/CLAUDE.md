# Issue Resolution Workflow for Claude

This document provides comprehensive guidance for working on issues in the Handheld Office project, including testing, validation, and documentation processes.

## 📁 **Issue Directory Structure**

### **Core Documentation Files**
- **README.md**: Overview and active/pending issues
- **COMPLETED.md**: All resolved issues and major achievements
- **TASKS.md**: Unified task list with dependencies and critical path planning
- **CLAUDE.md** (this file): Issue workflow and resolution process

### **Issue Files**
- **Individual Issues**: `###-issue-name.md` files with detailed descriptions
- **done/**: Archive of resolved issues (moved after completion)

### **File Naming Conventions**
- **Active**: `003-test-runner-binary-missing.md`
- **Resolved**: `done/003-test-runner-binary-missing-resolved.md`

## 🔄 **Issue Resolution Workflow**

### **Phase 1: Issue Selection and Analysis**

#### **1.1 Choose an Issue**
```bash
# Read the TASKS.md for strategic overview and critical path
less issues/TASKS.md

# Read the README.md for current priorities  
less issues/README.md

# Look for issues marked as:
# - High impact on critical path (check dependency matrix)
# - No blocking dependencies (can start immediately)
# - Clear scope and requirements
# - Matching current development capacity
```

#### **1.2 Understand the Issue**
- Read the complete issue description in `###-issue-name.md`
- Check **Problem**, **Impact**, and **Suggested Fixes** sections
- Identify affected files and systems
- Determine if issue has dependencies on other unresolved issues

#### **1.3 Validate Issue Status**
- Confirm the issue still exists (not already resolved)
- Check if partial work has been done
- Verify the issue scope matches current project state

### **Phase 2: Implementation and Testing**

#### **2.1 Create Implementation Plan**
Use TodoWrite tool to track implementation steps:
```bash
# Example todo structure
- Analyze affected files and scope
- Implement core changes
- Test changes work as expected
- Update documentation
- Update issue tracking files
- Move issue to done folder
```

#### **2.2 Implement Changes**
- Make minimal, focused changes that directly address the issue
- Follow existing code conventions and patterns
- Preserve security architecture (air-gapped P2P requirements)
- Document any design decisions in the issue file

#### **2.3 Testing and Validation**

**For Code Changes:**
```bash
# Compilation check
cargo check --lib

# Run relevant tests
cargo test [module_name]

# Full test suite (if safe)
cargo test --lib --release

# Cross-compilation check (for Anbernic compatibility)
cargo check --target armv7-unknown-linux-gnueabihf
```

**For Documentation Changes:**
- Verify all examples compile and work
- Check internal links are functional
- Confirm instructions are accurate and complete
- Test any shell commands or procedures

**For Configuration Changes:**
- Test that new configuration works as expected
- Verify backward compatibility where required
- Document any breaking changes

### **Phase 3: Issue Resolution Documentation**

#### **3.1 Update the Issue File**
Add a **Resolution** section to the issue file:

```markdown
## Resolution ✅ **COMPLETED**

**Date**: YYYY-MM-DD  
**Resolution**: Brief description of chosen solution

### Changes Made
1. **File/Line**: Specific change description
2. **File/Line**: Another change description

### Benefits
- ✅ Specific improvement
- ✅ Another benefit
- ✅ Verification that issue is resolved

**Implemented by**: Claude Code  
**Verification**: How the fix was validated
```

#### **3.2 Update Issue Tracking Files**

**Update TASKS.md (Unified Task List):**
- Mark the issue as completed in progress tracking section
- Update dependency matrix (issues that were blocked can now proceed)
- Update completion metrics and milestone progress
- Remove from active critical path if applicable
- Update velocity tracking with actual vs. estimated effort

**Update README.md (Active Issues):**
- Remove the resolved issue from active issue lists
- Update issue counts in the status overview
- Update "Last Updated" date
- Update any priority classifications

**Update COMPLETED.md (Resolved Issues):**
- Add the issue to the appropriate completed section
- Include resolution date and key details
- Update achievement statistics
- Add to timeline if it's a significant milestone

### **Phase 4: Archive and Cleanup**

#### **4.1 Move Issue to Done Folder**
```bash
# IMPORTANT: Use git mv to preserve file history and ensure proper tracking
git mv issues/003-issue-name.md issues/done/003-issue-name-resolved.md
```

**⚠️ Critical Note**: Always use `git mv` instead of regular `mv` commands to:
- Preserve file history and git tracking
- Maintain proper timeline of updates
- Enable git tools to track file movement correctly
- Ensure version control integrity

#### **4.2 Verify Documentation Links**
- Check that all references to the issue are updated
- Verify no broken links to the moved file
- Update any cross-references in other issues

## 🎯 **Issue Types and Specific Guidelines**

### **Documentation Issues**
- **Testing**: Verify all examples work as documented
- **Validation**: Check that instructions are clear and complete
- **Special Focus**: Ensure documentation matches current codebase state

### **Code Implementation Issues**
- **Testing**: Comprehensive compilation and functionality tests
- **Validation**: Verify the fix doesn't break existing functionality
- **Special Focus**: Follow security architecture (air-gapped P2P)

### **Architecture Compliance Issues**
- **Testing**: Review against ARCHITECTURE.md requirements
- **Validation**: Ensure consistency across all documentation
- **Special Focus**: Air-gapped handheld device requirements

### **Integration Issues**
- **Testing**: Test interaction between modified components
- **Validation**: Verify end-to-end workflows still function
- **Special Focus**: P2P networking and crypto system integration

## 📊 **Quality Assurance Standards**

### **Before Marking as Resolved**
- [ ] Issue requirements completely addressed
- [ ] All affected code compiles without errors
- [ ] Related tests pass (if applicable)
- [ ] Documentation is accurate and complete
- [ ] No regression in existing functionality
- [ ] Security architecture preserved
- [ ] Changes tested on target platforms (if relevant)

### **Documentation Update Checklist**
- [ ] Issue file updated with resolution details
- [ ] TASKS.md updated (progress tracking, dependencies, metrics)
- [ ] README.md updated (removed from active issues)
- [ ] COMPLETED.md updated (added to resolved issues)
- [ ] Issue moved to done/ folder with "-resolved" suffix
- [ ] All cross-references updated
- [ ] No broken links created

### **Code Quality Standards**
- [ ] Follows existing code conventions
- [ ] Preserves air-gapped P2P architecture
- [ ] No external API calls from Anbernic devices
- [ ] Proper error handling implemented
- [ ] Security best practices followed
- [ ] Performance impact considered

## 🚀 **Advanced Workflow Techniques**

### **Working with Partially Resolved Issues**
Some issues are marked "⚠️ *Partially Resolved*" meaning core architecture is implemented but integration work remains:

1. **Understand existing architecture**: Review implemented bytecode interface, crypto system, etc.
2. **Focus on integration**: Connect existing systems rather than reimplementing
3. **Preserve architecture**: Don't modify the air-gapped P2P foundation
4. **Update status carefully**: May transition from "Partially Resolved" to "Completed"

### **Handling Complex Dependencies**
When an issue depends on other unresolved issues:

1. **Identify dependencies**: List prerequisite issues that must be resolved first
2. **Consider partial solutions**: Implement what's possible without dependencies
3. **Document limitations**: Note what requires other issues to be resolved
4. **Update dependencies**: As prerequisites are resolved, return to complete the issue

### **Cross-System Validation**
For issues affecting multiple components:

1. **Component isolation**: Test each affected component independently
2. **Integration testing**: Verify components work together correctly
3. **End-to-end validation**: Test complete user workflows
4. **Performance impact**: Measure any performance changes

## ⚡ **Efficiency Tips**

### **Issue Selection Strategy**
- **Start isolated**: Choose issues with minimal dependencies
- **Documentation first**: Documentation issues are often safest to begin with
- **Build momentum**: Complete easier issues to build familiarity with codebase
- **Critical path**: Focus on issues blocking other development

### **Time Management**
- **Set clear scope**: Define exactly what will be considered "resolved"
- **Track progress**: Use TodoWrite tool to maintain visible progress
- **Time box work**: Set reasonable limits for investigation and implementation
- **Ask for clarification**: If issue scope is unclear, document assumptions

### **Testing Efficiency**
- **Minimal viable testing**: Focus tests on areas directly affected by changes
- **Incremental verification**: Test changes as you make them, not just at the end
- **Automated where possible**: Use `cargo test` and `cargo check` liberally
- **Target platform consideration**: Remember ARM/Anbernic compatibility

## 🎓 **Learning and Improvement**

### **Document Lessons Learned**
When resolving complex issues, add notes to help future development:

- **Design decisions**: Why certain approaches were chosen
- **Alternative approaches**: What was considered but not implemented
- **Future improvements**: Opportunities for enhancement identified
- **Gotchas**: Unexpected challenges or solutions

### **Process Improvement**
This workflow document should evolve based on experience:

- **Update procedures**: Improve workflow based on lessons learned
- **Add techniques**: Document effective approaches discovered
- **Clarify ambiguities**: Add detail where process was unclear
- **Share knowledge**: Help other contributors work effectively

## 📊 **TASKS.md Maintenance**

### **When to Update TASKS.md**
The unified task list requires regular maintenance to remain accurate and useful:

#### **After Issue Resolution** (Required)
```bash
# Update completion status
- Mark issue as completed in progress tracking
- Update completion metrics (e.g., Foundation Progress: 1/3 complete)
- Record actual vs. estimated effort in velocity tracking
- Update milestone progress if applicable

# Update dependencies
- Remove completed issue from "Blocks" lists of other issues
- Mark previously blocked issues as ready to start
- Update dependency matrix status
```

#### **When Starting an Issue** (Recommended)
```bash
# Update current work status
- Note which issue is currently in progress
- Update estimated timeline based on actual start date
- Mark dependent issues as "waiting" if needed
```

#### **Weekly Planning Review** (Recommended)
```bash
# Review and adjust priorities
- Update effort estimates based on learning
- Adjust critical path if dependencies change
- Re-evaluate milestone timelines
- Update completion percentages
```

### **TASKS.md Update Templates**

#### **Issue Completion Update**
```markdown
### **Progress Tracking**
- **Foundation Progress**: 1/3 issues complete (33%) <- UPDATE
- **Integration Progress**: 0/4 issues complete (0%)
- **Feature Progress**: 0/2 issues complete (0%)
- **Overall Progress**: 1/9 issues complete (11%) <- UPDATE

### **Velocity Tracking**  
| Week | Planned Issues | Completed Issues | Effort Variance | Notes |
|------|----------------|------------------|-----------------|-------|
| Week 1 | #015, #017, #018 | #015 ✅ | -0.5 days | Faster than expected |
```

#### **Dependency Matrix Update**
```markdown
| Issue | Depends On | Blocks | Can Start | Status |
|-------|------------|--------|-----------|---------|
| #015  | None       | #007, #008, #017, #018, #004 | ✅ ~~Now~~ DONE | ✅ Completed |
| #017  | ~~#015~~ ✅ | #004   | ✅ Ready | Ready to start |
```

### **Critical Path Management**
When an issue on the critical path is completed:

1. **Update path status**: Mark completion and update timeline
2. **Unblock dependent work**: Update status of issues that can now proceed  
3. **Re-evaluate priorities**: Check if critical path has changed
4. **Communicate readiness**: Note which issues are now ready to start

## 🔗 **Integration with Project Workflow**

### **Relationship to Project Documentation**
- **Root CLAUDE.md**: Contains overall project vision and principles
- **Issues CLAUDE.md** (this file): Specific workflow for issue resolution
- **TASKS.md**: Strategic planning and dependency management
- **README.md**: Current status and active issue overview
- **COMPLETED.md**: Historical achievements and lessons learned
- **Coordination**: Ensure issue resolution aligns with project vision and critical path

### **Git and Version Control**
```bash
# Recommended git workflow for issue resolution

# Step 1: Backup conversations (run from project root)
source ./scripts/backup-conversations && backup-conversations

# Step 2: Stage and commit changes
git add [modified files]
git commit -m "Resolve Issue #003: Brief description

- Specific change 1
- Specific change 2

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

**⚠️ File Movement Guidelines**:
- **ALWAYS use `git mv`** instead of regular `mv` for any file operations
- **NEVER use plain `mv`** as it breaks git history tracking
- **Apply to all scenarios**: renaming files, moving to different directories, reorganizing structure
- **Benefits**: Preserves commit history, maintains file lineage, enables proper git blame/log tracking

### **Build System Integration**
- **Cargo configuration**: Use optimized `.cargo/config.toml` settings
- **Target directory**: Build artifacts go to `files/target/`
- **Cross-compilation**: Test ARM compatibility when relevant

---

## 📞 **Support and Questions**

For questions about this workflow or specific issue resolution challenges:

1. **Check existing issues**: Similar problems may have been solved before
2. **Review COMPLETED.md**: Learn from previous successful resolutions
3. **Document uncertainties**: Add notes to issue files for future reference
4. **Iterate and improve**: This workflow evolves with project needs

**Remember**: The goal is consistent, high-quality issue resolution that maintains the project's air-gapped P2P architecture while enabling continued development and improvement.