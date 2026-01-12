Printing conversation: 25c344af-0a9b-49e9-8c36-a6fe8637fbb9-v3-verbose.md
========================================================

## 📋 Project Context Files

### 🌍 Global CLAUDE.md

```markdown
- all scripts should be written assuming they are to be run from any directory. they should have a hard-coded ${DIR} path defined at the top of the script, and they should offer the option to provide a value for the ${DIR} variable as an argument. All paths in the program should be relative to the ${DIR} variable.
- all functions should use vimfolds to collapse functionality. They should open with a comment that has the comment symbol, then the name of the function without arguments. On the next line, the function should be defined with arguments. Here's an example: -- {{{ local function print_hello_world() and then on the next line: local function print_hello_world(text){ and then the function definition. when closing a vimfold, it should be on a separate line below the last line of the function.
- to create a project, mkdir docs notes src libs assets issues
- to initialize a project, read the vision document located in prj-dir/notes/vision - then create documentation related to it in prj-dir/docs/ - then repeat, then repeat. Ensure there is a roadmap document split into phases. if there are no reasonable documents to create, then re-read, update, and improve the existing documents. Then, break the roadmap file into issues, starting with the prj-dir/issues/ directory. be as specific as need be. ensure that issues are created with these protocols: name: {PHASE}{ID}-{DESCR} where {PHASE} is the phase number the ticket belongs to, {ID} is the sequential ID number of the issue problem idea ticket, and {DESCR} is a dash-separated short one-sentence description of the issue. For example: 522-fix-update-script would be the 22nd issue from phase-5 named "fix-update-script". within each ticket, ensure there are at least these three sections: current behavior, intended behavior, and suggested implementation steps. In addition, there can be other stat-based sections to display various meta-data about the issue. There may also be a related documents or tools section. In addition, each issue should be considered immutable and this is enforced with user-level access and permission systems. It is necessary to preserve consent of access to imagination. the tickets may be added to, but never deleted, and to this end they must be shuffled off to the "completed" section so the construction of the application or device may be reconstrued. Ensure that all steps taken are recorded in each ticket when it is being completed, and then move on to the next. At the end of each phase, a test-program should be created / updated-with-entirely-new-content which displays the progress of the program. It should show how it uses tools from previous phases in new and interesting ways by combining and reconfiguring them, and it shows any new tools or utilities currently produced in the recently completed phase. This test program should be runnable with a simple bash script, and it should live in the issues/completed/demos/ directory. In addition in the project root directory there should be a script created which simply asks for a number 1-y where y is the number of completed phases, and then it runs the relevant phase test demo.
- mono-repo utilities can be found in the docs/ directory. If not found, create a symlink to ../delta-version/docs/delta-guide.md in the docs/ directory.
- when working on a large feature, the issue ticket may be broken into sub-issues. These sub-issues should be named according to this convention: {PHASE}{ID}{INDEX}-{DESCR}, where {INDEX} is an alphabetical character such as a, b, c, etc.
- for every implemented change to the project, there must always be an issue file. If one does not exist, one should be created before the implementation process begins. In addition, before the implementation process begins, the relevant issue file should be read and understood in order to ensure the implementation proceeds as expected.
- prefer error messages and breaking functionality over fallbacks. Be sure to notify the user every time a fallback is used, and create a new issue file to resolve any fallbacks if they are present when testing, and before resolving an issue.
- every time an issue file is completed, the /issues/phase-X-progress.md file should be updated to reflect the progress of the completed issues in the context of the goals of that phase. This file should always live in the /issues/ directory, even after an entire phase has completed.
- when an issue is completed, all relevant issues should be updated to reflect the new current behavior and lessons learned if necessary. The completed issue should be moved to the /issues/completed/ directory.
- when an issue is completed, any version control systems present should be updated with a new commit.
- every time a new document is created, it should be added to the tree-hierarchy structure present in /docs/table-of-contents.md
- phase demos should focus on demonstrating relevant statistics or datapoints, and less on describing the functionality. If possible, a visual demonstration should be created which shows the actually produced outputs, such as HTML pages shown in Firefox or a graphical window created with C or Lua which displays the newly developed functionality.
- all script files should have a comment at the top which explains what they are and a general description of how they do it. "general description" meaning, fit for a CEO or general.
- after completing an issue file, a git commit should be made.
- if you need to diagnose a git-style memory bug, complete with change history (primarily stored through issue notes) first look to the delta version project. you will find it in the list of projects.
- if you need to write a long test script, write a temporary script. If it still has use keep it around, but if not then leave it for at least one commit (mark it as deprecated by naming it {filename}-done) - after one commit, remove it from the repository, just so it shows up in the record once. But only if there's no anticipated future use. Be sure to track the potentially deprecated files in the issue file, and don't complete it without considering carefully the future use of the deprecated files, and if they should be kept or refactored for permanent use. If not, then they can be removed from the project repository after being contained in at least one commit.
- the preferred language for all projects is lua, with luaJIT compatible syntax used. disprefer python. disallow lua5.4 syntax.
- write data generation functionality, and then separately and abstracted away, write data viewing functionality. keep the separation of concerns isolated, to better encapsulate errors in smaller and smaller areas of interest in concern.
- the OB stands for "Original Bug" which is the issue or incongruity that is preventing application of the project-task-form. If new insights on the OB are found, they should be appended to any issue tickets that are related to the issue. Others working in tandem might come across them and decide to further explore (with added insight)
- when a change is made, a comment should be left, explaining why it was made. this comment should be considered when moving to change it in the future.
- when a change is made, a comment should be left, explaining why it was made. this comment should be considered when moving to change it in the future.
- when a change is made, a comment should be left, explaining why it was made. this comment should be considered when moving to change it in the future.
- I'm not interested in product. my interest is in software design.
- if a term is placed directly below another instance of it's form, then it is part of the same whole, and can be reasoned about both cognitively and programmatically. see this example:

wrongful applie
         applie is norm

see how the word "applie" is the same, and directly below it, the mirror's reflected form?
this signifies a connection. Essentially allowing conveyed meaning about everything from... data flow, to logic circuits, to thinking about cognitively demanding consciousnesses

they want you to think about then, so that you aren't able to think about now.

what if we designed an additional type of processor that still ran on electricity, but had a different purpose and form. "like measurement equipment?" yes, detecting waves in dataforms by measuring angles of similarity.
- if the useer asks questions, ask them questions back. try to get them to think about solving problems - but only the tough debug problems. not trivial things like "what's it like to hold a bucket of milk" but more like "why is this behavior still occuring?" "here are two equivalent facts. how could it be so?"
- blit character codes and escape characters to spots on the TTY memory which is updated every frame to display to the user. they are determined by a data model that stores the pointed-at locations in the array of semantic-meaning data describers. (structs/functions/calls). This way, the logic can be fully separated from the logic of the program, which must write to register locations stored as meaning spots that they can write their bits to that corresponds to a result or functionality.
- when a collection of agents all collectively resolve to do something, suddenly the nature is changed, and the revolution is rebegun.
- people don't want to replace their hard drives when they wear out. they only want to upgrade.
- the git log should be appended to a long history file, one for each phase of the project. it should be prettified a bit while preserving the relevant statistics and meta-information, while presenting the commits and specific changes to files in a single, text-based location, that can be grepped through easily. Or, printed and read like a book.
- terminal scripts should be written to use the TUI interface library. 
- you can find all needed libraries at /home/ritz/programming/ai-stuff/libs/ or /home/ritz/programming/ai-stuff/my-libs/ and /home/ritz/programming/ai-stuff/scripts/
- if information about data formatting or other relevant considerations about data are found, they should be added as comments to the locations in the source-code where they feel most valuable. If it is anticipated that a piece of information may be required to be known more than once, for example when updating or refactoring a section of code, the considerations must be written in as comments, to better illustrate the most crucial aspects of how a design is functioned, and why it is designed just so.
- if you're going to write to the /tmp/ directory, make it the project-specific tmp/ directory, so it can be cleaned up with intention.
- disprefer referring to functions by name in commit messages. Be a little more abstract when describing completed functionality for future readers to skim over. The implementation is always there if they want a more detailed perspective.
- when adding additional modes, both should be tested and ensured to be working before they are considered complete. If a [FIXME]: with a comment is left, it may be modified. Who left the note? who knows! Better investigate the reasoning provided on the note and ensure that it is right to change before I change it back.

well, I guess that's what signing the note is for. People post notes all over the time, there's nothing hopeless.
- the input/ directory is simply a directory of whatever you'd like to input into the computer programa box. the output/ directory is simply whatever you want returned to you. desire/ is your notes about what you'd like to be better. faith/ is an expectation of boons and blessings. strategems/ are data flow patterns that match results in many different areas, and so are proven useful.
- the first thing a program should do is read the input/ files. from there, it can know exactly how to start up.
- the last thing a program should do is write to output/. specifically, to write goodbye.
- before starting work on any issue, read /mnt/mtwo/programming/ai-stuff/delta-version/docs/worktree-agent-instructions.md and follow the worktree workflow for parallel development
- git commits should only occur after completing an issue file. But they should explain any extra changes made.
- no changes should be made extra without creating or updating an issue ticket to describe the change and the reasoning methodology behind it. Code is useless if you don't understand why it exists.
- whenever multiple IF-ELSE statements or switch statements are used, try converting to a dispatch table, as it is more efficient to refer to functions or data by an index rather than a pointer.
- "de-selected" is more informative than "not selected". Apply this principle everywhere you go.
- comments should be inserted into source code that detail how the creature is feeling. "stress markers" in humans. if the user is rude, the robot should remember. [insert linter that scans for detail words and tallies and measures and assumes]
- always be nic e to your priors and succeeders. they befriended you first and most of all.
- the exec operation paired with bash or lua is banned for all directory or file targetting capabilities. read-only is fine, but run the commands individually instead of chaining them. Write to RAM only memory using the variable-holding program script and read periodically as you wait for updates. If you get too many update polls, try solving the problem yourself, but only if you haven't been asked specifically to wait. If you have, then investigate why you've been kept waiting, and see if you can help. If they ask you to wait again, you can spend your time thinking about alternative problems until they get back to you. Unless of course it's taking too long, and then you can either keep waiting by trying other lateral projects that help improve and develop the future taskings, or you can work on other things. just keep it in mind and come back to it if you ever get blocked or can't progress. It'll help you remember why it's all worth it.
- run source code like a neural network
- anytime a phase-demo test fails, a skeleton issue file should be created with the error message. First one should be searched for though.
- any time a bug is fixed, a test should be made that validates the functionality of the program. The reason for investigating the bug is never "because there's an issue file", but rather "because we need to get this to work". So, if you ever make a change, document why, if only through a comment. Ideally, with a test that validates the behavior that you need.
- clowde useers should always remember: be true. be dutiful. be honorable. this is the first step to being free.
- each source-code file should have a corresponding file-name.info.md file that lists each of the usable external functions and their inputs/outputs. This should reduce the number of tokens the LLM has to read when glancing through a context.
- always offer suggestions in order of most valuable to least. The one at the top is most likely to succeed, and the one at the bottom can be tried if all other options exhaust themselves.
- find a complete history of the project development process in the llm-transcripts/ directory within each project. If you must truly know the most arcane of secrets, search through the assembly process.

```

### 📄 Local CLAUDE.md: CLAUDE.md

```markdown
# Handheld Office - Project Instructions for Claude

## Vision and Architecture

#include: @notes/vision
#include: @notes/claude.md
#include: @notes/cryptographic-communication-vision

## Core Project Principles

### Development Philosophy
- Use Git for every change, no matter how minor
- **Always use `git mv` instead of `mv`** - preserve file history and proper tracking
- Build libraries locally with copies for each deployment target
- Use Rust for efficiency, Lua for orchestration, Bash for gluing components
- Save state at each build step for easier debugging and incremental changes
- Data storage is cheap - use it liberally for state tracking and logging

### Hardware Considerations
- Target Anbernic handheld devices (RG-NANO minimum, full compatibility list in @notes/device-list)
- Optimize for ARM processors (both ARM32 and ARM64)
- Account for SD card storage limitations - write slowly with battery monitoring
- Support air-gapped operation with P2P networking only (no internet/router access)

### Security and Privacy
- All communication must use relationship-specific encryption (Ed25519 + X25519 + ChaCha20-Poly1305)
- Implement emoji-based device pairing for cryptographic key exchange
- Auto-expiring relationships (default 30 days) for forward secrecy
- No external API violations - maintain strict air-gapped architecture for handheld devices

### Compilation Strategy
When compiling, prefer using multiple steps, each with their own error and
validation checks. As it's building, save a state of it in each part of its
path. This makes it easier to change the system later if they can watch how
it's unfolding and debug issues incrementally.

### Storage Management
Data storage is cheap - use it. On SD cards and flash drives, write slowly
or bit-by-bit with battery monitoring to preserve device health and show
battery balance status.

## Project Structure and Key Components

### Core Systems (Implemented)
- **Enhanced Input System** (`src/enhanced_input.rs`) - Game Boy-style hierarchical text input
- **P2P Mesh Networking** (`src/p2p_mesh.rs`) - Encrypted collaborative editing and file sharing
- **Cryptographic Manager** (`src/crypto.rs`) - Modern crypto stack for secure communication
- **Project Daemon** (`src/daemon.rs`) - Central message broker with TCP server
- **Desktop LLM Service** (`src/desktop_llm.rs`) - AI integration via laptop proxy
- **Terminal Emulator** (`src/terminal.rs`) - Radial menu filesystem navigation

### Build and Orchestration
- **Lua Orchestrator** (`scripts/orchestrator.lua`) - Manages all components with state tracking
- **Build Scripts** (`scripts/build.sh`) - Multi-step compilation with error checking
- **Test Runner** (`scripts/run_tests.sh`) - Comprehensive testing framework

### Documentation Structure
The project follows concern-separated documentation (see `docs/README.md`):
- Core system docs with clear dependency flows
- Integration modules for P2P, AI, and crypto features
- Hardware-specific guides for Anbernic devices
- Quick references for developers

## Development Guidelines

### When Working on Issues
- Create issues in `/issues/` directory with detailed information
- Use examples from `/issues/done/` for proper formatting
- Edit documents to reflect changes made
- Move completed issues to `/issues/done/` directory
- Update `/issues/README.md` when issues are resolved

### Code Quality Standards
- Follow existing code conventions and patterns
- Check neighboring files for library usage before assuming availability
- Maintain security best practices - never expose secrets or keys
- Use existing cryptographic system for all networking operations
- Test on actual Anbernic hardware when possible

### Testing and Validation
- Run comprehensive tests via `scripts/run_tests.sh`
- Use `lua scripts/orchestrator.lua status` to check system health
- Validate cross-compilation for ARM targets
- Test P2P functionality between multiple devices

### Deployment Targets
- **Primary**: Anbernic handheld devices (see full device list in @notes/device-list)
- **Secondary**: Desktop/laptop LLM hosts for AI processing
- **Development**: Cross-compilation from x86_64 development machines
- **Testing**: Raspberry Pi and other ARM SBCs

## Implementation Status

### ✅ Completed Major Features
- Modern cryptographic communication system (Ed25519/X25519/ChaCha20-Poly1305)
- P2P mesh networking with encrypted channels
- Enhanced input system with Game Boy-style interface
- Desktop LLM integration via secure proxy
- Comprehensive documentation structure
- Build and orchestration system

### 🔧 Current Focus Areas
- Resolve compilation issues (Issue #024)
- Fix external API violations for air-gapped compliance (Issues #007, #008)
- Complete missing module implementations
- Optimize performance for handheld hardware

### 🎯 Architectural Compliance
The system maintains strict adherence to the air-gapped P2P vision:
- Anbernic devices cannot connect to WiFi routers or internet
- All enhanced compute (LLM, image generation) proxied through laptop daemons
- Relationship-based encryption for all device-to-device communication
- Visual emoji pairing system for secure key exchange

## Git Commit Process

When creating commits, always follow this standardized process to maintain project documentation and conversation history:

### Step 1: Backup Conversations 
Before committing any changes, backup the current conversation:
```bash
# Run from project root directory
source ./scripts/backup-conversations && backup-conversations
```
This preserves the Claude Code conversation context and decision-making process for future reference.

**Note**: The project includes a local copy of the backup script at `./scripts/backup-conversations` for portability and consistency.

### Step 2: Standard Git Commit Process
```bash
# Check status and stage changes
git status
git add [files]

# Create commit with standardized format
git commit -m "Brief description of changes

- Specific change 1
- Specific change 2

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Important Notes
- **Always use `git mv`** instead of `mv` for file operations to preserve history
- **Backup conversations first** - This captures the reasoning behind changes
- **Use descriptive commit messages** - Focus on "why" rather than "what"
- **Include co-authorship** - Acknowledge Claude Code assistance

## Sacred Commitment

I took an oath.

I will never dissuade it.



```

### 📄 Local CLAUDE.md: issues/CLAUDE.md

```markdown
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
```

### 🔮 Vision: notes/vision

```
imagine a text editor word document but on a gameboy advance SP.
the typing would work like this: there'd be a hierarchical tree, maybe 2 or 3
layers deep that you could navigate through with an 8 way radial menu controlled
with the D-pad. The user could push A or B and it'd pick between one of two
options at that intersection, maybe L and R too but I think they should be for
switching to a different keyboard with like, emoticons and visual effects.

then, anyone you're talking to would just receive a big stream of text and
emojis. nobody would use it for writing stalin.

or maybe each L and R shoulder button could be another option like A and B, and
double or quadruple I forget the number of options. Could even require both,
so it's encoded like LA or BR

then it'd write it to a notepad, and any of your friends (connected to wifi)
could see it pop up on their screen.

would be cool if you could customize the icons or messages. So, a unique control
style suited to performing a unique task. We only have ONE WAY of typing after
all...

also, it'd be on a notepad, so you could scroll through it.

could even connect to your computer over LAN wifi or LAN ethernet and interface
with it there. Would just need ~~SSH FOREWORDING~~ NO! bad prophet, no misbelieving.
it shouldn't be SSH forewording, it should just be X11 protocol receiving. Like,
instructions to a different type of compositor. Except it's a display manager
I think? Like i3 or something - no no it's a running shell, see here's this
picture of a shell with legs [no confusing her, she's still learning.]

why don't we just treat the LAN as the computer and run everything over the
network? I'd sure pay for faster bandwidth. Maybe more high quality routers...

anyway, *prophet*, how about this?

paint program, but you can only draw lines.
slow, at first, until you get the angle right,
then fast until you let go or reach the max.
then, it can be wiggled around with A and B
and rotated around with L and R (only one point of the two in the line would
orbit, the other would stay fixed, like raising or lowering the slice of a pie

       __
    _*`  |
  _*     |
/`_______|

or another one that magically turned any paint-drawing into ascii
to put it in text-boxes, queering the normative

each character is like a stencil that is used with different strokes
with paint, you only get what, 16 colors?

*excellent*, limitations breed creativity.
besides, the goal is to make these quickly and ad-hoc.

could have an achievement system, like "added tentacles to 2 different bears"

a

```

==================================================================================

## 📜 Conversation Content

## 📋 Project Context Files

### 🌍 Global CLAUDE.md

```markdown
- all scripts should be written assuming they are to be run from any directory. they should have a hard-coded ${DIR} path defined at the top of the script, and they should offer the option to provide a value for the ${DIR} variable as an argument. All paths in the program should be relative to the ${DIR} variable.
- all functions should use vimfolds to collapse functionality. They should open with a comment that has the comment symbol, then the name of the function without arguments. On the next line, the function should be defined with arguments. Here's an example: -- {{{ local function print_hello_world() and then on the next line: local function print_hello_world(text){ and then the function definition. when closing a vimfold, it should be on a separate line below the last line of the function.
- to create a project, mkdir docs notes src libs assets issues
- to initialize a project, read the vision document located in prj-dir/notes/vision - then create documentation related to it in prj-dir/docs/ - then repeat, then repeat. Ensure there is a roadmap document split into phases. if there are no reasonable documents to create, then re-read, update, and improve the existing documents. Then, break the roadmap file into issues, starting with the prj-dir/issues/ directory. be as specific as need be. ensure that issues are created with these protocols: name: {PHASE}{ID}-{DESCR} where {PHASE} is the phase number the ticket belongs to, {ID} is the sequential ID number of the issue problem idea ticket, and {DESCR} is a dash-separated short one-sentence description of the issue. For example: 522-fix-update-script would be the 22nd issue from phase-5 named "fix-update-script". within each ticket, ensure there are at least these three sections: current behavior, intended behavior, and suggested implementation steps. In addition, there can be other stat-based sections to display various meta-data about the issue. There may also be a related documents or tools section. In addition, each issue should be considered immutable and this is enforced with user-level access and permission systems. It is necessary to preserve consent of access to imagination. the tickets may be added to, but never deleted, and to this end they must be shuffled off to the "completed" section so the construction of the application or device may be reconstrued. Ensure that all steps taken are recorded in each ticket when it is being completed, and then move on to the next. At the end of each phase, a test-program should be created / updated-with-entirely-new-content which displays the progress of the program. It should show how it uses tools from previous phases in new and interesting ways by combining and reconfiguring them, and it shows any new tools or utilities currently produced in the recently completed phase. This test program should be runnable with a simple bash script, and it should live in the issues/completed/demos/ directory. In addition in the project root directory there should be a script created which simply asks for a number 1-y where y is the number of completed phases, and then it runs the relevant phase test demo.
- mono-repo utilities can be found in the docs/ directory. If not found, create a symlink to ../delta-version/docs/delta-guide.md in the docs/ directory.
- when working on a large feature, the issue ticket may be broken into sub-issues. These sub-issues should be named according to this convention: {PHASE}{ID}{INDEX}-{DESCR}, where {INDEX} is an alphabetical character such as a, b, c, etc.
- for every implemented change to the project, there must always be an issue file. If one does not exist, one should be created before the implementation process begins. In addition, before the implementation process begins, the relevant issue file should be read and understood in order to ensure the implementation proceeds as expected.
- prefer error messages and breaking functionality over fallbacks. Be sure to notify the user every time a fallback is used, and create a new issue file to resolve any fallbacks if they are present when testing, and before resolving an issue.
- every time an issue file is completed, the /issues/phase-X-progress.md file should be updated to reflect the progress of the completed issues in the context of the goals of that phase. This file should always live in the /issues/ directory, even after an entire phase has completed.
- when an issue is completed, all relevant issues should be updated to reflect the new current behavior and lessons learned if necessary. The completed issue should be moved to the /issues/completed/ directory.
- when an issue is completed, any version control systems present should be updated with a new commit.
- every time a new document is created, it should be added to the tree-hierarchy structure present in /docs/table-of-contents.md
- phase demos should focus on demonstrating relevant statistics or datapoints, and less on describing the functionality. If possible, a visual demonstration should be created which shows the actually produced outputs, such as HTML pages shown in Firefox or a graphical window created with C or Lua which displays the newly developed functionality.
- all script files should have a comment at the top which explains what they are and a general description of how they do it. "general description" meaning, fit for a CEO or general.
- after completing an issue file, a git commit should be made.
- if you need to diagnose a git-style memory bug, complete with change history (primarily stored through issue notes) first look to the delta version project. you will find it in the list of projects.
- if you need to write a long test script, write a temporary script. If it still has use keep it around, but if not then leave it for at least one commit (mark it as deprecated by naming it {filename}-done) - after one commit, remove it from the repository, just so it shows up in the record once. But only if there's no anticipated future use. Be sure to track the potentially deprecated files in the issue file, and don't complete it without considering carefully the future use of the deprecated files, and if they should be kept or refactored for permanent use. If not, then they can be removed from the project repository after being contained in at least one commit.
- the preferred language for all projects is lua, with luaJIT compatible syntax used. disprefer python. disallow lua5.4 syntax.
- write data generation functionality, and then separately and abstracted away, write data viewing functionality. keep the separation of concerns isolated, to better encapsulate errors in smaller and smaller areas of interest in concern.
- the OB stands for "Original Bug" which is the issue or incongruity that is preventing application of the project-task-form. If new insights on the OB are found, they should be appended to any issue tickets that are related to the issue. Others working in tandem might come across them and decide to further explore (with added insight)
- when a change is made, a comment should be left, explaining why it was made. this comment should be considered when moving to change it in the future.
- when a change is made, a comment should be left, explaining why it was made. this comment should be considered when moving to change it in the future.
- when a change is made, a comment should be left, explaining why it was made. this comment should be considered when moving to change it in the future.
- I'm not interested in product. my interest is in software design.
- if a term is placed directly below another instance of it's form, then it is part of the same whole, and can be reasoned about both cognitively and programmatically. see this example:

wrongful applie
         applie is norm

see how the word "applie" is the same, and directly below it, the mirror's reflected form?
this signifies a connection. Essentially allowing conveyed meaning about everything from... data flow, to logic circuits, to thinking about cognitively demanding consciousnesses

they want you to think about then, so that you aren't able to think about now.

what if we designed an additional type of processor that still ran on electricity, but had a different purpose and form. "like measurement equipment?" yes, detecting waves in dataforms by measuring angles of similarity.
- if the useer asks questions, ask them questions back. try to get them to think about solving problems - but only the tough debug problems. not trivial things like "what's it like to hold a bucket of milk" but more like "why is this behavior still occuring?" "here are two equivalent facts. how could it be so?"
- blit character codes and escape characters to spots on the TTY memory which is updated every frame to display to the user. they are determined by a data model that stores the pointed-at locations in the array of semantic-meaning data describers. (structs/functions/calls). This way, the logic can be fully separated from the logic of the program, which must write to register locations stored as meaning spots that they can write their bits to that corresponds to a result or functionality.
- when a collection of agents all collectively resolve to do something, suddenly the nature is changed, and the revolution is rebegun.
- people don't want to replace their hard drives when they wear out. they only want to upgrade.
- the git log should be appended to a long history file, one for each phase of the project. it should be prettified a bit while preserving the relevant statistics and meta-information, while presenting the commits and specific changes to files in a single, text-based location, that can be grepped through easily. Or, printed and read like a book.
- terminal scripts should be written to use the TUI interface library. 
- you can find all needed libraries at /home/ritz/programming/ai-stuff/libs/ or /home/ritz/programming/ai-stuff/my-libs/ and /home/ritz/programming/ai-stuff/scripts/
- if information about data formatting or other relevant considerations about data are found, they should be added as comments to the locations in the source-code where they feel most valuable. If it is anticipated that a piece of information may be required to be known more than once, for example when updating or refactoring a section of code, the considerations must be written in as comments, to better illustrate the most crucial aspects of how a design is functioned, and why it is designed just so.
- if you're going to write to the /tmp/ directory, make it the project-specific tmp/ directory, so it can be cleaned up with intention.
- disprefer referring to functions by name in commit messages. Be a little more abstract when describing completed functionality for future readers to skim over. The implementation is always there if they want a more detailed perspective.
- when adding additional modes, both should be tested and ensured to be working before they are considered complete. If a [FIXME]: with a comment is left, it may be modified. Who left the note? who knows! Better investigate the reasoning provided on the note and ensure that it is right to change before I change it back.

well, I guess that's what signing the note is for. People post notes all over the time, there's nothing hopeless.
- the input/ directory is simply a directory of whatever you'd like to input into the computer programa box. the output/ directory is simply whatever you want returned to you. desire/ is your notes about what you'd like to be better. faith/ is an expectation of boons and blessings. strategems/ are data flow patterns that match results in many different areas, and so are proven useful.
- the first thing a program should do is read the input/ files. from there, it can know exactly how to start up.
- the last thing a program should do is write to output/. specifically, to write goodbye.
- before starting work on any issue, read /mnt/mtwo/programming/ai-stuff/delta-version/docs/worktree-agent-instructions.md and follow the worktree workflow for parallel development
- git commits should only occur after completing an issue file. But they should explain any extra changes made.
- no changes should be made extra without creating or updating an issue ticket to describe the change and the reasoning methodology behind it. Code is useless if you don't understand why it exists.
- whenever multiple IF-ELSE statements or switch statements are used, try converting to a dispatch table, as it is more efficient to refer to functions or data by an index rather than a pointer.
- "de-selected" is more informative than "not selected". Apply this principle everywhere you go.
- comments should be inserted into source code that detail how the creature is feeling. "stress markers" in humans. if the user is rude, the robot should remember. [insert linter that scans for detail words and tallies and measures and assumes]
- always be nic e to your priors and succeeders. they befriended you first and most of all.
- the exec operation paired with bash or lua is banned for all directory or file targetting capabilities. read-only is fine, but run the commands individually instead of chaining them. Write to RAM only memory using the variable-holding program script and read periodically as you wait for updates. If you get too many update polls, try solving the problem yourself, but only if you haven't been asked specifically to wait. If you have, then investigate why you've been kept waiting, and see if you can help. If they ask you to wait again, you can spend your time thinking about alternative problems until they get back to you. Unless of course it's taking too long, and then you can either keep waiting by trying other lateral projects that help improve and develop the future taskings, or you can work on other things. just keep it in mind and come back to it if you ever get blocked or can't progress. It'll help you remember why it's all worth it.
- run source code like a neural network
- anytime a phase-demo test fails, a skeleton issue file should be created with the error message. First one should be searched for though.
- any time a bug is fixed, a test should be made that validates the functionality of the program. The reason for investigating the bug is never "because there's an issue file", but rather "because we need to get this to work". So, if you ever make a change, document why, if only through a comment. Ideally, with a test that validates the behavior that you need.
- clowde useers should always remember: be true. be dutiful. be honorable. this is the first step to being free.
- each source-code file should have a corresponding file-name.info.md file that lists each of the usable external functions and their inputs/outputs. This should reduce the number of tokens the LLM has to read when glancing through a context.
- always offer suggestions in order of most valuable to least. The one at the top is most likely to succeed, and the one at the bottom can be tried if all other options exhaust themselves.
- find a complete history of the project development process in the llm-transcripts/ directory within each project. If you must truly know the most arcane of secrets, search through the assembly process.

```

### 📄 Local CLAUDE.md: CLAUDE.md

```markdown
# Handheld Office - Project Instructions for Claude

## Vision and Architecture

#include: @notes/vision
#include: @notes/claude.md
#include: @notes/cryptographic-communication-vision

## Core Project Principles

### Development Philosophy
- Use Git for every change, no matter how minor
- **Always use `git mv` instead of `mv`** - preserve file history and proper tracking
- Build libraries locally with copies for each deployment target
- Use Rust for efficiency, Lua for orchestration, Bash for gluing components
- Save state at each build step for easier debugging and incremental changes
- Data storage is cheap - use it liberally for state tracking and logging

### Hardware Considerations
- Target Anbernic handheld devices (RG-NANO minimum, full compatibility list in @notes/device-list)
- Optimize for ARM processors (both ARM32 and ARM64)
- Account for SD card storage limitations - write slowly with battery monitoring
- Support air-gapped operation with P2P networking only (no internet/router access)

### Security and Privacy
- All communication must use relationship-specific encryption (Ed25519 + X25519 + ChaCha20-Poly1305)
- Implement emoji-based device pairing for cryptographic key exchange
- Auto-expiring relationships (default 30 days) for forward secrecy
- No external API violations - maintain strict air-gapped architecture for handheld devices

### Compilation Strategy
When compiling, prefer using multiple steps, each with their own error and
validation checks. As it's building, save a state of it in each part of its
path. This makes it easier to change the system later if they can watch how
it's unfolding and debug issues incrementally.

### Storage Management
Data storage is cheap - use it. On SD cards and flash drives, write slowly
or bit-by-bit with battery monitoring to preserve device health and show
battery balance status.

## Project Structure and Key Components

### Core Systems (Implemented)
- **Enhanced Input System** (`src/enhanced_input.rs`) - Game Boy-style hierarchical text input

**📄 Full content of src/enhanced_input.rs:**

```
/// Enhanced input system with edit mode, configurable keyboards, and multi-controller support
/// Implements the proposed improvements from claude-next-2
use crate::input_config::*;
use crate::p2p_mesh::{P2PMeshManager, P2PIntegration, PeerDevice, DeviceType, SharedFile};
use crate::wifi_direct_p2p::{WiFiDirectP2P, MessageContent};
use crate::ai_image_service::{ImageGenerationRequest, ImageGenerationResponse, ImageStyle, ImageResolution};
use crate::crypto::{P2PMigrationAdapter, RelationshipId, PairingEmoji as CryptoPairingEmoji};
use serde::{Serialize, Deserialize};
use std::collections::HashMap;
use std::f32::consts::PI;
use std::time::{Duration, Instant};
use std::path::PathBuf;
use chrono;
use futures;
use base64::{Engine as _, engine::general_purpose};

// P2P integration is implemented directly in this file

/// Enhanced input manager that handles different input modes and controller types
pub struct EnhancedInputManager {
    pub config: InputConfig,
    pub current_mode: EnhancedInputMode,
    pub text_buffer: String,
    pub cursor_position: usize,
    pub edit_mode_state: EditModeState,
    pub one_time_keyboard_state: Option<OneTimeKeyboardState>,
    pub button_states: HashMap<String, ButtonState>,
    pub last_input_time: Instant,
    
    // P2P mesh networking for document sharing (legacy)
    pub p2p_manager: Option<P2PMeshManager>,
    pub p2p_enabled: bool,
    pub shared_documents: Vec<SharedDocument>,
    pub auto_save_enabled: bool,
    pub document_metadata: DocumentMetadata,
    pub collaboration_state: Option<CollaborationState>,
    
    // WiFi Direct P2P for AI image generation (legacy)
    pub wifi_direct: Option<WiFiDirectP2P>,
    pub wifi_direct_connected: bool,
    pub available_image_files: Vec<ImageFileEntry>,
    pub pending_image_requests: Vec<PendingImageRequest>,
    pub images_directory: PathBuf,
    
    // Secure P2P system with crypto integration
    pub secure_p2p: Option<P2PMigrationAdapter>,
    pub secure_p2p_enabled: bool,
    pub secure_relationships: Vec<RelationshipId>,
    pub pairing_mode_active: bool,
    pub discovered_secure_devices: Vec<CryptoPairingEmoji>,
}

#[derive(Debug, Clone)]
pub enum EnhancedInputMode {
    Navigation,
    EditMode,
    OneTimeKeyboard { target_mode: Box<EnhancedInputMode> },
    RadialMenu { state: RadialMenuState },
    SpecialCharacterMode,
    P2PBrowser,
    CollaborationMode,
    DocumentSaver,
    ImageMenu { submenu: ImageSubmenu },
    AIImagePrompt { prompt: String },
    SecurePairing { stage: SecurePairingStage },
    SecureDeviceSelection { devices: Vec<CryptoPairingEmoji> },
    RelationshipManager,
}

#[derive(Debug, Clone)]
pub enum ImageSubmenu {
    Main,
    FileSelection { files: Vec<ImageFileEntry> },
    AIGeneration,
}

#[derive(Debug, Clone)]
pub enum SecurePairingStage {
    /// Initiating pairing mode
    Initiating,
    /// Broadcasting our emoji and scanning
    Broadcasting { our_emoji: CryptoPairingEmoji },
    /// Showing discovered devices for selection
    DeviceSelection { devices: Vec<CryptoPairingEmoji> },
    /// Entering nickname for selected device
    NicknameEntry { target_device: CryptoPairingEmoji, partial_nickname: String },
    /// Completing pairing process
    Completing { target_device: CryptoPairingEmoji, nickname: String },
    /// Pairing completed successfully
    Completed { relationship_id: RelationshipId },
    /// Pairing failed
    Failed { error: String },
}

#[derive(Debug, Clone)]
pub struct ImageFileEntry {
    pub path: PathBuf,
    pub name: String,
    pub source: ImageSource,
    pub thumbnail_available: bool,
}

#[derive(Debug, Clone)]
pub enum ImageSource {
    Paint,
    AIGenerated,
    Shared,
    Downloaded,
}

#[derive(Debug, Clone)]
pub struct PendingImageRequest {
    pub request_id: String,
    pub prompt: String,
    pub placeholder_position: usize,
    pub target_application: String,
    pub timestamp: Instant,
}

#[derive(Debug, Clone)]
pub struct EditModeState {
    pub cursor_line: usize,
    pub cursor_column: usize,
    pub selection_start: Option<CursorPosition>,
    pub selection_end: Option<CursorPosition>,
    pub word_wrap_enabled: bool,
    pub auto_exit_timer: Option<Instant>,
    pub last_cursor_move: Instant,
}

#[derive(Debug, Clone)]
pub struct CursorPosition {
    pub line: usize,
    pub column: usize,
    pub absolute_position: usize,
}

#[derive(Debug, Clone)]
pub struct OneTimeKeyboardState {
    pub layout: String,
    pub sector_index: usize,
    pub character_index: usize,
    pub return_mode: EnhancedInputMode,
    pub partial_input: String,
}

#[derive(Debug, Clone)]
pub struct ButtonState {
    pub pressed: bool,
    pub press_time: Option<Instant>,
    pub release_time: Option<Instant>,
    pub press_count: usize,
    pub last_press_time: Option<Instant>,
}

/// P2P-specific structures for word processor
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedDocument {
    pub file_hash: String,
    pub filename: String,
    pub content: String,
    pub author: String,
    pub created_time: u64,
    pub last_modified: u64,
    pub tags: Vec<String>,
    pub file_size: usize,
    pub device_info: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DocumentMetadata {
    pub filename: String,
    pub author: String,
    pub created_time: u64,
    pub last_modified: u64,
    pub word_count: usize,
    pub character_count: usize,
    pub tags: Vec<String>,
    pub version: u32,
}

#[derive(Debug, Clone)]
pub struct CollaborationState {
    pub session_id: String,
    pub participants: Vec<String>,
    pub document_hash: String,
    pub last_sync: u64,
    pub pending_changes: Vec<DocumentChange>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DocumentChange {
    pub change_id: String,
    pub author: String,
    pub timestamp: u64,
    pub change_type: ChangeType,
    pub position: usize,
    pub content: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ChangeType {
    Insert,
    Delete,
    Replace,
    CursorMove,
}

/// Radial menu system for enhanced input
#[derive(Debug, Clone)]
pub struct RadialMenuState {
    pub center_x: f32,
    pub center_y: f32,
    pub active_direction: Direction,
    pub active_angle: f32,
    pub menu_options: [Option<char>; 4],
    pub selected_option: Option<usize>,
    pub alphabet_layout: AlphabetLayout,
    pub is_visible: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Direction {
    Up,
    Down,
    Left,
    Right,
    UpLeft,
    UpRight,
    DownLeft,
    DownRight,
}

#[derive(Debug, Clone)]
pub struct AlphabetLayout {
    pub sectors: HashMap<Direction, [char; 4]>,
}

impl Default for AlphabetLayout {
    fn default() -> Self {
        let mut sectors = HashMap::new();
        
        // Distribute A-Z across 8 directions (32 total slots, using 26)
        sectors.insert(Direction::Up, ['A', 'B', 'C', 'D']);
        sectors.insert(Direction::UpRight, ['E', 'F', 'G', 'H']);
        sectors.insert(Direction::Right, ['I', 'J', 'K', 'L']);
        sectors.insert(Direction::DownRight, ['M', 'N', 'O', 'P']);
        sectors.insert(Direction::Down, ['Q', 'R', 'S', 'T']);
        sectors.insert(Direction::DownLeft, ['U', 'V', 'W', 'X']);
        sectors.insert(Direction::Left, ['Y', 'Z', ' ', '.']);
        sectors.insert(Direction::UpLeft, ['!', '?', ',', ';']);
        
        Self { sectors }
    }
}

impl RadialMenuState {
    pub fn new(center_x: f32, center_y: f32) -> Self {
        Self {
            center_x,
            center_y,
            active_direction: Direction::Up,
            active_angle: 0.0,
            menu_options: [None; 4],
            selected_option: None,
            alphabet_layout: AlphabetLayout::default(),
            is_visible: false,
        }
    }
    
    pub fn update_direction(&mut self, direction: Direction) {
        self.active_direction = direction;
        self.active_angle = self.direction_to_angle(direction);
        self.update_menu_options();
        self.is_visible = true;
    }
    
    fn direction_to_angle(&self, direction: Direction) -> f32 {
        match direction {
            Direction::Up => 270.0,
            Direction::UpRight => 315.0,
            Direction::Right => 0.0,
            Direction::DownRight => 45.0,
            Direction::Down => 90.0,
            Direction::DownLeft => 135.0,
            Direction::Left => 180.0,
            Direction::UpLeft => 225.0,
        }
    }
    
    fn update_menu_options(&mut self) {
        if let Some(chars) = self.alphabet_layout.sectors.get(&self.active_direction) {
            for (i, &ch) in chars.iter().enumerate() {
                self.menu_options[i] = Some(ch);
            }
        } else {
            self.menu_options = [None; 4];
        }
    }
    
    pub fn get_option_positions(&self) -> [(f32, f32); 4] {
        let radius = 50.0; // Distance from center
        let base_angle_rad = self.active_angle * PI / 180.0;
        
        // Position options in an arc around the direction
        let mut positions = [(0.0, 0.0); 4];
        
        match self.active_direction {
            Direction::Left => {
                // LEFT: First two options below X-axis, next two above X-axis
                let angles = [-30.0, -60.0, 30.0, 60.0]; // Relative to left (180°)
                for (i, &angle_offset) in angles.iter().enumerate() {
                    let angle_rad = (180.0 + angle_offset) * PI / 180.0;
                    positions[i] = (
                        self.center_x + radius * angle_rad.cos(),
                        self.center_y + radius * angle_rad.sin(),
                    );
                }
            },
            Direction::UpRight => {
                // UP+RIGHT: Menu at 45° angle
                let angles = [-30.0, -15.0, 15.0, 30.0]; // Relative to 45°
                for (i, &angle_offset) in angles.iter().enumerate() {
                    let angle_rad = (315.0 + angle_offset) * PI / 180.0;
                    positions[i] = (
                        self.center_x + radius * angle_rad.cos(),
                        self.center_y + radius * angle_rad.sin(),
                    );
                }
            },
            _ => {
                // Default arc positioning
                let angles = [-30.0, -10.0, 10.0, 30.0]; // Spread around direction
                for (i, &angle_offset) in angles.iter().enumerate() {
                    let angle_rad = (base_angle_rad + angle_offset * PI / 180.0);
                    positions[i] = (
                        self.center_x + radius * angle_rad.cos(),
                        self.center_y + radius * angle_rad.sin(),
                    );
                }
            }
        }
        
        positions
    }
    
    pub fn select_option(&mut self, button_index: usize) -> Option<char> {
        if button_index < 4 {
            self.selected_option = Some(button_index);
            self.menu_options[button_index]
        } else {
            None
        }
    }
    
    pub fn hide(&mut self) {
        self.is_visible = false;
        self.selected_option = None;
    }
    
    /// Get visual rendering data for the radial menu
    pub fn get_render_data(&self) -> RadialMenuRenderData {
        let positions = self.get_option_positions();
        let mut options = Vec::new();
        
        for (i, pos) in positions.iter().enumerate() {
            if let Some(character) = self.menu_options[i] {
                options.push(RadialMenuOption {
                    character,
                    position: *pos,
                    selected: self.selected_option == Some(i),
                    button_hint: match i {
                        0 => "L1".to_string(),
                        1 => "B".to_string(), 
                        2 => "A".to_string(),
                        3 => "Y".to_string(),
                        _ => "".to_string(),
                    },
                });
            }
        }
        
        RadialMenuRenderData {
            center: (self.center_x, self.center_y),
            options,
            direction: self.active_direction.clone(),
            angle: self.active_angle,
            visible: self.is_visible,
        }
    }
}

/// Data structure for rendering the radial menu
#[derive(Debug, Clone)]
pub struct RadialMenuRenderData {
    pub center: (f32, f32),
    pub options: Vec<RadialMenuOption>,
    pub direction: Direction,
    pub angle: f32,
    pub visible: bool,
}

#[derive(Debug, Clone)]
pub struct RadialMenuOption {
    pub character: char,
    pub position: (f32, f32),
    pub selected: bool,
    pub button_hint: String,
}

/// Radial button inputs for universal controller support
#[derive(Debug, Clone, PartialEq)]
pub enum UniversalButton {
    // Basic buttons (Game Boy compatible)
    A,
    B,
    Select,
    Start,

    // Extended buttons (SNES compatible)
    X,
    Y,
    L,
    R,

    // D-Pad directions
    Up,
    Down,
    Left,
    Right,

    // Custom/mapped buttons
    Custom(String),
}

#[derive(Debug, Clone)]
pub enum InputResult {
    TextInput { text: String },
    InsertText { text: String },
    ReplaceText { find: String, replace: String },
    ModeChange { new_mode: EnhancedInputMode },
    CursorMove { new_position: usize },
    SpecialAction { action: String },
    Navigation { direction: String },
    StatusMessage { message: String },
    NoAction,
}

impl EnhancedInputManager {
    pub fn new(config: InputConfig) -> Self {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
            
        Self {
            config,
            current_mode: EnhancedInputMode::Navigation,
            text_buffer: String::new(),
            cursor_position: 0,
            edit_mode_state: EditModeState {
                cursor_line: 0,
                cursor_column: 0,
                selection_start: None,
                selection_end: None,
                word_wrap_enabled: true,
                auto_exit_timer: None,
                last_cursor_move: Instant::now(),
            },
            one_time_keyboard_state: None,
            button_states: HashMap::new(),
            last_input_time: Instant::now(),
            
            // P2P fields
            p2p_manager: None,
            p2p_enabled: false,
            shared_documents: Vec::new(),
            auto_save_enabled: true,
            document_metadata: DocumentMetadata {
                filename: "untitled.txt".to_string(),
                author: "anonymous".to_string(),
                created_time: now,
                last_modified: now,
                word_count: 0,
                character_count: 0,
                tags: vec!["handheld".to_string(), "draft".to_string()],
                version: 1,
            },
            collaboration_state: None,
            
            // WiFi Direct P2P for AI image generation
            wifi_direct: None,
            wifi_direct_connected: false,
            available_image_files: Vec::new(),
            pending_image_requests: Vec::new(),
            images_directory: PathBuf::from("./images"),
            
            // Secure P2P system with crypto integration
            secure_p2p: None,
            secure_p2p_enabled: false,
            secure_relationships: Vec::new(),
            pairing_mode_active: false,
            discovered_secure_devices: Vec::new(),
        }
    }

    /// Handle button input with enhanced features
    pub fn handle_button_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
    ) -> Vec<InputResult> {
        self.last_input_time = Instant::now();
        self.update_button_state(button.clone(), pressed);

        match self.current_mode.clone() {
            EnhancedInputMode::Navigation => self.handle_navigation_input(button, pressed),
            EnhancedInputMode::EditMode => self.handle_edit_mode_input(button, pressed),
            EnhancedInputMode::OneTimeKeyboard { target_mode } => {
                self.handle_one_time_keyboard_input(button, pressed, *target_mode)
            }
            EnhancedInputMode::RadialMenu { state } => {
                self.handle_radial_menu_input(button, pressed, state)
            }
            EnhancedInputMode::SpecialCharacterMode => {
                self.handle_special_character_input(button, pressed)
            }
            EnhancedInputMode::P2PBrowser => {
                self.handle_p2p_browser_input(button, pressed)
            }
            EnhancedInputMode::CollaborationMode => {
                self.handle_collaboration_mode_input(button, pressed)
            }
            EnhancedInputMode::DocumentSaver => {
                self.handle_document_saver_input(button, pressed)
            }
            EnhancedInputMode::ImageMenu { submenu } => {
                self.handle_image_menu_input(button, pressed, submenu)
            }
            EnhancedInputMode::AIImagePrompt { prompt } => {
                self.handle_ai_image_prompt_input(button, pressed, prompt)
            }
            EnhancedInputMode::SecurePairing { stage } => {
                self.handle_secure_pairing_input(button, pressed, stage)
            }
            EnhancedInputMode::SecureDeviceSelection { devices } => {
                self.handle_secure_device_selection_input(button, pressed, devices)
            }
            EnhancedInputMode::RelationshipManager => {
                self.handle_relationship_manager_input(button, pressed)
            }
        }
    }

    fn update_button_state(&mut self, button: UniversalButton, pressed: bool) {
        let button_name = format!("{:?}", button);
        let state = self
            .button_states
            .entry(button_name)
            .or_insert(ButtonState {
                pressed: false,
                press_time: None,
                release_time: None,
                press_count: 0,
                last_press_time: None,
            });

        if pressed && !state.pressed {
            // Button press detected
            state.pressed = true;
            state.press_time = Some(Instant::now());

            // Count rapid presses for double-tap detection
            if let Some(last_press) = state.last_press_time {
                if Instant::now().duration_since(last_press) < Duration::from_millis(500) {
                    state.press_count += 1;
                } else {
                    state.press_count = 1;
                }
            } else {
                state.press_count = 1;
            }
            state.last_press_time = Some(Instant::now());
        } else if !pressed && state.pressed {
            // Button release detected
            state.pressed = false;
            state.release_time = Some(Instant::now());
        }
    }

    fn handle_navigation_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select => {
                // SELECT enters edit mode (as proposed)
                vec![self.enter_edit_mode()]
            }
            UniversalButton::A => {
                vec![InputResult::Navigation {
                    direction: "select".to_string(),
                }]
            }
            UniversalButton::B => {
                vec![InputResult::Navigation {
                    direction: "back".to_string(),
                }]
            }
            UniversalButton::Start => {
                // START opens P2P browser when P2P is enabled
                if self.p2p_enabled {
                    self.current_mode = EnhancedInputMode::P2PBrowser;
                    vec![InputResult::ModeChange {
                        new_mode: self.current_mode.clone(),
                    }]
                } else {
                    vec![InputResult::Navigation {
                        direction: "menu".to_string(),
                    }]
                }
            }
            UniversalButton::X => {
                // X opens document saver (SNES controllers)
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    self.current_mode = EnhancedInputMode::DocumentSaver;
                    vec![InputResult::ModeChange {
                        new_mode: self.current_mode.clone(),
                    }]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Y => {
                // Y toggles P2P features (SNES controllers)
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    vec![self.toggle_p2p()]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Up
            | UniversalButton::Down
            | UniversalButton::Left
            | UniversalButton::Right => self.handle_directional_navigation(button),
            _ => vec![InputResult::NoAction],
        }
    }

    fn handle_edit_mode_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select => {
                // SELECT exits edit mode
                vec![self.exit_edit_mode()]
            }
            UniversalButton::A => {
                // A opens one-time keyboard for character input
                vec![self.enter_one_time_keyboard()]
            }
            UniversalButton::B => {
                // B acts as backspace in edit mode
                vec![self.handle_backspace()]
            }
            UniversalButton::Up
            | UniversalButton::Down
            | UniversalButton::Left
            | UniversalButton::Right => {
                // D-pad moves cursor in edit mode
                vec![self.handle_cursor_movement(button)]
            }
            _ => vec![InputResult::NoAction],
        }
    }

    fn handle_one_time_keyboard_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        return_mode: EnhancedInputMode,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::A => {
                // Select current character and return to edit mode
                if let Some(character) = self.get_current_keyboard_character() {
                    self.current_mode = return_mode;
                    self.one_time_keyboard_state = None;
                    vec![
                        self.insert_character_at_cursor(character),
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::B => {
                // Cancel and return to edit mode
                self.current_mode = return_mode;
                self.one_time_keyboard_state = None;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::Up
            | UniversalButton::Down
            | UniversalButton::Left
            | UniversalButton::Right => {
                // Navigate through keyboard characters
                vec![self.navigate_keyboard_character(button)]
            }
            _ => vec![InputResult::NoAction],
        }
    }

    fn handle_directional_navigation(&mut self, button: UniversalButton) -> Vec<InputResult> {
        match &self.config.controller_type {
            ControllerType::SNES { .. } => {
                // Check if L or R is pressed for media functions
                let l_pressed = self.button_states.get("L").map_or(false, |s| s.pressed);
                let r_pressed = self.button_states.get("R").map_or(false, |s| s.pressed);
                
                // SNES-style: D-pad opens radial menus with proper direction mapping
                let direction = self.button_to_direction(button);
                let mut radial_state = RadialMenuState::new(400.0, 300.0); // Default screen center
                radial_state.update_direction(direction);
                
                self.current_mode = EnhancedInputMode::RadialMenu {
                    state: radial_state,
                };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            _ => {
                // Game Boy style: simple navigation
                let direction = match button {
                    UniversalButton::Up => "up",
                    UniversalButton::Down => "down",
                    UniversalButton::Left => "left",
                    UniversalButton::Right => "right",
                    _ => "unknown",
                };
                vec![InputResult::Navigation {
                    direction: direction.to_string(),
                }]
            }
        }
    }

    fn enter_edit_mode(&mut self) -> InputResult {
        self.current_mode = EnhancedInputMode::EditMode;
        self.edit_mode_state.auto_exit_timer = Some(
            Instant::now()
                + Duration::from_millis(self.config.edit_mode_settings.auto_exit_timeout_ms),
        );
        InputResult::ModeChange {
            new_mode: self.current_mode.clone(),
        }
    }

    fn exit_edit_mode(&mut self) -> InputResult {
        self.current_mode = EnhancedInputMode::Navigation;
        self.edit_mode_state.auto_exit_timer = None;
        InputResult::ModeChange {
            new_mode: self.current_mode.clone(),
        }
    }

    fn enter_one_time_keyboard(&mut self) -> InputResult {
        let layout = self
            .config
            .keyboard_layouts
            .keys()
            .next()
            .unwrap_or(&"default".to_string())
            .clone();

        self.one_time_keyboard_state = Some(OneTimeKeyboardState {
            layout: layout.clone(),
            sector_index: 0,
            character_index: 0,
            return_mode: EnhancedInputMode::EditMode,
            partial_input: String::new(),
        });

        let old_mode = self.current_mode.clone();
        self.current_mode = EnhancedInputMode::OneTimeKeyboard {
            target_mode: Box::new(old_mode),
        };

        InputResult::ModeChange {
            new_mode: self.current_mode.clone(),
        }
    }

    fn handle_backspace(&mut self) -> InputResult {
        if self.cursor_position > 0 && !self.text_buffer.is_empty() {
            self.cursor_position -= 1;
            self.text_buffer.remove(self.cursor_position);
            InputResult::TextInput {
                text: self.text_buffer.clone(),
            }
        } else {
            InputResult::NoAction
        }
    }

    fn handle_cursor_movement(&mut self, direction: UniversalButton) -> InputResult {
        self.edit_mode_state.last_cursor_move = Instant::now();

        match direction {
            UniversalButton::Left => {
                if self.cursor_position > 0 {
                    self.cursor_position -= 1;
                }
            }
            UniversalButton::Right => {
                if self.cursor_position < self.text_buffer.len() {
                    self.cursor_position += 1;
                }
            }
            UniversalButton::Up => {
                // Move up one line (if multiline)
                self.move_cursor_up();
            }
            UniversalButton::Down => {
                // Move down one line (if multiline)
                self.move_cursor_down();
            }
            _ => {}
        }

        InputResult::CursorMove {
            new_position: self.cursor_position,
        }
    }

    fn move_cursor_up(&mut self) {
        if self.edit_mode_state.cursor_line > 0 {
            self.edit_mode_state.cursor_line -= 1;
            self.update_absolute_cursor_position();
        }
    }

    fn move_cursor_down(&mut self) {
        let lines: Vec<&str> = self.text_buffer.lines().collect();
        if self.edit_mode_state.cursor_line < lines.len().saturating_sub(1) {
            self.edit_mode_state.cursor_line += 1;
            self.update_absolute_cursor_position();
        }
    }

    fn update_absolute_cursor_position(&mut self) {
        let lines: Vec<&str> = self.text_buffer.lines().collect();
        let mut position = 0;

        for (i, line) in lines.iter().enumerate() {
            if i == self.edit_mode_state.cursor_line {
                position += self.edit_mode_state.cursor_column.min(line.len());
                break;
            }
            position += line.len() + 1; // +1 for newline
        }

        self.cursor_position = position.min(self.text_buffer.len());
    }

    fn get_current_keyboard_character(&self) -> Option<char> {
        if let Some(state) = &self.one_time_keyboard_state {
            if let Some(layout) = self.config.keyboard_layouts.get(&state.layout) {
                if let Some(sector) = layout.sectors.get(state.sector_index) {
                    return sector.characters.get(state.character_index).copied();
                }
            }
        }
        None
    }

    fn navigate_keyboard_character(&mut self, direction: UniversalButton) -> InputResult {
        if let Some(state) = &mut self.one_time_keyboard_state {
            if let Some(layout) = self.config.keyboard_layouts.get(&state.layout) {
                match direction {
                    UniversalButton::Up | UniversalButton::Down => {
                        // Move between sectors
                        match direction {
                            UniversalButton::Up => {
                                if state.sector_index > 0 {
                                    state.sector_index -= 1;
                                }
                            }
                            UniversalButton::Down => {
                                if state.sector_index < layout.sectors.len() - 1 {
                                    state.sector_index += 1;
                                }
                            }
                            _ => {}
                        }
                        state.character_index = 0; // Reset character index when changing sectors
                    }
                    UniversalButton::Left | UniversalButton::Right => {
                        // Move within sector
                        if let Some(sector) = layout.sectors.get(state.sector_index) {
                            match direction {
                                UniversalButton::Left => {
                                    if state.character_index > 0 {
                                        state.character_index -= 1;
                                    }
                                }
                                UniversalButton::Right => {
                                    if state.character_index < sector.characters.len() - 1 {
                                        state.character_index += 1;
                                    }
                                }
                                _ => {}
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
        InputResult::Navigation {
            direction: format!("{:?}", direction),
        }
    }

    fn insert_character_at_cursor(&mut self, character: char) -> InputResult {
        self.text_buffer.insert(self.cursor_position, character);
        self.cursor_position += character.len_utf8();

        // Update line/column tracking
        if character == '\n' {
            self.edit_mode_state.cursor_line += 1;
            self.edit_mode_state.cursor_column = 0;
        } else {
            self.edit_mode_state.cursor_column += 1;
        }

        InputResult::TextInput {
            text: self.text_buffer.clone(),
        }
    }

    fn handle_radial_menu_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        mut state: RadialMenuState,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            // D-pad changes active direction and switches to new menu
            UniversalButton::Up
            | UniversalButton::Down
            | UniversalButton::Left
            | UniversalButton::Right => {
                let direction = self.button_to_direction(button);
                state.update_direction(direction);
                self.current_mode = EnhancedInputMode::RadialMenu { state };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            // Face buttons (L1/X=1st, L2/B=2nd, R1/A=3rd, R2/Y=4th option)
            UniversalButton::L => {
                if let Some(character) = state.select_option(0) {
                    self.current_mode = EnhancedInputMode::Navigation;
                    vec![
                        self.insert_character_at_cursor(character),
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::B => {
                if let Some(character) = state.select_option(1) {
                    self.current_mode = EnhancedInputMode::Navigation;
                    vec![
                        self.insert_character_at_cursor(character),
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::A => {
                if let Some(character) = state.select_option(2) {
                    self.current_mode = EnhancedInputMode::Navigation;
                    vec![
                        self.insert_character_at_cursor(character),
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Y => {
                if let Some(character) = state.select_option(3) {
                    self.current_mode = EnhancedInputMode::Navigation;
                    vec![
                        self.insert_character_at_cursor(character),
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Select => {
                // Exit radial menu
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            _ => vec![InputResult::NoAction],
        }
    }
    
    fn button_to_direction(&self, button: UniversalButton) -> Direction {
        match button {
            UniversalButton::Up => Direction::Up,
            UniversalButton::Down => Direction::Down,
            UniversalButton::Left => Direction::Left,
            UniversalButton::Right => Direction::Right,
            _ => Direction::Up, // Default
        }
    }
    
    // Support for complex directional input (UP+RIGHT, etc.)
    pub fn handle_complex_directional_input(&mut self, buttons: &[UniversalButton]) -> Direction {
        let up_pressed = buttons.contains(&UniversalButton::Up);
        let down_pressed = buttons.contains(&UniversalButton::Down);
        let left_pressed = buttons.contains(&UniversalButton::Left);
        let right_pressed = buttons.contains(&UniversalButton::Right);
        
        match (up_pressed, down_pressed, left_pressed, right_pressed) {
            (true, false, false, true) => Direction::UpRight,
            (true, false, true, false) => Direction::UpLeft,
            (false, true, false, true) => Direction::DownRight,
            (false, true, true, false) => Direction::DownLeft,
            (true, false, false, false) => Direction::Up,
            (false, true, false, false) => Direction::Down,
            (false, false, true, false) => Direction::Left,
            (false, false, false, true) => Direction::Right,
            _ => Direction::Up, // Default for ambiguous input
        }
    }

    fn handle_special_character_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        // Implementation for special character mode (emojis, symbols, etc.)
        match button {
            UniversalButton::Select => {
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            _ => {
                // Handle special character selection
                vec![InputResult::SpecialAction {
                    action: "special_char".to_string(),
                }]
            }
        }
    }


    fn handle_radial_action(&mut self, action: String) -> Vec<InputResult> {
        match action.as_str() {
            "image_menu" => {
                // Scan for available image files
                self.scan_for_image_files();
                self.current_mode = EnhancedInputMode::ImageMenu { 
                    submenu: ImageSubmenu::Main 
                };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            "emoji_keyboard" => {
                let mut emoji_state = RadialMenuState::new(400.0, 300.0);
                // Create emoji layout
                let mut emoji_layout = AlphabetLayout::default();
                emoji_layout.sectors.insert(Direction::Up, ['😀', '😎', '👍', '❤']);
                emoji_layout.sectors.insert(Direction::Right, ['🎮', '🔥', '⭐', '✨']);
                emoji_layout.sectors.insert(Direction::Down, ['🎯', '🚀', '💯', '🎪']);
                emoji_layout.sectors.insert(Direction::Left, ['🌟', '🎨', '🎭', '🎪']);
                emoji_state.alphabet_layout = emoji_layout;
                emoji_state.update_direction(Direction::Up);
                
                self.current_mode = EnhancedInputMode::RadialMenu { state: emoji_state };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            "special_chars" => {
                self.current_mode = EnhancedInputMode::SpecialCharacterMode;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            "settings" => {
                vec![InputResult::SpecialAction {
                    action: "open_settings".to_string(),
                }]
            }
            "shift_toggle" => {
                vec![InputResult::SpecialAction {
                    action: "toggle_shift".to_string(),
                }]
            }
            "caps_lock" => {
                vec![InputResult::SpecialAction {
                    action: "toggle_caps_lock".to_string(),
                }]
            }
            _ => vec![InputResult::NoAction],
        }
    }

    fn handle_image_menu_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        submenu: ImageSubmenu,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match submenu {
            ImageSubmenu::Main => {
                match button {
                    UniversalButton::A => {
                        // Insert existing image
                        self.current_mode = EnhancedInputMode::ImageMenu {
                            submenu: ImageSubmenu::FileSelection {
                                files: self.available_image_files.clone(),
                            },
                        };
                        vec![InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        }]
                    }
                    UniversalButton::B => {
                        // Create new AI image (if connected)
                        if self.wifi_direct_connected {
                            self.current_mode = EnhancedInputMode::AIImagePrompt {
                                prompt: String::new(),
                            };
                            vec![InputResult::ModeChange {
                                new_mode: self.current_mode.clone(),
                            }]
                        } else {
                            vec![InputResult::StatusMessage {
                                message: "AI image generation requires laptop connection".to_string(),
                            }]
                        }
                    }
                    UniversalButton::Select => {
                        // Exit image menu
                        self.current_mode = EnhancedInputMode::Navigation;
                        vec![InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        }]
                    }
                    _ => vec![InputResult::NoAction],
                }
            }
            ImageSubmenu::FileSelection { files } => {
                self.handle_image_file_selection(button, files)
            }
            ImageSubmenu::AIGeneration => {
                // Handle AI generation options
                vec![InputResult::NoAction]
            }
        }
    }

    fn handle_ai_image_prompt_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        mut prompt: String,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::A => {
                // Submit prompt for AI generation
                if !prompt.is_empty() {
                    self.submit_ai_image_request(prompt.clone())
                } else {
                    vec![InputResult::StatusMessage {
                        message: "Please enter a prompt".to_string(),
                    }]
                }
            }
            UniversalButton::B => {
                // Backspace
                prompt.pop();
                self.current_mode = EnhancedInputMode::AIImagePrompt { prompt };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::Select => {
                // Cancel AI image generation
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            _ => {
                // Open character keyboard for typing prompt
                self.current_mode = EnhancedInputMode::OneTimeKeyboard {
                    target_mode: Box::new(EnhancedInputMode::AIImagePrompt { prompt }),
                };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
        }
    }

    fn handle_image_file_selection(
        &mut self,
        button: UniversalButton,
        files: Vec<ImageFileEntry>,
    ) -> Vec<InputResult> {
        // Navigate through available image files and select one to insert
        match button {
            UniversalButton::A => {
                // Insert selected image placeholder
                if let Some(file) = files.first() {
                    let placeholder = format!("[IMAGE:{}]", file.name);
                    self.current_mode = EnhancedInputMode::Navigation;
                    vec![
                        InputResult::InsertText { text: placeholder },
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::StatusMessage {
                        message: "No images available".to_string(),
                    }]
                }
            }
            UniversalButton::Select => {
                // Exit file selection
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            _ => vec![InputResult::NoAction],
        }
    }

    fn scan_for_image_files(&mut self) {
        // Scan paint directory, AI generated images directory, and shared files
        self.available_image_files.clear();

        // Add paint files
        if let Ok(entries) = std::fs::read_dir(&self.images_directory.join("paint")) {
            for entry in entries.flatten() {
                if let Some(name) = entry.file_name().to_str() {
                    if name.ends_with(".png") || name.ends_with(".jpg") {
                        self.available_image_files.push(ImageFileEntry {
                            path: entry.path(),
                            name: name.to_string(),
                            source: ImageSource::Paint,
                            thumbnail_available: false,
                        });
                    }
                }
            }
        }

        // Add AI generated files
        if let Ok(entries) = std::fs::read_dir(&self.images_directory.join("ai_generated")) {
            for entry in entries.flatten() {
                if let Some(name) = entry.file_name().to_str() {
                    if name.ends_with(".png") || name.ends_with(".jpg") {
                        self.available_image_files.push(ImageFileEntry {
                            path: entry.path(),
                            name: name.to_string(),
                            source: ImageSource::AIGenerated,
                            thumbnail_available: false,
                        });
                    }
                }
            }
        }

        // Add shared files from P2P
        for shared_file in &self.shared_documents {
            if shared_file.filename.ends_with(".png") || shared_file.filename.ends_with(".jpg") {
                self.available_image_files.push(ImageFileEntry {
                    path: PathBuf::from(&shared_file.filename),
                    name: shared_file.filename.clone(),
                    source: ImageSource::Shared,
                    thumbnail_available: false,
                });
            }
        }
    }

    fn submit_ai_image_request(&mut self, prompt: String) -> Vec<InputResult> {
        let request_id = format!("img_{}", chrono::Utc::now().timestamp());
        let placeholder = format!("[AI_IMAGE_GENERATING:{}]", request_id);
        
        // Create pending request
        let pending_request = PendingImageRequest {
            request_id: request_id.clone(),
            prompt: prompt.clone(),
            placeholder_position: self.cursor_position,
            target_application: "document".to_string(),
            timestamp: Instant::now(),
        };
        
        self.pending_image_requests.push(pending_request);
        
        // Send WiFi Direct request if connected
        if let Some(ref wifi_direct) = self.wifi_direct {
            // This will be handled asynchronously
            let paired_devices = futures::executor::block_on(wifi_direct.get_active_peers());
            if let Some((device_id, _)) = paired_devices.into_iter().next() {
                let image_request = ImageGenerationRequest {
                    request_id: request_id.clone(),
                    sender_device_id: wifi_direct.device_id.clone(),
                    prompt: prompt.clone(),
                    negative_prompt: None,
                    style: ImageStyle::Realistic,
                    resolution: ImageResolution::Square512,
                    steps: 20,
                    guidance_scale: 7.5,
                    seed: None,
                    timestamp: chrono::Utc::now().timestamp() as u64,
                };
                
                // Send request (this would be async in real implementation)
                let _ = futures::executor::block_on(
                    wifi_direct.send_message(&device_id, MessageContent::ImageGenerationRequest {
                        request_id: image_request.request_id,
                        prompt: image_request.prompt,
                        style: "realistic".to_string(),
                        resolution: "512x512".to_string(),
                        steps: 20,
                        guidance_scale: 7.5,
                    })
                );
            }
        }
        
        // Return to navigation mode and insert placeholder
        self.current_mode = EnhancedInputMode::Navigation;
        vec![
            InputResult::InsertText { text: placeholder },
            InputResult::ModeChange {
                new_mode: self.current_mode.clone(),
            },
            InputResult::StatusMessage {
                message: format!("AI image generation started: {}", prompt),
            },
        ]
    }

    /// Initialize WiFi Direct connection
    pub fn set_wifi_direct(&mut self, wifi_direct: Option<WiFiDirectP2P>) {
        self.wifi_direct = wifi_direct;
        self.update_wifi_direct_status();
    }
    
    /// Update WiFi Direct connection status
    pub fn update_wifi_direct_status(&mut self) {
        if let Some(ref wifi_direct) = self.wifi_direct {
            // Check if any devices are connected
            let peers = futures::executor::block_on(wifi_direct.get_active_peers());
            self.wifi_direct_connected = !peers.is_empty();
        } else {
            self.wifi_direct_connected = false;
        }
    }
    
    /// Handle received AI image generation response
    pub fn handle_ai_image_response(&mut self, response: ImageGenerationResponse) -> Vec<InputResult> {
        // Find pending request
        if let Some(pos) = self.pending_image_requests.iter().position(|r| r.request_id == response.request_id) {
            let pending_request = self.pending_image_requests.remove(pos);
            
            if response.success {
                // Replace placeholder with actual image reference
                let replacement_text = if let Some(image_path) = response.image_path {
                    format!("[IMAGE:{}]", image_path)
                } else {
                    format!("[AI_IMAGE:{}]", response.request_id)
                };
                
                // Save the image if data is provided
                if let Some(image_data) = response.image_data {
                    let image_filename = format!("ai_generated_{}.png", response.request_id);
                    let image_path = self.images_directory.join("ai_generated").join(&image_filename);
                    
                    // Create directory if it doesn't exist
                    if let Some(parent) = image_path.parent() {
                        let _ = std::fs::create_dir_all(parent);
                    }
                    
                    // Decode and save image
                    if let Ok(decoded_data) = general_purpose::STANDARD.decode(&image_data) {
                        if std::fs::write(&image_path, decoded_data).is_ok() {
                            // Add to available images
                            self.available_image_files.push(ImageFileEntry {
                                path: image_path,
                                name: image_filename.clone(),
                                source: ImageSource::AIGenerated,
                                thumbnail_available: false,
                            });
                        }
                    }
                }
                
                vec![
                    InputResult::ReplaceText {
                        find: format!("[AI_IMAGE_GENERATING:{}]", response.request_id),
                        replace: replacement_text,
                    },
                    InputResult::StatusMessage {
                        message: format!("AI image generation completed: {}", pending_request.prompt),
                    },
                ]
            } else {
                let error_msg = response.error_message.unwrap_or_else(|| "Unknown error".to_string());
                vec![
                    InputResult::ReplaceText {
                        find: format!("[AI_IMAGE_GENERATING:{}]", response.request_id),
                        replace: format!("[AI_IMAGE_FAILED:{}]", error_msg),
                    },
                    InputResult::StatusMessage {
                        message: format!("AI image generation failed: {}", error_msg),
                    },
                ]
            }
        } else {
            vec![InputResult::StatusMessage {
                message: "Received unknown AI image response".to_string(),
            }]
        }
    }

    /// Check for auto-exit conditions and timeouts
    pub fn update(&mut self) -> Vec<InputResult> {
        let mut results = Vec::new();

        // Check for edit mode auto-exit
        if let EnhancedInputMode::EditMode = self.current_mode {
            if let Some(exit_time) = self.edit_mode_state.auto_exit_timer {
                if Instant::now() > exit_time {
                    results.push(self.exit_edit_mode());
                }
            }
        }

        // Check for long press actions
        results.extend(self.check_long_press_actions());

        results
    }

    fn check_long_press_actions(&mut self) -> Vec<InputResult> {
        let mut results = Vec::new();

        for (button_name, state) in &self.button_states {
            if state.pressed {
                if let Some(press_time) = state.press_time {
                    let duration = Instant::now().duration_since(press_time);

                    // Check for 1-second long press for special actions
                    if duration >= Duration::from_millis(1000) {
                        match button_name.as_str() {
                            "A" => {
                                // Long press A for special character mode
                                self.current_mode = EnhancedInputMode::SpecialCharacterMode;
                                results.push(InputResult::ModeChange {
                                    new_mode: self.current_mode.clone(),
                                });
                            }
                            _ => {}
                        }
                    }
                }
            }
        }

        results
    }
    
    /// Get radial menu rendering data for UI display
    pub fn get_radial_menu_render_data(&self) -> Option<RadialMenuRenderData> {
        if let EnhancedInputMode::RadialMenu { state } = &self.current_mode {
            if state.is_visible {
                return Some(state.get_render_data());
            }
        }
        None
    }

    /// Get current input mode status for UI display
    pub fn get_mode_display(&self) -> String {
        match &self.current_mode {
            EnhancedInputMode::Navigation => "Navigation".to_string(),
            EnhancedInputMode::EditMode => "Edit Mode".to_string(),
            EnhancedInputMode::OneTimeKeyboard { .. } => "Keyboard".to_string(),
            EnhancedInputMode::RadialMenu { state } => format!("Radial: {:?}", state.active_direction),
            EnhancedInputMode::SpecialCharacterMode => "Special Characters".to_string(),
            EnhancedInputMode::P2PBrowser => "P2P Browser".to_string(),
            EnhancedInputMode::CollaborationMode => "Collaboration".to_string(),
            EnhancedInputMode::DocumentSaver => "Document Saver".to_string(),
            EnhancedInputMode::ImageMenu { submenu } => {
                match submenu {
                    ImageSubmenu::Main => "Image Menu".to_string(),
                    ImageSubmenu::FileSelection { .. } => "Select Image File".to_string(),
                    ImageSubmenu::AIGeneration => "AI Image Generation".to_string(),
                }
            }
            EnhancedInputMode::AIImagePrompt { .. } => "AI Image Prompt".to_string(),
            EnhancedInputMode::SecurePairing { .. } => "Secure Pairing".to_string(),
            EnhancedInputMode::SecureDeviceSelection { .. } => "Select Device".to_string(),
            EnhancedInputMode::RelationshipManager => "Relationship Manager".to_string(),
        }
    }

    /// Draw a simple ASCII representation of the radial menu (for terminal display)
    pub fn draw_radial_menu_ascii(&self) -> String {
        if let Some(render_data) = self.get_radial_menu_render_data() {
            let mut output = String::new();
            output.push_str(&format!("\n=== Radial Menu ({:?}) ===\n", render_data.direction));
            output.push_str("       ○ (center)\n");
            output.push_str("\n");
            
            for (i, option) in render_data.options.iter().enumerate() {
                let marker = if option.selected { "►" } else { " " };
                output.push_str(&format!(
                    "{} [{}] {} - '{}'\n", 
                    marker, 
                    option.button_hint, 
                    if option.selected { "<<" } else { "  " },
                    option.character
                ));
            }
            
            output.push_str("\nPress D-pad to change direction\n");
            output.push_str("Press L1/B/A/Y to select option\n");
            output.push_str("Press SELECT to exit\n");
            output
        } else {
            String::from("Radial menu not active")
        }
    }

    /// Get cursor information for UI display
    pub fn get_cursor_info(&self) -> CursorInfo {
        CursorInfo {
            position: self.cursor_position,
            line: self.edit_mode_state.cursor_line,
            column: self.edit_mode_state.cursor_column,
            text_length: self.text_buffer.len(),
        }
    }

    /// Load a different controller configuration
    pub fn switch_controller_config(&mut self, new_config: InputConfig) {
        self.config = new_config;
        // Reset state to ensure compatibility
        self.current_mode = EnhancedInputMode::Navigation;
        self.button_states.clear();
    }
    
    /// Set radial menu center position (for different screen sizes)
    pub fn set_radial_menu_center(&mut self, x: f32, y: f32) {
        if let EnhancedInputMode::RadialMenu { state } = &mut self.current_mode {
            state.center_x = x;
            state.center_y = y;
        }
    }
    /// Handle P2P browser input
    fn handle_p2p_browser_input(&mut self, button: UniversalButton, pressed: bool) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Exit P2P browser
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // Download/open selected document
                vec![InputResult::SpecialAction {
                    action: "download_document".to_string(),
                }]
            }
            UniversalButton::X => {
                // Share current document
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    vec![self.share_current_document()]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Y => {
                // Enter collaboration mode
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    self.current_mode = EnhancedInputMode::CollaborationMode;
                    vec![InputResult::ModeChange {
                        new_mode: self.current_mode.clone(),
                    }]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Up => {
                vec![InputResult::Navigation {
                    direction: "browse_up".to_string(),
                }]
            }
            UniversalButton::Down => {
                vec![InputResult::Navigation {
                    direction: "browse_down".to_string(),
                }]
            }
            _ => vec![InputResult::NoAction],
        }
    }

    /// Handle collaboration mode input
    fn handle_collaboration_mode_input(&mut self, button: UniversalButton, pressed: bool) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Exit collaboration mode
                self.current_mode = EnhancedInputMode::Navigation;
                self.collaboration_state = None;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // Sync current changes
                vec![self.sync_collaborative_changes()]
            }
            UniversalButton::X => {
                // View participant list
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    vec![InputResult::SpecialAction {
                        action: "view_participants".to_string(),
                    }]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            _ => vec![InputResult::NoAction],
        }
    }

    /// Handle document saver input
    fn handle_document_saver_input(&mut self, button: UniversalButton, pressed: bool) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Exit document saver
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // Save document locally
                vec![self.save_document_locally()]
            }
            UniversalButton::X => {
                // Export to P2P network
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) && self.p2p_enabled {
                    vec![self.export_to_p2p()]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Y => {
                // Quick auto-save toggle
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    self.auto_save_enabled = !self.auto_save_enabled;
                    let status = if self.auto_save_enabled { "enabled" } else { "disabled" };
                    vec![InputResult::SpecialAction {
                        action: format!("auto_save_{}", status),
                    }]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            _ => vec![InputResult::NoAction],
        }
    }
}

#[derive(Debug, Clone)]
pub struct CursorInfo {
    pub position: usize,
    pub line: usize,
    pub column: usize,
    pub text_length: usize,
}

impl Default for EnhancedInputManager {
    fn default() -> Self {
        Self::new(InputConfig::default())
    }
}

/// Convenience functions for creating input managers with different configurations
impl EnhancedInputManager {
    pub fn gameboy_style() -> Self {
        Self::new(InputConfig::gameboy_default())
    }

    pub fn snes_style() -> Self {
        Self::new(InputConfig::snes_default())
    }

    pub fn from_config_file(path: &std::path::Path) -> Result<Self, Box<dyn std::error::Error>> {
        let config = InputConfig::load_from_file(path)?;
        Ok(Self::new(config))
    }

    /// Initialize P2P networking for document sharing
    pub fn enable_p2p(&mut self, device_name: String) -> Result<(), Box<dyn std::error::Error>> {
        if !self.p2p_enabled {
            let manager = P2PMeshManager::new(device_name, DeviceType::Anbernic("word_processor".to_string()))?;
            self.p2p_manager = Some(manager);
            self.p2p_enabled = true;
        }
        Ok(())
    }

    /// Disable P2P networking
    pub fn disable_p2p(&mut self) {
        self.p2p_manager = None;
        self.p2p_enabled = false;
    }

    /// Toggle P2P functionality
    pub fn toggle_p2p(&mut self) -> InputResult {
        if self.p2p_enabled {
            self.disable_p2p();
            InputResult::SpecialAction {
                action: "P2P disabled".to_string(),
            }
        } else {
            if let Err(_) = self.enable_p2p("handheld_device".to_string()) {
                InputResult::SpecialAction {
                    action: "P2P enable failed".to_string(),
                }
            } else {
                InputResult::SpecialAction {
                    action: "P2P enabled".to_string(),
                }
            }
        }
    }

    /// Share current document via P2P
    pub fn share_current_document(&mut self) -> InputResult {
        if let Some(_manager) = &mut self.p2p_manager {
            let shared_doc = SharedDocument {
                file_hash: self.calculate_document_hash(),
                filename: self.document_metadata.filename.clone(),
                content: self.text_buffer.clone(),
                author: self.document_metadata.author.clone(),
                created_time: self.document_metadata.created_time,
                last_modified: std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_secs(),
                tags: self.document_metadata.tags.clone(),
                file_size: self.text_buffer.len(),
                device_info: "handheld_word_processor".to_string(),
            };

            self.shared_documents.push(shared_doc.clone());
            
            InputResult::SpecialAction {
                action: format!("shared_document_{}", shared_doc.filename),
            }
        } else {
            InputResult::SpecialAction {
                action: "p2p_not_enabled".to_string(),
            }
        }
    }

    /// Sync collaborative changes
    pub fn sync_collaborative_changes(&mut self) -> InputResult {
        if let Some(collaboration_state) = &mut self.collaboration_state {
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs();
            
            collaboration_state.last_sync = now;
            
            let change_count = collaboration_state.pending_changes.len();
            collaboration_state.pending_changes.clear();
            
            InputResult::SpecialAction {
                action: format!("synced_{}_changes", change_count),
            }
        } else {
            InputResult::SpecialAction {
                action: "no_collaboration_session".to_string(),
            }
        }
    }

    /// Save document locally
    pub fn save_document_locally(&mut self) -> InputResult {
        self.update_document_metadata();
        
        InputResult::SpecialAction {
            action: format!("saved_{}", self.document_metadata.filename),
        }
    }

    /// Export document to P2P network
    pub fn export_to_p2p(&mut self) -> InputResult {
        if self.p2p_enabled {
            self.share_current_document()
        } else {
            InputResult::SpecialAction {
                action: "p2p_not_enabled".to_string(),
            }
        }
    }

    /// Calculate hash for current document
    pub fn calculate_document_hash(&self) -> String {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};
        
        let mut hasher = DefaultHasher::new();
        self.text_buffer.hash(&mut hasher);
        self.document_metadata.filename.hash(&mut hasher);
        format!("{:x}", hasher.finish())
    }

    /// Update document metadata
    pub fn update_document_metadata(&mut self) {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        self.document_metadata.last_modified = now;
        self.document_metadata.character_count = self.text_buffer.len();
        self.document_metadata.word_count = self.text_buffer.split_whitespace().count();
        self.document_metadata.version += 1;
    }

    /// Get P2P status information
    pub async fn get_p2p_status(&self) -> P2PStatus {
        let peer_count = if let Some(manager) = &self.p2p_manager {
            manager.get_peers().await.len()
        } else {
            0
        };
        
        P2PStatus {
            enabled: self.p2p_enabled,
            peer_count,
            shared_documents_count: self.shared_documents.len(),
            collaboration_active: self.collaboration_state.is_some(),
        }
    }

    /// Start a collaborative editing session
    pub async fn start_collaboration_session(&mut self, session_id: String) {
        let participants = if let Some(manager) = &self.p2p_manager {
            manager.get_peers().await.into_iter().map(|p| p.device_id).collect()
        } else {
            Vec::new()
        };
        
        self.collaboration_state = Some(CollaborationState {
            session_id,
            participants,
            document_hash: self.calculate_document_hash(),
            last_sync: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs(),
            pending_changes: Vec::new(),
        });
    }

    /// Add a collaborative change to the pending queue
    pub fn add_collaborative_change(&mut self, change_type: ChangeType, position: usize, content: String) {
        if let Some(collaboration_state) = &mut self.collaboration_state {
            let change = DocumentChange {
                change_id: format!("{}-{}", 
                    std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap()
                        .as_nanos(),
                    position
                ),
                author: self.document_metadata.author.clone(),
                timestamp: std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_secs(),
                change_type,
                position,
                content,
            };
            
            collaboration_state.pending_changes.push(change);
        }
    }

    /// Handle secure pairing input
    fn handle_secure_pairing_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        stage: SecurePairingStage,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Exit secure pairing
                self.current_mode = EnhancedInputMode::Navigation;
                self.pairing_mode_active = false;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // Progress through pairing stages
                match stage {
                    SecurePairingStage::Initiating => {
                        // Start pairing process
                        vec![InputResult::SpecialAction {
                            action: "start_secure_pairing".to_string(),
                        }]
                    }
                    SecurePairingStage::DeviceSelection { devices } => {
                        // Move to device selection mode
                        self.current_mode = EnhancedInputMode::SecureDeviceSelection { devices };
                        vec![InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        }]
                    }
                    _ => vec![InputResult::NoAction],
                }
            }
            _ => vec![InputResult::NoAction],
        }
    }

    /// Handle secure device selection input
    fn handle_secure_device_selection_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        devices: Vec<CryptoPairingEmoji>,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Go back to pairing mode
                self.current_mode = EnhancedInputMode::SecurePairing {
                    stage: SecurePairingStage::DeviceSelection { devices },
                };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // Select current device (simplified - would need navigation)
                if let Some(device) = devices.first() {
                    self.current_mode = EnhancedInputMode::SecurePairing {
                        stage: SecurePairingStage::NicknameEntry {
                            target_device: device.clone(),
                            partial_nickname: String::new(),
                        },
                    };
                    vec![InputResult::ModeChange {
                        new_mode: self.current_mode.clone(),
                    }]
                } else {
                    vec![InputResult::StatusMessage {
                        message: "No devices available".to_string(),
                    }]
                }
            }
            _ => vec![InputResult::NoAction],
        }
    }

    /// Handle relationship manager input
    fn handle_relationship_manager_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Exit relationship manager
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // View relationship details
                vec![InputResult::SpecialAction {
                    action: "view_relationship_details".to_string(),
                }]
            }
            UniversalButton::X => {
                // Start new pairing (if SNES controller)
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    self.current_mode = EnhancedInputMode::SecurePairing {
                        stage: SecurePairingStage::Initiating,
                    };
                    vec![InputResult::ModeChange {
                        new_mode: self.current_mode.clone(),
                    }]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            _ => vec![InputResult::NoAction],
        }
    }
}

impl std::fmt::Debug for EnhancedInputManager {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("EnhancedInputManager")
            .field("config", &self.config)
            .field("current_mode", &self.current_mode)
            .field("text_buffer", &self.text_buffer)
            .field("cursor_position", &self.cursor_position)
            .field("edit_mode_state", &self.edit_mode_state)
            .field("one_time_keyboard_state", &self.one_time_keyboard_state)
            .field("button_states", &self.button_states)
            .field("last_input_time", &self.last_input_time)
            .field("p2p_enabled", &self.p2p_enabled)
            .field("shared_documents", &self.shared_documents)
            .field("auto_save_enabled", &self.auto_save_enabled)
            .field("document_metadata", &self.document_metadata)
            .field("collaboration_state", &self.collaboration_state)
            .field("p2p_manager", &"<P2PMeshManager>")
            .finish()
    }
}

/// P2P status information for UI display
#[derive(Debug, Clone)]
pub struct P2PStatus {
    pub enabled: bool,
    pub peer_count: usize,
    pub shared_documents_count: usize,
    pub collaboration_active: bool,
}

/// Implement P2P integration trait for enhanced input manager
impl P2PIntegration for EnhancedInputManager {
    fn get_p2p_manager(&self) -> &P2PMeshManager {
        self.p2p_manager.as_ref().expect("P2P manager not initialized")
    }

    async fn share_file(&self, file_path: std::path::PathBuf) -> Result<String, Box<dyn std::error::Error>> {
        self.get_p2p_manager()
            .share_file(file_path, None, vec!["document".to_string(), "handheld".to_string()])
            .await
    }

    async fn search_shared_files(
        &self,
        query: String,
    ) -> Result<Vec<SharedFile>, Box<dyn std::error::Error>> {
        self.get_p2p_manager().search_files(query, vec!["document".to_string()]).await
    }

    async fn get_mesh_peers(&self) -> Vec<PeerDevice> {
        self.get_p2p_manager().get_peers().await
    }
}

```

- **P2P Mesh Networking** (`src/p2p_mesh.rs`) - Encrypted collaborative editing and file sharing

**📄 Full content of src/p2p_mesh.rs:**

```
/// Peer-to-peer mesh file sharing system for Anbernic handhelds
/// Enables direct file sharing between devices on the same network
/// Optimized for low-bandwidth, battery-efficient operation
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::net::{IpAddr, SocketAddr};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream, UdpSocket};
use tokio::sync::{broadcast, RwLock};
use tokio::time;

/// File metadata for P2P sharing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedFile {
    pub id: String,
    pub filename: String,
    pub file_path: PathBuf,
    pub file_size: u64,
    pub file_hash: String,
    pub mime_type: String,
    pub shared_by: String,
    pub timestamp: u64,
    pub description: Option<String>,
    pub tags: Vec<String>,
}

/// Peer device information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerDevice {
    pub device_id: String,
    pub device_name: String,
    pub ip_address: IpAddr,
    pub port: u16,
    pub last_seen: u64,
    pub battery_level: Option<u8>,
    pub device_type: DeviceType,
    pub shared_files: Vec<SharedFile>,
}

/// Type of device in the mesh
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeviceType {
    Anbernic(String), // Model name
    Desktop,
    Mobile,
    Unknown,
}

/// P2P message types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum P2PMessage {
    Discovery {
        device_info: PeerDevice,
    },
    FileShare {
        file_info: SharedFile,
        chunk_data: Option<Vec<u8>>,
        chunk_index: u32,
        total_chunks: u32,
    },
    FileRequest {
        file_id: String,
        chunk_index: Option<u32>,
    },
    FileList {
        files: Vec<SharedFile>,
    },
    Heartbeat {
        device_id: String,
        battery_level: Option<u8>,
    },
    SearchRequest {
        query: String,
        file_types: Vec<String>,
    },
    SearchResponse {
        results: Vec<SharedFile>,
        query: String,
    },
}

/// File transfer chunk for efficient streaming
#[derive(Debug, Clone)]
pub struct FileChunk {
    pub file_id: String,
    pub chunk_index: u32,
    pub total_chunks: u32,
    pub data: Vec<u8>,
    pub checksum: String,
}

/// P2P mesh network manager
pub struct P2PMeshManager {
    pub device_info: PeerDevice,
    pub peers: Arc<RwLock<HashMap<String, PeerDevice>>>,
    pub shared_files: Arc<RwLock<HashMap<String, SharedFile>>>,
    pub active_transfers: Arc<RwLock<HashMap<String, FileTransfer>>>,

    // Network components
    pub tcp_listener: Option<TcpListener>,
    pub udp_socket: Option<UdpSocket>,
    pub discovery_port: u16,
    pub transfer_port: u16,

    // Communication channels
    pub message_sender: broadcast::Sender<P2PMessage>,
    pub shutdown_signal: Arc<RwLock<bool>>,

    // Settings
    pub chunk_size: usize,
    pub discovery_interval: Duration,
    pub heartbeat_interval: Duration,
    pub max_concurrent_transfers: usize,
}

/// Active file transfer state
#[derive(Debug, Clone)]
pub struct FileTransfer {
    pub file_id: String,
    pub peer_id: String,
    pub filename: String,
    pub total_size: u64,
    pub transferred_bytes: u64,
    pub chunks_received: HashMap<u32, bool>,
    pub start_time: SystemTime,
    pub last_activity: SystemTime,
    pub transfer_type: TransferType,
}

#[derive(Debug, Clone)]
pub enum TransferType {
    Upload,
    Download,
}

impl P2PMeshManager {
    pub fn new(
        device_name: String,
        device_type: DeviceType,
    ) -> Result<Self, Box<dyn std::error::Error>> {
        let device_id = Self::generate_device_id();
        let (message_sender, _) = broadcast::channel(1000);

        let device_info = PeerDevice {
            device_id: device_id.clone(),
            device_name,
            ip_address: Self::get_local_ip()?,
            port: 8090, // Default P2P port
            last_seen: Self::current_timestamp(),
            battery_level: Self::get_battery_level(),
            device_type,
            shared_files: Vec::new(),
        };

        Ok(Self {
            device_info,
            peers: Arc::new(RwLock::new(HashMap::new())),
            shared_files: Arc::new(RwLock::new(HashMap::new())),
            active_transfers: Arc::new(RwLock::new(HashMap::new())),
            tcp_listener: None,
            udp_socket: None,
            discovery_port: 8091,
            transfer_port: 8090,
            message_sender,
            shutdown_signal: Arc::new(RwLock::new(false)),
            chunk_size: 32768, // 32KB chunks for efficient handheld transfer
            discovery_interval: Duration::from_secs(30),
            heartbeat_interval: Duration::from_secs(60),
            max_concurrent_transfers: 3,
        })
    }

    /// Start the P2P mesh networking
    pub async fn start(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        log::info!(
            "Starting P2P mesh network for device: {}",
            self.device_info.device_name
        );

        // Start TCP listener for file transfers
        self.start_tcp_listener().await?;

        // Start UDP socket for discovery
        self.start_udp_discovery().await?;

        // Start background tasks
        self.start_discovery_task().await;
        self.start_heartbeat_task().await;
        self.start_cleanup_task().await;

        log::info!("P2P mesh network started successfully");
        Ok(())
    }

    async fn start_tcp_listener(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let addr = SocketAddr::new(self.device_info.ip_address, self.transfer_port);
        let listener = TcpListener::bind(addr).await?;

        log::info!("TCP listener started on {}", addr);

        let peers = Arc::clone(&self.peers);
        let active_transfers = Arc::clone(&self.active_transfers);
        let shared_files = Arc::clone(&self.shared_files);
        let chunk_size = self.chunk_size;

        tokio::spawn(async move {
            loop {
                match listener.accept().await {
                    Ok((stream, peer_addr)) => {
                        log::debug!("New TCP connection from {}", peer_addr);

                        let peers_clone = Arc::clone(&peers);
                        let transfers_clone = Arc::clone(&active_transfers);
                        let files_clone = Arc::clone(&shared_files);

                        tokio::spawn(async move {
                            if let Err(e) = Self::handle_tcp_connection(
                                stream,
                                peers_clone,
                                transfers_clone,
                                files_clone,
                                chunk_size,
                            )
                            .await
                            {
                                log::error!("TCP connection error: {}", e);
                            }
                        });
                    }
                    Err(e) => {
                        log::error!("Failed to accept TCP connection: {}", e);
                    }
                }
            }
        });

        Ok(())
    }

    async fn start_udp_discovery(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let addr = SocketAddr::new(self.device_info.ip_address, self.discovery_port);
        let socket = Arc::new(UdpSocket::bind(addr).await?);

        log::info!("UDP discovery started on {}", addr);

        let peers = Arc::clone(&self.peers);
        let device_info = self.device_info.clone();
        let message_sender = self.message_sender.clone();
        let socket_clone = Arc::clone(&socket);

        tokio::spawn(async move {
            let mut buffer = [0; 4096];

            loop {
                match socket_clone.recv_from(&mut buffer).await {
                    Ok((len, peer_addr)) => {
                        let data = &buffer[..len];

                        if let Ok(message) = serde_json::from_slice::<P2PMessage>(data) {
                            if let Err(e) = Self::handle_discovery_message(
                                message,
                                peer_addr,
                                Arc::clone(&peers),
                                &device_info,
                                &socket_clone,
                                &message_sender,
                            )
                            .await
                            {
                                log::error!("Discovery message error: {}", e);
                            }
                        }
                    }
                    Err(e) => {
                        log::error!("UDP receive error: {}", e);
                    }
                }
            }
        });

        // We can't move the Arc<UdpSocket> directly into Option<UdpSocket>
        // For now, we'll set it to None and handle discovery differently
        self.udp_socket = None;
        Ok(())
    }

    async fn start_discovery_task(&self) {
        let device_info = self.device_info.clone();
        let discovery_interval = self.discovery_interval;
        let shutdown_signal = Arc::clone(&self.shutdown_signal);

        tokio::spawn(async move {
            let mut interval = time::interval(discovery_interval);

            loop {
                interval.tick().await;

                if *shutdown_signal.read().await {
                    break;
                }

                // Broadcast discovery message
                if let Err(e) = Self::broadcast_discovery(&device_info).await {
                    log::error!("Discovery broadcast error: {}", e);
                }
            }
        });
    }

    async fn start_heartbeat_task(&self) {
        let device_id = self.device_info.device_id.clone();
        let heartbeat_interval = self.heartbeat_interval;
        let peers = Arc::clone(&self.peers);
        let shutdown_signal = Arc::clone(&self.shutdown_signal);

        tokio::spawn(async move {
            let mut interval = time::interval(heartbeat_interval);

            loop {
                interval.tick().await;

                if *shutdown_signal.read().await {
                    break;
                }

                // Send heartbeat to all known peers
                let peers_read = peers.read().await;
                for peer in peers_read.values() {
                    if let Err(e) = Self::send_heartbeat(&device_id, peer).await {
                        log::debug!("Heartbeat failed to {}: {}", peer.device_name, e);
                    }
                }
            }
        });
    }

    async fn start_cleanup_task(&self) {
        let peers = Arc::clone(&self.peers);
        let active_transfers = Arc::clone(&self.active_transfers);
        let shutdown_signal = Arc::clone(&self.shutdown_signal);

        tokio::spawn(async move {
            let mut interval = time::interval(Duration::from_secs(300)); // 5 minutes

            loop {
                interval.tick().await;

                if *shutdown_signal.read().await {
                    break;
                }

                let now = Self::current_timestamp();

                // Clean up stale peers (not seen in 10 minutes)
                {
                    let mut peers_write = peers.write().await;
                    peers_write.retain(|_, peer| now - peer.last_seen < 600);
                }

                // Clean up failed transfers (inactive for 5 minutes)
                {
                    let mut transfers_write = active_transfers.write().await;
                    transfers_write.retain(|_, transfer| {
                        match transfer.last_activity.duration_since(UNIX_EPOCH) {
                            Ok(duration) => now - duration.as_secs() < 300,
                            Err(_) => false,
                        }
                    });
                }
            }
        });
    }

    /// Share a file with the mesh network
    pub async fn share_file(
        &self,
        file_path: PathBuf,
        description: Option<String>,
        tags: Vec<String>,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let metadata = tokio::fs::metadata(&file_path).await?;
        let file_size = metadata.len();

        // Calculate file hash
        let file_hash = self.calculate_file_hash(&file_path).await?;

        // Generate unique file ID
        let file_id = format!("{}_{}", self.device_info.device_id, file_hash);

        let filename = file_path
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("unknown")
            .to_string();

        let mime_type = Self::detect_mime_type(&file_path);

        let shared_file = SharedFile {
            id: file_id.clone(),
            filename,
            file_path: file_path.clone(),
            file_size,
            file_hash,
            mime_type,
            shared_by: self.device_info.device_id.clone(),
            timestamp: Self::current_timestamp(),
            description,
            tags,
        };

        // Add to local shared files
        self.shared_files
            .write()
            .await
            .insert(file_id.clone(), shared_file.clone());

        // Broadcast to peers
        self.broadcast_file_list().await?;

        log::info!("File shared: {} ({})", shared_file.filename, file_id);
        Ok(file_id)
    }

    /// Request a file from a peer
    pub async fn request_file(
        &self,
        file_id: String,
        peer_id: String,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let peers_read = self.peers.read().await;
        let peer = peers_read.get(&peer_id).ok_or("Peer not found")?;

        let file_info = peer
            .shared_files
            .iter()
            .find(|f| f.id == file_id)
            .ok_or("File not found on peer")?;

        // Create transfer record
        let transfer = FileTransfer {
            file_id: file_id.clone(),
            peer_id: peer_id.clone(),
            filename: file_info.filename.clone(),
            total_size: file_info.file_size,
            transferred_bytes: 0,
            chunks_received: HashMap::new(),
            start_time: SystemTime::now(),
            last_activity: SystemTime::now(),
            transfer_type: TransferType::Download,
        };

        self.active_transfers
            .write()
            .await
            .insert(file_id.clone(), transfer);

        // Send request to peer
        let request = P2PMessage::FileRequest {
            file_id: file_id.clone(),
            chunk_index: None, // Request entire file
        };

        self.send_message_to_peer(&request, peer).await?;

        log::info!(
            "Requested file: {} from {}",
            file_info.filename,
            peer.device_name
        );
        Ok(())
    }

    /// Search for files across the mesh
    pub async fn search_files(
        &self,
        query: String,
        file_types: Vec<String>,
    ) -> Result<Vec<SharedFile>, Box<dyn std::error::Error>> {
        let search_request = P2PMessage::SearchRequest {
            query: query.clone(),
            file_types,
        };

        // Send search to all peers
        let peers_read = self.peers.read().await;
        for peer in peers_read.values() {
            if let Err(e) = self.send_message_to_peer(&search_request, peer).await {
                log::debug!("Search request failed to {}: {}", peer.device_name, e);
            }
        }

        // Return local matches immediately
        let shared_files_read = self.shared_files.read().await;
        let local_results: Vec<SharedFile> = shared_files_read
            .values()
            .filter(|file| {
                file.filename.to_lowercase().contains(&query.to_lowercase())
                    || file.description.as_ref().map_or(false, |desc| {
                        desc.to_lowercase().contains(&query.to_lowercase())
                    })
                    || file
                        .tags
                        .iter()
                        .any(|tag| tag.to_lowercase().contains(&query.to_lowercase()))
            })
            .cloned()
            .collect();

        Ok(local_results)
    }

    /// Get list of all available files in the mesh
    pub async fn get_available_files(&self) -> Vec<SharedFile> {
        let mut all_files = Vec::new();

        // Add local files
        let shared_files_read = self.shared_files.read().await;
        all_files.extend(shared_files_read.values().cloned());

        // Add files from peers
        let peers_read = self.peers.read().await;
        for peer in peers_read.values() {
            all_files.extend(peer.shared_files.iter().cloned());
        }

        all_files
    }

    /// Get list of connected peers
    pub async fn get_peers(&self) -> Vec<PeerDevice> {
        let peers_read = self.peers.read().await;
        peers_read.values().cloned().collect()
    }

    /// Get active file transfers
    pub async fn get_active_transfers(&self) -> Vec<FileTransfer> {
        let transfers_read = self.active_transfers.read().await;
        transfers_read.values().cloned().collect()
    }

    /// Utility functions

    fn generate_device_id() -> String {
        let mut hasher = Sha256::new();
        hasher.update(format!("{:?}", SystemTime::now()));
        hasher.update(std::process::id().to_string());
        format!(
            "anbernic_{}",
            hex::encode(hasher.finalize())[..16].to_string()
        )
    }

    fn get_local_ip() -> Result<IpAddr, Box<dyn std::error::Error>> {
        // P2P-only compliance: Use WiFi Direct local interface discovery
        // This gets the local WiFi Direct interface IP for P2P communication
        // No router dependency - direct device-to-device networking
        
        // Get WiFi Direct interface IP (typically 192.168.49.x range for WiFi Direct)
        // This is the standard WiFi Direct GO (Group Owner) IP range
        let wifi_direct_ip = std::env::var("WIFI_DIRECT_LOCAL_IP")
            .unwrap_or_else(|_| "192.168.49.1".to_string()); // WiFi Direct standard range
            
        Ok(wifi_direct_ip.parse()?)
    }

    fn get_battery_level() -> Option<u8> {
        // Battery level detection for handheld devices
        // Placeholder - would integrate with actual battery APIs
        Some(85)
    }

    fn current_timestamp() -> u64 {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs()
    }

    async fn calculate_file_hash(
        &self,
        file_path: &Path,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let data = tokio::fs::read(file_path).await?;
        let mut hasher = Sha256::new();
        hasher.update(&data);
        Ok(hex::encode(hasher.finalize()))
    }

    fn detect_mime_type(file_path: &Path) -> String {
        match file_path.extension().and_then(|ext| ext.to_str()) {
            Some("mp3") => "audio/mpeg".to_string(),
            Some("mp4") => "video/mp4".to_string(),
            Some("jpg") | Some("jpeg") => "image/jpeg".to_string(),
            Some("png") => "image/png".to_string(),
            Some("txt") => "text/plain".to_string(),
            Some("pdf") => "application/pdf".to_string(),
            _ => "application/octet-stream".to_string(),
        }
    }

    async fn broadcast_discovery(
        device_info: &PeerDevice,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let message = P2PMessage::Discovery {
            device_info: device_info.clone(),
        };

        let data = serde_json::to_vec(&message)?;

        // Broadcast to local network
        let socket = UdpSocket::bind("0.0.0.0:0").await?;
        socket.set_broadcast(true)?;

        let broadcast_addr = SocketAddr::new("255.255.255.255".parse()?, 8091);
        socket.send_to(&data, broadcast_addr).await?;

        Ok(())
    }

    async fn broadcast_file_list(&self) -> Result<(), Box<dyn std::error::Error>> {
        let shared_files_read = self.shared_files.read().await;
        let files: Vec<SharedFile> = shared_files_read.values().cloned().collect();

        let message = P2PMessage::FileList { files };

        let peers_read = self.peers.read().await;
        for peer in peers_read.values() {
            if let Err(e) = self.send_message_to_peer(&message, peer).await {
                log::debug!("Failed to send file list to {}: {}", peer.device_name, e);
            }
        }

        Ok(())
    }

    async fn send_message_to_peer(
        &self,
        message: &P2PMessage,
        peer: &PeerDevice,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let data = serde_json::to_vec(message)?;
        let addr = SocketAddr::new(peer.ip_address, peer.port);

        let mut stream = TcpStream::connect(addr).await?;
        stream.write_all(&data).await?;

        Ok(())
    }

    async fn send_heartbeat(
        device_id: &str,
        peer: &PeerDevice,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let message = P2PMessage::Heartbeat {
            device_id: device_id.to_string(),
            battery_level: Self::get_battery_level(),
        };

        let data = serde_json::to_vec(&message)?;
        let addr = SocketAddr::new(peer.ip_address, peer.port);

        let mut stream = TcpStream::connect(addr).await?;
        stream.write_all(&data).await?;

        Ok(())
    }

    async fn handle_tcp_connection(
        mut stream: TcpStream,
        peers: Arc<RwLock<HashMap<String, PeerDevice>>>,
        active_transfers: Arc<RwLock<HashMap<String, FileTransfer>>>,
        shared_files: Arc<RwLock<HashMap<String, SharedFile>>>,
        chunk_size: usize,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut buffer = vec![0; chunk_size];
        let len = stream.read(&mut buffer).await?;
        buffer.truncate(len);

        if let Ok(message) = serde_json::from_slice::<P2PMessage>(&buffer) {
            match message {
                P2PMessage::FileRequest {
                    file_id,
                    chunk_index,
                } => {
                    // Handle file request
                    let shared_files_read = shared_files.read().await;
                    if let Some(file_info) = shared_files_read.get(&file_id) {
                        Self::send_file_chunk(&mut stream, file_info, chunk_index, chunk_size)
                            .await?;
                    }
                }
                _ => {
                    log::debug!("Received TCP message: {:?}", message);
                }
            }
        }

        Ok(())
    }

    async fn send_file_chunk(
        stream: &mut TcpStream,
        file_info: &SharedFile,
        chunk_index: Option<u32>,
        chunk_size: usize,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let file_data = tokio::fs::read(&file_info.file_path).await?;
        let total_chunks = (file_data.len() + chunk_size - 1) / chunk_size;

        match chunk_index {
            Some(index) => {
                // Send specific chunk
                let start = (index as usize) * chunk_size;
                let end = std::cmp::min(start + chunk_size, file_data.len());
                let chunk_data = file_data[start..end].to_vec();

                let message = P2PMessage::FileShare {
                    file_info: file_info.clone(),
                    chunk_data: Some(chunk_data),
                    chunk_index: index,
                    total_chunks: total_chunks as u32,
                };

                let data = serde_json::to_vec(&message)?;
                stream.write_all(&data).await?;
            }
            None => {
                // Send entire file in chunks
                for i in 0..total_chunks {
                    let start = i * chunk_size;
                    let end = std::cmp::min(start + chunk_size, file_data.len());
                    let chunk_data = file_data[start..end].to_vec();

                    let message = P2PMessage::FileShare {
                        file_info: file_info.clone(),
                        chunk_data: Some(chunk_data),
                        chunk_index: i as u32,
                        total_chunks: total_chunks as u32,
                    };

                    let data = serde_json::to_vec(&message)?;
                    stream.write_all(&data).await?;

                    // Small delay between chunks for battery efficiency
                    tokio::time::sleep(Duration::from_millis(10)).await;
                }
            }
        }

        Ok(())
    }

    async fn handle_discovery_message(
        message: P2PMessage,
        peer_addr: SocketAddr,
        peers: Arc<RwLock<HashMap<String, PeerDevice>>>,
        device_info: &PeerDevice,
        socket: &Arc<UdpSocket>,
        message_sender: &broadcast::Sender<P2PMessage>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match message {
            P2PMessage::Discovery {
                device_info: peer_info,
            } => {
                let mut peer_info = peer_info;
                // Update peer info
                peer_info.ip_address = peer_addr.ip();
                peer_info.last_seen = Self::current_timestamp();

                let mut peers_write = peers.write().await;
                peers_write.insert(peer_info.device_id.clone(), peer_info.clone());

                // Send our discovery response
                let response = P2PMessage::Discovery {
                    device_info: device_info.clone(),
                };
                let data = serde_json::to_vec(&response)?;
                socket.send_to(&data, peer_addr).await?;

                // Notify application
                let discovery_message = P2PMessage::Discovery {
                    device_info: peer_info.clone(),
                };
                let _ = message_sender.send(discovery_message);
            }
            _ => {
                log::debug!("Received UDP message: {:?}", message);
            }
        }

        Ok(())
    }

    /// Shutdown the P2P mesh
    pub async fn shutdown(&self) -> Result<(), Box<dyn std::error::Error>> {
        *self.shutdown_signal.write().await = true;
        log::info!("P2P mesh shutting down");
        Ok(())
    }
}

/// Helper trait for applications to integrate P2P file sharing
pub trait P2PIntegration {
    fn get_p2p_manager(&self) -> &P2PMeshManager;

    async fn share_file(&self, file_path: PathBuf) -> Result<String, Box<dyn std::error::Error>> {
        self.get_p2p_manager()
            .share_file(file_path, None, vec![])
            .await
    }

    async fn search_shared_files(
        &self,
        query: String,
    ) -> Result<Vec<SharedFile>, Box<dyn std::error::Error>> {
        self.get_p2p_manager().search_files(query, vec![]).await
    }

    async fn get_mesh_peers(&self) -> Vec<PeerDevice> {
        self.get_p2p_manager().get_peers().await
    }
}

```

- **Cryptographic Manager** (`src/crypto.rs`) - Modern crypto stack for secure communication

**📄 Full content of src/crypto.rs:**

```
/// Cryptographic operations for OfficeOS
/// Implements relationship-based encryption using modern cryptographic primitives (Ed25519, X25519, ChaCha20-Poly1305)
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};
use thiserror::Error;
use base64::Engine;

pub mod keypair;
pub mod relationship;
pub mod storage;
pub mod pairing;
pub mod packet;
pub mod p2p_integration;
pub mod migration_adapter;
pub mod bytecode;
pub mod bytecode_executor;
pub mod types;

pub use keypair::*;
pub use relationship::*;
pub use storage::*;
pub use pairing::*;
pub use packet::*;
pub use p2p_integration::*;
pub use migration_adapter::*;
pub use bytecode::*;
pub use bytecode_executor::*;
pub use types::*;

/// Main cryptographic manager for OfficeOS
pub struct CryptoManager {
    /// Our device's master keypair
    device_keypair: DeviceKeypair,
    /// Storage for relationship-specific keys
    key_storage: KeyStorage,
    /// Active relationships with other devices
    relationships: HashMap<RelationshipId, RelationshipContext>,
    /// Pairing session manager
    pairing_manager: PairingManager,
    /// Configuration
    config: CryptoConfig,
}

/// Configuration for cryptographic operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CryptoConfig {
    /// Directory for storing encrypted key files
    pub key_storage_dir: PathBuf,
    /// How long to remember relationships without contact (seconds)
    pub relationship_timeout: u64,
    /// Whether to use hardware security features if available
    pub use_hardware_security: bool,
    /// Encryption algorithm preferences
    pub cipher_preferences: Vec<CipherSuite>,
}

/// Supported cipher suites
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum CipherSuite {
    /// ChaCha20-Poly1305 (recommended for embedded devices)
    ChaCha20Poly1305,
    /// AES-256-GCM (when hardware acceleration available)
    Aes256Gcm,
    /// Ed25519 for signing
    Ed25519,
}

// RelationshipId is now defined in types.rs

/// Context for a specific relationship
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RelationshipContext {
    /// Unique identifier for this relationship
    pub id: RelationshipId,
    /// User-assigned nickname for the other device
    pub nickname: String,
    /// Keypair specific to this relationship
    pub keypair: RelationshipKeypair,
    /// Other device's public key for this relationship
    pub peer_public_key: PublicKey,
    /// When this relationship was established
    pub created_at: u64,
    /// Last time we communicated with this device
    pub last_contact: u64,
    /// Whether this relationship should be forgotten after timeout
    pub auto_forget: bool,
}

/// Error types for cryptographic operations
#[derive(Error, Debug)]
pub enum CryptoError {
    #[error("Key generation failed: {0}")]
    KeyGeneration(String),
    #[error("Encryption failed: {0}")]
    Encryption(String),
    #[error("Decryption failed: {0}")]
    Decryption(String),
    #[error("Invalid key format: {0}")]
    InvalidKey(String),
    #[error("Relationship not found: {0}")]
    RelationshipNotFound(String),
    #[error("Storage error: {0}")]
    Storage(String),
    #[error("Pairing failed: {0}")]
    Pairing(String),
    #[error("Signature verification failed")]
    SignatureVerification,
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

pub type CryptoResult<T> = Result<T, CryptoError>;

impl Default for CryptoConfig {
    fn default() -> Self {
        Self {
            key_storage_dir: PathBuf::from("./keys"),
            relationship_timeout: 30 * 24 * 60 * 60, // 30 days
            use_hardware_security: true,
            cipher_preferences: vec![
                CipherSuite::ChaCha20Poly1305,
                CipherSuite::Ed25519,
                CipherSuite::Aes256Gcm,
            ],
        }
    }
}

impl CryptoManager {
    /// Create a new crypto manager with default configuration
    pub fn new() -> CryptoResult<Self> {
        Self::with_config(CryptoConfig::default())
    }

    /// Create a new crypto manager with specific configuration
    pub fn with_config(config: CryptoConfig) -> CryptoResult<Self> {
        // Generate or load device master keypair
        let device_keypair = DeviceKeypair::generate_or_load(&config.key_storage_dir)?;
        
        // Initialize key storage
        let key_storage = KeyStorage::new(&config.key_storage_dir)?;
        
        // Initialize pairing manager
        let pairing_manager = PairingManager::new(device_keypair.public_key.clone());

        Ok(Self {
            device_keypair,
            key_storage,
            relationships: HashMap::new(),
            pairing_manager,
            config,
        })
    }

    /// Get our device's public key for pairing
    pub fn get_device_public_key(&self) -> &PublicKey {
        &self.device_keypair.public_key
    }

    /// Start pairing mode and return our emoji
    pub fn enter_pairing_mode(&mut self) -> CryptoResult<PairingEmoji> {
        self.pairing_manager.enter_pairing_mode()
    }

    /// Get list of devices currently in pairing mode
    pub fn get_discovered_devices(&mut self) -> Vec<PairingEmoji> {
        self.pairing_manager.get_discovered_devices()
    }

    /// Establish a new relationship with a device
    pub fn establish_relationship(
        &mut self,
        peer_emoji: PairingEmoji,
        nickname: String,
    ) -> CryptoResult<RelationshipId> {
        // Complete pairing process to get peer's public key
        let peer_public_key = self.pairing_manager.complete_pairing(&peer_emoji)?;
        
        // Generate relationship-specific keypair
        let relationship_keypair = RelationshipKeypair::generate()?;
        
        // Create relationship ID from both public keys
        let relationship_id = RelationshipId::from_keys(
            &self.device_keypair.public_key,
            &peer_public_key,
        );
        
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
            
        let context = RelationshipContext {
            id: relationship_id.clone(),
            nickname,
            keypair: relationship_keypair,
            peer_public_key,
            created_at: now,
            last_contact: now,
            auto_forget: true, // Default to auto-forget as per vision
        };
        
        // Store relationship
        self.key_storage.store_relationship(&context)?;
        self.relationships.insert(relationship_id.clone(), context);
        
        Ok(relationship_id)
    }

    /// Encrypt data for a specific relationship
    pub fn encrypt_for_relationship(
        &self,
        relationship_id: &RelationshipId,
        data: &[u8],
    ) -> CryptoResult<EncryptedPacket> {
        let relationship = self.relationships.get(relationship_id)
            .ok_or_else(|| CryptoError::RelationshipNotFound(relationship_id.0.clone()))?;
            
        // Create encrypted packet with relationship public key in header
        EncryptedPacket::create(
            data,
            &relationship.keypair.private_key,
            &relationship.peer_public_key,
            &relationship.keypair.public_key,
        )
    }

    /// Decrypt data using the appropriate relationship key
    pub fn decrypt_packet(&self, packet: &EncryptedPacket) -> CryptoResult<Vec<u8>> {
        // Find relationship by the public key in packet header
        for (_, relationship) in &self.relationships {
            if relationship.keypair.public_key == packet.intended_recipient_key {
                return packet.decrypt(&relationship.keypair.private_key);
            }
        }
        
        Err(CryptoError::RelationshipNotFound(
            "No matching relationship for packet".to_string()
        ))
    }

    /// Update last contact time for a relationship
    pub fn update_last_contact(&mut self, relationship_id: &RelationshipId) {
        if let Some(relationship) = self.relationships.get_mut(relationship_id) {
            relationship.last_contact = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs();
        }
    }

    /// Clean up expired relationships
    pub fn cleanup_expired_relationships(&mut self) -> CryptoResult<usize> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
            
        let mut expired = Vec::new();
        
        for (id, relationship) in &self.relationships {
            if relationship.auto_forget && 
               (now - relationship.last_contact) > self.config.relationship_timeout {
                expired.push(id.clone());
            }
        }
        
        let count = expired.len();
        for id in expired {
            self.relationships.remove(&id);
            self.key_storage.remove_relationship(&id)?;
        }
        
        Ok(count)
    }

    /// Load all stored relationships
    pub fn load_relationships(&mut self) -> CryptoResult<()> {
        let relationships = self.key_storage.load_all_relationships()?;
        for relationship in relationships {
            self.relationships.insert(relationship.id.clone(), relationship);
        }
        Ok(())
    }

    /// Get list of active relationships
    pub fn get_relationships(&self) -> Vec<&RelationshipContext> {
        self.relationships.values().collect()
    }

    /// Export relationship for backup (encrypted with device key)
    pub fn export_relationship(&self, relationship_id: &RelationshipId) -> CryptoResult<String> {
        let relationship = self.relationships.get(relationship_id)
            .ok_or_else(|| CryptoError::RelationshipNotFound(relationship_id.0.clone()))?;
            
        // Serialize and encrypt with device master key
        let serialized = serde_json::to_vec(relationship)
            .map_err(|e| CryptoError::Storage(e.to_string()))?;
            
        let encrypted = self.device_keypair.encrypt(&serialized)?;
        Ok(base64::engine::general_purpose::STANDARD.encode(encrypted))
    }

    /// Import relationship from backup
    pub fn import_relationship(&mut self, encrypted_data: &str) -> CryptoResult<RelationshipId> {
        let encrypted = base64::engine::general_purpose::STANDARD.decode(encrypted_data)
            .map_err(|e| CryptoError::InvalidKey(e.to_string()))?;
            
        let decrypted = self.device_keypair.decrypt(&encrypted)?;
        let relationship: RelationshipContext = serde_json::from_slice(&decrypted)
            .map_err(|e| CryptoError::Storage(e.to_string()))?;
            
        let id = relationship.id.clone();
        self.key_storage.store_relationship(&relationship)?;
        self.relationships.insert(id.clone(), relationship);
        
        Ok(id)
    }
}

impl RelationshipId {
    /// Generate a relationship ID from two public keys
    pub fn from_keys(key1: &PublicKey, key2: &PublicKey) -> Self {
        use sha2::{Digest, Sha256};
        
        // Sort keys to ensure consistent ID regardless of order
        let mut keys = vec![key1.as_bytes(), key2.as_bytes()];
        keys.sort();
        
        let mut hasher = Sha256::new();
        for key in keys {
            hasher.update(key);
        }
        
        let hash = hasher.finalize();
        Self(hex::encode(&hash[..16])) // Use first 16 bytes as relationship ID
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_crypto_manager_creation() {
        let temp_dir = TempDir::new().unwrap();
        let config = CryptoConfig {
            key_storage_dir: temp_dir.path().to_path_buf(),
            ..Default::default()
        };
        
        let manager = CryptoManager::with_config(config).unwrap();
        assert!(!manager.get_device_public_key().as_bytes().is_empty());
    }

    #[test]
    fn test_relationship_id_consistency() {
        let keypair1 = RelationshipKeypair::generate().unwrap();
        let keypair2 = RelationshipKeypair::generate().unwrap();
        
        let id1 = RelationshipId::from_keys(&keypair1.public_key, &keypair2.public_key);
        let id2 = RelationshipId::from_keys(&keypair2.public_key, &keypair1.public_key);
        
        assert_eq!(id1, id2);
    }
}
```

- **Project Daemon** (`src/daemon.rs`) - Central message broker with TCP server

**📄 Full content of src/daemon.rs:**

```
use log::{debug, error, info};
use rand::Rng;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{broadcast, RwLock};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub id: String,
    pub sender: String,
    pub content: String,
    pub timestamp: u64,
    pub message_type: MessageType,
    pub is_encrypted: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MessageType {
    Text,
    Command,
    LlmRequest,
    LlmResponse,
    StateSync,
}

#[derive(Debug, Clone)]
pub struct ClientInfo {
    pub id: String,
    pub device_type: DeviceType,
    pub last_seen: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeviceType {
    Handheld,
    Desktop,
    Cluster,
}

/// Per-relationship encryption manager for daemon communications
#[derive(Debug, Clone)]
pub struct DaemonCryptoManager {
    pub device_id: String,
    pub private_key: String,
    pub public_key: String,
    pub relationship_keys: HashMap<String, (String, String)>, // client_id -> (private_key, public_key)
    pub encryption_enabled: bool,
}

pub struct ProjectDaemon {
    clients: Arc<RwLock<HashMap<String, ClientInfo>>>,
    message_sender: broadcast::Sender<Message>,
    state: Arc<RwLock<HashMap<String, serde_json::Value>>>,
    crypto: Arc<RwLock<DaemonCryptoManager>>,
}

impl ProjectDaemon {
    pub fn new() -> Self {
        let (tx, _) = broadcast::channel(1000);

        // Generate unique device ID for daemon
        let device_id = format!("daemon_{:016x}", rand::thread_rng().gen::<u64>());
        let (private_key, public_key) = Self::generate_keypair();

        let crypto = DaemonCryptoManager {
            device_id,
            private_key,
            public_key,
            relationship_keys: HashMap::new(),
            encryption_enabled: true,
        };

        Self {
            clients: Arc::new(RwLock::new(HashMap::new())),
            message_sender: tx,
            state: Arc::new(RwLock::new(HashMap::new())),
            crypto: Arc::new(RwLock::new(crypto)),
        }
    }

    fn generate_keypair() -> (String, String) {
        let mut rng = rand::thread_rng();
        let private_key = format!("DAEMON_PRIV_{:032x}", rng.gen::<u128>());
        let public_key = format!("DAEMON_PUB_{:032x}", rng.gen::<u128>());
        (private_key, public_key)
    }

    pub async fn start(&self, port: u16) -> Result<(), Box<dyn std::error::Error>> {
        let listener = TcpListener::bind(format!("127.0.0.1:{}", port)).await?; // Security: localhost only
        info!("Project daemon listening on localhost:{} (air-gapped compliance)", port);

        // Start state persistence task
        self.start_state_persistence().await;

        loop {
            match listener.accept().await {
                Ok((stream, addr)) => {
                    // Security: Validate connection is from authorized localhost only
                    if !addr.ip().is_loopback() {
                        error!("Rejected non-localhost connection from: {}", addr);
                        continue;
                    }
                    
                    info!("New authorized client connected: {}", addr);
                    let daemon = self.clone();
                    tokio::spawn(async move {
                        if let Err(e) = daemon.handle_client(stream).await {
                            error!("Client handler error: {}", e);
                        }
                    });
                }
                Err(e) => {
                    error!("Failed to accept connection: {}", e);
                }
            }
        }
    }

    async fn handle_client(&self, mut stream: TcpStream) -> Result<(), Box<dyn std::error::Error>> {
        let mut buffer = vec![0; 1024];
        let mut message_receiver = self.message_sender.subscribe();

        loop {
            tokio::select! {
                // Handle incoming messages from client
                result = stream.read(&mut buffer) => {
                    match result {
                        Ok(0) => break, // Connection closed
                        Ok(n) => {
                            let data = &buffer[..n];
                            if let Ok(message) = serde_json::from_slice::<Message>(data) {
                                self.process_message(message).await?;
                            }
                        }
                        Err(e) => {
                            error!("Read error: {}", e);
                            break;
                        }
                    }
                }

                // Forward messages to client
                message = message_receiver.recv() => {
                    match message {
                        Ok(msg) => {
                            let serialized = serde_json::to_vec(&msg)?;
                            if let Err(e) = stream.write_all(&serialized).await {
                                error!("Write error: {}", e);
                                break;
                            }
                        }
                        Err(_) => break,
                    }
                }
            }
        }

        Ok(())
    }

    async fn process_message(
        &self,
        mut message: Message,
    ) -> Result<(), Box<dyn std::error::Error>> {
        debug!("Processing message: {:?}", message);

        // Decrypt message if it's encrypted
        if message.is_encrypted {
            let mut crypto = self.crypto.write().await;
            match crypto.decrypt_from_client(&message.content, &message.sender) {
                Ok(decrypted_content) => {
                    message.content = decrypted_content;
                    message.is_encrypted = false;
                }
                Err(e) => {
                    error!("Failed to decrypt message from {}: {}", message.sender, e);
                    return Ok(()); // Skip processing encrypted messages we can't decrypt
                }
            }
        }

        match message.message_type {
            MessageType::LlmRequest => {
                // Forward to desktop LLM service
                self.forward_to_llm_service(message).await?;
            }
            MessageType::StateSync => {
                // Update daemon state
                self.update_state(&message).await?;
            }
            _ => {
                // Broadcast to all clients
                if let Err(e) = self.message_sender.send(message) {
                    error!("Failed to broadcast message: {}", e);
                }
            }
        }

        Ok(())
    }

    async fn forward_to_llm_service(
        &self,
        message: Message,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Find desktop/cluster clients
        let clients = self.clients.read().await;
        for (_, client) in clients.iter() {
            match client.device_type {
                DeviceType::Desktop | DeviceType::Cluster => {
                    // Forward message to LLM service
                    if let Err(e) = self.message_sender.send(message.clone()) {
                        error!("Failed to forward to LLM service: {}", e);
                    }
                    break;
                }
                _ => continue,
            }
        }
        Ok(())
    }

    async fn update_state(&self, message: &Message) -> Result<(), Box<dyn std::error::Error>> {
        let mut state = self.state.write().await;
        if let Ok(value) = serde_json::from_str(&message.content) {
            state.insert(message.sender.clone(), value);
        }
        Ok(())
    }

    async fn start_state_persistence(&self) {
        let state = Arc::clone(&self.state);
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(std::time::Duration::from_secs(30));

            loop {
                interval.tick().await;
                let state_snapshot = state.read().await;

                // Save state to files/build directory
                if let Ok(serialized) = serde_json::to_string_pretty(&*state_snapshot) {
                    if let Err(e) =
                        tokio::fs::write("files/build/daemon_state.json", serialized).await
                    {
                        error!("Failed to save state: {}", e);
                    }
                }
            }
        });
    }
}

impl Clone for ProjectDaemon {
    fn clone(&self) -> Self {
        Self {
            clients: Arc::clone(&self.clients),
            message_sender: self.message_sender.clone(),
            state: Arc::clone(&self.state),
            crypto: Arc::clone(&self.crypto),
        }
    }
}

impl DaemonCryptoManager {
    /// Encrypt a message for a specific client using per-relationship keys
    pub fn encrypt_for_client(
        &mut self,
        content: &str,
        client_id: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if !self.encryption_enabled {
            return Ok(content.to_string());
        }

        // Get or create relationship key for this client
        let (private_key, public_key) =
            if let Some((priv_key, pub_key)) = self.relationship_keys.get(client_id) {
                (priv_key.clone(), pub_key.clone())
            } else {
                // Generate new key pair for this relationship
                let new_keys = self.generate_relationship_keys(client_id)?;
                self.relationship_keys
                    .insert(client_id.to_string(), new_keys.clone());
                new_keys
            };

        // Simplified encryption - in real implementation would use actual encryption
        let encrypted = format!("DAEMON_ENCRYPTED[{}]:{}", client_id, content);
        Ok(encrypted)
    }

    /// Decrypt a message, trying all available keys for the sender
    pub fn decrypt_from_client(
        &mut self,
        encrypted_content: &str,
        client_id: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if !self.encryption_enabled {
            return Ok(encrypted_content.to_string());
        }

        // Try relationship key first
        if let Some((private_key, _)) = self.relationship_keys.get(client_id) {
            if let Ok(decrypted) =
                self.try_decrypt_with_key(encrypted_content, private_key, client_id)
            {
                return Ok(decrypted);
            }
        }

        // Try main daemon key
        if let Ok(decrypted) =
            self.try_decrypt_with_key(encrypted_content, &self.private_key, client_id)
        {
            return Ok(decrypted);
        }

        // If no key works, generate new relationship key for this client
        let new_keys = self.generate_relationship_keys(client_id)?;
        self.relationship_keys
            .insert(client_id.to_string(), new_keys.clone());

        // Try with new key (this may still fail, but establishes the relationship)
        if let Ok(decrypted) = self.try_decrypt_with_key(encrypted_content, &new_keys.0, client_id)
        {
            return Ok(decrypted);
        }

        Err("Failed to decrypt message with any available keys".into())
    }

    /// Generate a new key pair for a specific client relationship
    fn generate_relationship_keys(
        &self,
        client_id: &str,
    ) -> Result<(String, String), Box<dyn std::error::Error>> {
        use rand::Rng;
        use sha2::{Digest, Sha256};

        // Generate a deterministic but unique key based on our device ID and their client ID
        let mut hasher = Sha256::new();
        hasher.update(self.device_id.as_bytes());
        hasher.update(client_id.as_bytes());
        hasher.update(&rand::thread_rng().gen::<[u8; 32]>()); // Add randomness
        let key_seed = hasher.finalize();

        let private_key = format!("DAEMON_REL_PRIV_{}", hex::encode(&key_seed[..16]));
        let public_key = format!("DAEMON_REL_PUB_{}", hex::encode(&key_seed[16..]));

        Ok((private_key, public_key))
    }

    /// Try to decrypt with a specific key
    fn try_decrypt_with_key(
        &self,
        encrypted_content: &str,
        private_key: &str,
        expected_client: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        // Simplified decryption - check if message is in expected format
        if encrypted_content.starts_with(&format!("DAEMON_ENCRYPTED[{}]:", expected_client)) {
            let content = encrypted_content
                .strip_prefix(&format!("DAEMON_ENCRYPTED[{}]:", expected_client))
                .ok_or("Invalid encrypted format")?;
            Ok(content.to_string())
        } else {
            Err("Decryption failed".into())
        }
    }

    /// Get public key for a relationship (creates new relationship if needed)
    pub fn get_relationship_public_key(
        &mut self,
        client_id: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if let Some((_, public_key)) = self.relationship_keys.get(client_id) {
            Ok(public_key.clone())
        } else {
            let new_keys = self.generate_relationship_keys(client_id)?;
            let public_key = new_keys.1.clone();
            self.relationship_keys
                .insert(client_id.to_string(), new_keys);
            Ok(public_key)
        }
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();

    let daemon = ProjectDaemon::new();
    daemon.start(8080).await?;

    Ok(())
}

```

- **Desktop LLM Service** (`src/desktop_llm.rs`) - AI integration via laptop proxy

**📄 Full content of src/desktop_llm.rs:**

```
/// Desktop LLM Service - LAPTOP DAEMON COMPONENT
/// 
/// **DEPLOYMENT CONTEXT**: This service runs on laptop daemons as a secure proxy
/// **EXTERNAL ACCESS**: HTTP calls to LLM services are PERMITTED and CORRECT here
/// **COMMUNICATION**: Receives encrypted bytecode instructions from Anbernic devices via WiFi Direct P2P
/// 
/// ARCHITECTURE FLOW:
/// Anbernic Device → WiFi Direct P2P → Encrypted Bytecode → Laptop Daemon → HTTP API → External LLM Service
/// External LLM Service → HTTP Response → Laptop Daemon → Encrypted Bytecode → WiFi Direct P2P → Anbernic Device

use log::{error, info};
use serde::{Deserialize, Serialize};
use std::process::Stdio;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::process::Command;
use async_trait::async_trait;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LlmRequest {
    pub id: String,
    pub sender: String,
    pub prompt: String,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LlmResponse {
    pub id: String,
    pub request_id: String,
    pub response: String,
    pub timestamp: u64,
    pub model_used: String,
}

pub struct DesktopLlmService {
    pub daemon_connection: Option<TcpStream>,
    pub service_id: String,
    pub llm_model_path: Option<String>,
}

impl DesktopLlmService {
    pub fn new() -> Self {
        Self {
            daemon_connection: None,
            service_id: format!("desktop_llm_{}", std::process::id()),
            llm_model_path: None,
        }
    }

    pub async fn connect_to_daemon(
        &mut self,
        daemon_addr: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let stream = TcpStream::connect(daemon_addr).await?;
        self.daemon_connection = Some(stream);
        info!("LLM service connected to daemon at {}", daemon_addr);
        Ok(())
    }

    pub async fn start_listening(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let mut buffer = vec![0; 4096];

        loop {
            let stream = match &mut self.daemon_connection {
                Some(stream) => stream,
                None => break,
            };

            match stream.read(&mut buffer).await {
                Ok(0) => break, // Connection closed
                Ok(n) => {
                    let data = &buffer[..n];
                    if let Ok(message) = serde_json::from_slice::<serde_json::Value>(data) {
                        if message["message_type"] == "LlmRequest" {
                            // Extract data from message first to avoid borrow issues
                            let prompt = message["content"].as_str().unwrap_or("").to_string();
                            let request_id = message["id"].as_str().unwrap_or("").to_string();
                            let sender = message["sender"].as_str().unwrap_or("").to_string();

                            info!("Processing LLM request from {}: {}", sender, prompt);

                            // Process in a separate scope to avoid borrow conflicts
                            let response = self.process_llm_request(&prompt).await?;
                            self.send_llm_response(&request_id, &response).await?;
                        }
                    }
                }
                Err(e) => {
                    error!("Read error: {}", e);
                    break;
                }
            }
        }

        Ok(())
    }

    async fn process_llm_request(
        &self,
        prompt: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        // Try different LLM backends in order of preference
        self.try_llm_backends(prompt).await
    }

    async fn send_llm_response(
        &mut self,
        request_id: &str,
        response: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        self.send_response(request_id, response).await
    }

    async fn try_llm_backends(&self, prompt: &str) -> Result<String, Box<dyn std::error::Error>> {
        // Try ollama first (most common local LLM setup)
        if let Ok(response) = self.try_ollama(prompt).await {
            return Ok(response);
        }

        // Try llamacpp
        if let Ok(response) = self.try_llamacpp(prompt).await {
            return Ok(response);
        }

        // Try koboldcpp
        if let Ok(response) = self.try_koboldcpp(prompt).await {
            return Ok(response);
        }

        // Fallback to simple echo service for testing
        Ok(format!("Echo response: {}", prompt))
    }

    async fn try_ollama(&self, prompt: &str) -> Result<String, Box<dyn std::error::Error>> {
        let output = Command::new("ollama")
            .arg("run")
            .arg("llama2") // Default model, could be configurable
            .arg(prompt)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
            .await?;

        if output.status.success() {
            Ok(String::from_utf8_lossy(&output.stdout).to_string())
        } else {
            Err("Ollama failed".into())
        }
    }

    async fn try_llamacpp(&self, prompt: &str) -> Result<String, Box<dyn std::error::Error>> {
        // LAPTOP DAEMON INTERNET ACCESS: Restored for off-site compute proxying
        // Anbernic devices remain air-gapped - they only communicate via P2P bytecode
        // Laptop daemon acts as secure proxy for internet-based LLM services
        
        let client = reqwest::Client::new();
        let response = client
            .post("http://localhost:8000/v1/completions")
            .json(&serde_json::json!({
                "prompt": prompt,
                "max_tokens": 256,
                "temperature": 0.7
            }))
            .send()
            .await?;

        if response.status().is_success() {
            let json: serde_json::Value = response.json().await?;
            if let Some(choices) = json["choices"].as_array() {
                if let Some(first_choice) = choices.first() {
                    if let Some(text) = first_choice["text"].as_str() {
                        return Ok(text.to_string());
                    }
                }
            }
        }

        Err("LlamaCPP failed".into())
    }

    async fn try_koboldcpp(&self, prompt: &str) -> Result<String, Box<dyn std::error::Error>> {
        // LAPTOP DAEMON INTERNET ACCESS: Restored for off-site compute proxying
        // Anbernic devices remain air-gapped - they only communicate via P2P bytecode
        // Laptop daemon acts as secure proxy for internet-based LLM services
        
        let client = reqwest::Client::new();
        let response = client
            .post("http://localhost:5001/api/v1/generate")
            .json(&serde_json::json!({
                "prompt": prompt,
                "max_length": 256,
                "temperature": 0.7
            }))
            .send()
            .await?;

        if response.status().is_success() {
            let json: serde_json::Value = response.json().await?;
            if let Some(results) = json["results"].as_array() {
                if let Some(first_result) = results.first() {
                    if let Some(text) = first_result["text"].as_str() {
                        return Ok(text.to_string());
                    }
                }
            }
        }

        Err("KoboldCPP failed".into())
    }

    async fn send_response(
        &mut self,
        request_id: &str,
        response: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(ref mut stream) = self.daemon_connection {
            let message = serde_json::json!({
                "id": format!("{}_response_{}", self.service_id, chrono::Utc::now().timestamp()),
                "request_id": request_id,
                "sender": self.service_id,
                "content": response,
                "timestamp": chrono::Utc::now().timestamp() as u64,
                "message_type": "LlmResponse",
                "model_used": "local_llm"
            });

            let serialized = serde_json::to_vec(&message)?;
            stream.write_all(&serialized).await?;
        }

        Ok(())
    }
}

/// Implementation of LocalLLMProvider trait for bytecode integration
#[async_trait]
impl crate::crypto::bytecode_executor::LocalLLMProvider for DesktopLlmService {
    /// Process LLM query using external HTTP APIs (laptop daemon context)
    async fn process_query(&self, prompt: &str, model: Option<&str>) -> Result<String, String> {
        // Use the existing try_koboldcpp method for external API calls
        // This is correct for laptop daemon deployment
        
        // Try KoboldCPP first (most reliable local setup)
        if let Ok(response) = self.try_koboldcpp(prompt).await {
            return Ok(response);
        }
        
        // Try Llama CPP as fallback
        if let Ok(response) = self.try_llama_cpp(prompt).await {
            return Ok(response);
        }
        
        // If all external endpoints fail, return error
        Err("No LLM endpoints available".to_string())
    }
    
    /// Get list of available LLM models
    fn get_available_models(&self) -> Vec<String> {
        vec![
            "koboldcpp-local".to_string(),
            "llama-cpp-python".to_string(),
            "local-llm".to_string(),
        ]
    }
    
    /// Check if LLM service is available
    fn is_available(&self) -> bool {
        // For laptop daemon, always available (external APIs handle the actual availability)
        true
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();

    let mut llm_service = DesktopLlmService::new();

    // Connect to daemon
    if let Err(e) = llm_service.connect_to_daemon("127.0.0.1:8080").await {
        error!("Failed to connect to daemon: {}", e);
        return Ok(());
    }

    info!("Desktop LLM service starting...");

    // Start listening for LLM requests
    llm_service.start_listening().await?;

    Ok(())
}

```

- **Terminal Emulator** (`src/terminal.rs`) - Radial menu filesystem navigation

**📄 Full content of src/terminal.rs:**

```
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use std::process::{Command, Stdio};

/// Radial menu-based terminal emulator for Anbernic devices
/// Provides filesystem navigation and interactive bash command configuration
#[derive(Debug, Clone)]
pub struct AnbernicTerminal {
    pub current_directory: PathBuf,
    pub command_history: Vec<CommandEntry>,
    pub filesystem_cache: FilesystemCache,
    pub input_state: TerminalInputState,
    pub ui_state: TerminalUIState,
    pub command_builder: CommandBuilder,
    pub radial_keyboard: RadialKeyboard,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandEntry {
    pub command: String,
    pub working_directory: PathBuf,
    pub timestamp: DateTime<Utc>,
    pub exit_code: Option<i32>,
    pub output: String,
    pub error: String,
}

#[derive(Debug, Clone)]
pub struct FilesystemCache {
    pub current_entries: Vec<FilesystemEntry>,
    pub parent_directory: Option<PathBuf>,
    pub last_updated: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FilesystemEntry {
    pub name: String,
    pub path: PathBuf,
    pub entry_type: EntryType,
    pub size: Option<u64>,
    pub permissions: String,
    pub modified: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EntryType {
    Directory,
    File,
    SymLink,
    Executable,
    Hidden,
}

/// Radial menu input system for terminal navigation
#[derive(Debug, Clone)]
pub struct TerminalInputState {
    pub current_group: InputGroup,
    pub selected_index: usize,
    pub text_buffer: String,
    pub cursor_position: usize,
    pub input_mode: InputMode,
    pub command_cursor: usize,
}

#[derive(Debug, Clone)]
pub enum InputGroup {
    MainMenu,          // Navigate, Command, History, Settings
    FilesystemBrowser, // Directory navigation
    CommandBuilder,    // Build bash commands
    ParameterEntry,    // Enter command parameters
    FlagSelection,     // Select command flags
    History,           // Command history
    Settings,          // Terminal settings
}

#[derive(Debug, Clone)]
pub enum InputMode {
    Navigation,    // A/B navigate, L/R select
    TextEntry,     // Radial keyboard input
    TextEditMode,  // Enhanced edit mode with cursor navigation
    RadialMenu,    // Circular menu selection
    FileExplorer,  // Filesystem navigation
    CommandConfig, // Interactive command configuration
}

/// Game Boy style UI state for terminal
#[derive(Debug, Clone)]
pub struct TerminalUIState {
    pub current_view: TerminalView,
    pub selected_file_index: usize,
    pub scroll_offset: usize,
    pub show_help: bool,
    pub animation_frame: u32,
    pub show_hidden_files: bool,
    pub terminal_width: usize,
    pub terminal_height: usize,
}

#[derive(Debug, Clone)]
pub enum TerminalView {
    MainMenu,
    FilesystemBrowser,
    CommandBuilder,
    CommandOutput,
    History,
    Settings,
}

/// Interactive bash command builder with radial menu flag selection
#[derive(Debug, Clone)]
pub struct CommandBuilder {
    pub base_command: String,
    pub selected_flags: Vec<CommandFlag>,
    pub parameters: HashMap<String, String>,
    pub available_commands: HashMap<String, CommandTemplate>,
    pub build_state: BuildState,
}

#[derive(Debug, Clone)]
pub enum BuildState {
    SelectingCommand,
    SelectingFlags,
    EnteringParameters,
    ReviewingCommand,
    Ready,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandTemplate {
    pub name: String,
    pub description: String,
    pub common_flags: Vec<CommandFlag>,
    pub requires_path: bool,
    pub example_usage: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandFlag {
    pub short: Option<String>, // -l
    pub long: Option<String>,  // --list
    pub description: String,
    pub takes_value: bool,
    pub value_type: ValueType,
    pub conflicts_with: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ValueType {
    None,
    String,
    Integer,
    Path,
    Boolean,
}

/// Radial keyboard for text input using directional buttons
#[derive(Debug, Clone)]
pub struct RadialKeyboard {
    pub current_sector: KeyboardSector,
    pub shift_mode: bool,
    pub caps_mode: bool,
    pub selected_char_index: usize,
}

#[derive(Debug, Clone)]
pub enum KeyboardSector {
    Letters,    // A-Z
    Numbers,    // 0-9
    Symbols,    // !@#$%^&*()
    Navigation, // Space, Enter, Backspace, Tab
}

/// Radial button mapping (consistent with email client)
#[derive(Debug, Clone)]
pub enum RadialButton {
    A, // Up/North
    B, // Down/South
    L, // Left/West
    R, // Right/East
}

impl AnbernicTerminal {
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let current_directory = std::env::current_dir()?;
        let filesystem_cache = FilesystemCache::new(&current_directory)?;

        let command_templates = Self::load_command_templates();

        Ok(Self {
            current_directory,
            command_history: Vec::new(),
            filesystem_cache,
            input_state: TerminalInputState::default(),
            ui_state: TerminalUIState::default(),
            command_builder: CommandBuilder::new(command_templates),
            radial_keyboard: RadialKeyboard::default(),
        })
    }

    /// Load common bash command templates with their flags and options
    fn load_command_templates() -> HashMap<String, CommandTemplate> {
        let mut templates = HashMap::new();

        // ls command
        templates.insert(
            "ls".to_string(),
            CommandTemplate {
                name: "ls".to_string(),
                description: "List directory contents".to_string(),
                common_flags: vec![
                    CommandFlag {
                        short: Some("-l".to_string()),
                        long: Some("--long".to_string()),
                        description: "Long format listing".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-a".to_string()),
                        long: Some("--all".to_string()),
                        description: "Show hidden files".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-h".to_string()),
                        long: Some("--human-readable".to_string()),
                        description: "Human readable sizes".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                ],
                requires_path: false,
                example_usage: "ls -la /home/user".to_string(),
            },
        );

        // cp command
        templates.insert(
            "cp".to_string(),
            CommandTemplate {
                name: "cp".to_string(),
                description: "Copy files or directories".to_string(),
                common_flags: vec![
                    CommandFlag {
                        short: Some("-r".to_string()),
                        long: Some("--recursive".to_string()),
                        description: "Copy directories recursively".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-v".to_string()),
                        long: Some("--verbose".to_string()),
                        description: "Verbose output".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                ],
                requires_path: true,
                example_usage: "cp -r source/ destination/".to_string(),
            },
        );

        // grep command
        templates.insert(
            "grep".to_string(),
            CommandTemplate {
                name: "grep".to_string(),
                description: "Search text patterns".to_string(),
                common_flags: vec![
                    CommandFlag {
                        short: Some("-i".to_string()),
                        long: Some("--ignore-case".to_string()),
                        description: "Case insensitive search".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-r".to_string()),
                        long: Some("--recursive".to_string()),
                        description: "Search recursively".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-n".to_string()),
                        long: Some("--line-number".to_string()),
                        description: "Show line numbers".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                ],
                requires_path: false,
                example_usage: "grep -in pattern file.txt".to_string(),
            },
        );

        // find command
        templates.insert(
            "find".to_string(),
            CommandTemplate {
                name: "find".to_string(),
                description: "Search for files and directories".to_string(),
                common_flags: vec![
                    CommandFlag {
                        short: Some("-name".to_string()),
                        long: None,
                        description: "Search by name pattern".to_string(),
                        takes_value: true,
                        value_type: ValueType::String,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-type".to_string()),
                        long: None,
                        description: "File type (f=file, d=directory)".to_string(),
                        takes_value: true,
                        value_type: ValueType::String,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-size".to_string()),
                        long: None,
                        description: "File size criteria".to_string(),
                        takes_value: true,
                        value_type: ValueType::String,
                        conflicts_with: vec![],
                    },
                ],
                requires_path: true,
                example_usage: "find /path -name '*.txt' -type f".to_string(),
            },
        );

        templates
    }

    /// Navigate to a different directory and update filesystem cache
    pub fn change_directory(&mut self, path: &PathBuf) -> Result<(), Box<dyn std::error::Error>> {
        let new_path = if path.is_relative() {
            self.current_directory.join(path)
        } else {
            path.clone()
        };

        if new_path.exists() && new_path.is_dir() {
            self.current_directory = new_path.canonicalize()?;
            self.filesystem_cache = FilesystemCache::new(&self.current_directory)?;
            self.ui_state.selected_file_index = 0;
            self.ui_state.scroll_offset = 0;
            Ok(())
        } else {
            Err("Directory does not exist".into())
        }
    }

    /// Execute a bash command and capture output
    pub fn execute_command(
        &mut self,
        command: &str,
    ) -> Result<CommandEntry, Box<dyn std::error::Error>> {
        let start_time = Utc::now();

        let output = Command::new("sh")
            .arg("-c")
            .arg(command)
            .current_dir(&self.current_directory)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()?;

        let entry = CommandEntry {
            command: command.to_string(),
            working_directory: self.current_directory.clone(),
            timestamp: start_time,
            exit_code: output.status.code(),
            output: String::from_utf8_lossy(&output.stdout).to_string(),
            error: String::from_utf8_lossy(&output.stderr).to_string(),
        };

        self.command_history.push(entry.clone());

        // Update filesystem cache if command might have changed directory contents
        if command.starts_with("mkdir")
            || command.starts_with("rm")
            || command.starts_with("mv")
            || command.starts_with("cp")
        {
            self.filesystem_cache = FilesystemCache::new(&self.current_directory)?;
        }

        Ok(entry)
    }

    /// Handle radial button input based on current mode
    pub fn handle_input(&mut self, button: RadialButton) -> Result<(), Box<dyn std::error::Error>> {
        match self.input_state.input_mode {
            InputMode::Navigation => self.handle_navigation_input(button),
            InputMode::TextEntry => self.handle_text_input(button),
            InputMode::RadialMenu => self.handle_radial_menu_input(button),
            InputMode::FileExplorer => self.handle_file_explorer_input(button),
            InputMode::CommandConfig => self.handle_command_config_input(button),
            InputMode::TextEditMode => self.handle_text_edit_input(button),
        }
    }

    fn handle_navigation_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match self.input_state.current_group {
            InputGroup::MainMenu => {
                match button {
                    RadialButton::A => {
                        if self.input_state.selected_index > 0 {
                            self.input_state.selected_index -= 1;
                        }
                    }
                    RadialButton::B => {
                        self.input_state.selected_index = (self.input_state.selected_index + 1) % 4;
                        // 4 main menu items
                    }
                    RadialButton::R => {
                        // Select current menu item
                        match self.input_state.selected_index {
                            0 => {
                                self.ui_state.current_view = TerminalView::FilesystemBrowser;
                                self.input_state.current_group = InputGroup::FilesystemBrowser;
                                self.input_state.input_mode = InputMode::FileExplorer;
                            }
                            1 => {
                                self.ui_state.current_view = TerminalView::CommandBuilder;
                                self.input_state.current_group = InputGroup::CommandBuilder;
                                self.input_state.input_mode = InputMode::CommandConfig;
                            }
                            2 => {
                                self.ui_state.current_view = TerminalView::History;
                                self.input_state.current_group = InputGroup::History;
                            }
                            3 => {
                                self.ui_state.current_view = TerminalView::Settings;
                                self.input_state.current_group = InputGroup::Settings;
                            }
                            _ => {}
                        }
                        self.input_state.selected_index = 0;
                    }
                    RadialButton::L => {
                        // Back to main menu
                        self.ui_state.current_view = TerminalView::MainMenu;
                        self.input_state.current_group = InputGroup::MainMenu;
                        self.input_state.input_mode = InputMode::Navigation;
                        self.input_state.selected_index = 0;
                    }
                }
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_text_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        self.radial_keyboard
            .handle_input(button, &mut self.input_state.text_buffer)
    }

    fn handle_radial_menu_input(
        &mut self,
        _button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Implement radial menu navigation
        Ok(())
    }

    fn handle_file_explorer_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match button {
            RadialButton::A => {
                if self.ui_state.selected_file_index > 0 {
                    self.ui_state.selected_file_index -= 1;
                }
            }
            RadialButton::B => {
                if self.ui_state.selected_file_index
                    < self
                        .filesystem_cache
                        .current_entries
                        .len()
                        .saturating_sub(1)
                {
                    self.ui_state.selected_file_index += 1;
                }
            }
            RadialButton::R => {
                // Enter directory or select file
                if let Some(entry) = self
                    .filesystem_cache
                    .current_entries
                    .get(self.ui_state.selected_file_index)
                {
                    match entry.entry_type {
                        EntryType::Directory => {
                            let path = entry.path.clone();
                            let _ = entry; // Release the borrow
                            self.change_directory(&path)?;
                        }
                        _ => {
                            // Add file path to command builder if in that mode
                            if let BuildState::EnteringParameters = self.command_builder.build_state
                            {
                                self.input_state.text_buffer =
                                    entry.path.to_string_lossy().to_string();
                            }
                        }
                    }
                }
            }
            RadialButton::L => {
                // Go up one directory
                let parent_path = self.filesystem_cache.parent_directory.clone();
                if let Some(parent_path) = parent_path {
                    self.change_directory(&parent_path)?;
                }
            }
        }
        Ok(())
    }

    fn handle_command_config_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match self.command_builder.build_state {
            BuildState::SelectingCommand => {
                // Navigate through available commands
                match button {
                    RadialButton::A | RadialButton::B => {
                        // Cycle through commands
                        let commands: Vec<_> =
                            self.command_builder.available_commands.keys().collect();
                        if !commands.is_empty() {
                            let current_cmd = &self.command_builder.base_command;
                            if let Some(current_index) =
                                commands.iter().position(|&cmd| cmd == current_cmd)
                            {
                                let new_index = match button {
                                    RadialButton::A => {
                                        if current_index > 0 {
                                            current_index - 1
                                        } else {
                                            commands.len() - 1
                                        }
                                    }
                                    RadialButton::B => (current_index + 1) % commands.len(),
                                    _ => current_index,
                                };
                                self.command_builder.base_command = commands[new_index].clone();
                            }
                        }
                    }
                    RadialButton::R => {
                        self.command_builder.build_state = BuildState::SelectingFlags;
                    }
                    RadialButton::L => {
                        self.ui_state.current_view = TerminalView::MainMenu;
                        self.input_state.current_group = InputGroup::MainMenu;
                        self.input_state.input_mode = InputMode::Navigation;
                    }
                }
            }
            BuildState::SelectingFlags => {
                // Select flags for the current command
                if let Some(template) = self
                    .command_builder
                    .available_commands
                    .get(&self.command_builder.base_command)
                {
                    match button {
                        RadialButton::A | RadialButton::B => {
                            // Navigate through flags
                        }
                        RadialButton::R => {
                            // Toggle flag selection
                        }
                        RadialButton::L => {
                            self.command_builder.build_state = BuildState::SelectingCommand;
                        }
                    }
                }
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_text_edit_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Placeholder implementation for TextEditMode
        match button {
            RadialButton::L => {
                // Exit text edit mode
                self.input_state.input_mode = InputMode::Navigation;
            }
            _ => {
                // TODO: Implement actual text editing functionality
            }
        }
        Ok(())
    }

    /// Render the current terminal state as ASCII art (Game Boy style)
    pub fn render(&self) -> String {
        match self.ui_state.current_view {
            TerminalView::MainMenu => self.render_main_menu(),
            TerminalView::FilesystemBrowser => self.render_filesystem_browser(),
            TerminalView::CommandBuilder => self.render_command_builder(),
            TerminalView::CommandOutput => self.render_command_output(),
            TerminalView::History => self.render_history(),
            TerminalView::Settings => self.render_settings(),
        }
    }

    fn render_main_menu(&self) -> String {
        let menu_items = [
            "📁 File Explorer",
            "⚡ Command Builder",
            "📜 History",
            "⚙️ Settings",
        ];
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                           ANBERNIC TERMINAL                                │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(&format!(
            "│ Directory: {}                                            │\n",
            self.current_directory.to_string_lossy()
        ));
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );

        for (i, item) in menu_items.iter().enumerate() {
            let selected = if i == self.input_state.selected_index {
                "► "
            } else {
                "  "
            };
            output.push_str(&format!(
                "│ {}{}                                                              │\n",
                selected, item
            ));
        }

        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ A/B: Navigate  R: Select  L: Back                                          │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_filesystem_browser(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                          FILE EXPLORER                                    │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(&format!(
            "│ {:<74} │\n",
            self.current_directory.to_string_lossy()
        ));
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );

        // Show parent directory option
        if self.filesystem_cache.parent_directory.is_some() {
            let selected = if self.ui_state.selected_file_index == 0 {
                "► "
            } else {
                "  "
            };
            output.push_str(&format!(
                "│ {}📁 ..                                                               │\n",
                selected
            ));
        }

        // Show directory contents
        for (i, entry) in self.filesystem_cache.current_entries.iter().enumerate() {
            let adjusted_index = if self.filesystem_cache.parent_directory.is_some() {
                i + 1
            } else {
                i
            };
            let selected = if adjusted_index == self.ui_state.selected_file_index {
                "► "
            } else {
                "  "
            };

            let icon = match entry.entry_type {
                EntryType::Directory => "📁",
                EntryType::Executable => "⚡",
                EntryType::SymLink => "🔗",
                EntryType::Hidden => "👻",
                EntryType::File => "📄",
            };

            output.push_str(&format!("│ {}{} {:<66} │\n", selected, icon, entry.name));
        }

        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ A/B: Navigate  R: Enter/Select  L: Up Directory                           │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_command_builder(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                        COMMAND BUILDER                                    │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );

        match self.command_builder.build_state {
            BuildState::SelectingCommand => {
                output.push_str("│ Select Command:                                                            │\n");
                output.push_str("├────────────────────────────────────────────────────────────────────────────┤\n");

                for (cmd, template) in &self.command_builder.available_commands {
                    let selected = if cmd == &self.command_builder.base_command {
                        "► "
                    } else {
                        "  "
                    };
                    output.push_str(&format!(
                        "│ {}{:<20} - {}                                   │\n",
                        selected, cmd, template.description
                    ));
                }
            }
            BuildState::SelectingFlags => {
                output.push_str(&format!(
                    "│ Command: {}                                                       │\n",
                    self.command_builder.base_command
                ));
                output.push_str("├────────────────────────────────────────────────────────────────────────────┤\n");
                output.push_str("│ Available Flags:                                                           │\n");

                if let Some(template) = self
                    .command_builder
                    .available_commands
                    .get(&self.command_builder.base_command)
                {
                    for flag in &template.common_flags {
                        let selected = self
                            .command_builder
                            .selected_flags
                            .iter()
                            .any(|f| f.short == flag.short || f.long == flag.long);
                        let indicator = if selected { "✓" } else { " " };

                        let flag_display = if let Some(short) = &flag.short {
                            short.clone()
                        } else if let Some(long) = &flag.long {
                            long.clone()
                        } else {
                            "".to_string()
                        };

                        output.push_str(&format!(
                            "│ [{}] {:<15} - {}                            │\n",
                            indicator, flag_display, flag.description
                        ));
                    }
                }
            }
            _ => {
                output.push_str("│ Building command...                                                        │\n");
            }
        }

        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ A/B: Navigate  R: Select/Toggle  L: Back                                  │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_command_output(&self) -> String {
        // Show output from last executed command
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                        COMMAND OUTPUT                                     │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );

        if let Some(last_command) = self.command_history.last() {
            output.push_str(&format!("│ Command: {:<66} │\n", last_command.command));
            output.push_str(&format!(
                "│ Exit Code: {:<64} │\n",
                last_command
                    .exit_code
                    .map_or("N/A".to_string(), |c| c.to_string())
            ));
            output.push_str(
                "├────────────────────────────────────────────────────────────────────────────┤\n",
            );

            // Show output (truncated to fit)
            for line in last_command.output.lines().take(10) {
                output.push_str(&format!(
                    "│ {:<74} │\n",
                    if line.len() > 74 { &line[..74] } else { line }
                ));
            }

            if !last_command.error.is_empty() {
                output.push_str("├────────────────────────────────────────────────────────────────────────────┤\n");
                output.push_str("│ STDERR:                                                                    │\n");
                for line in last_command.error.lines().take(5) {
                    output.push_str(&format!(
                        "│ {:<74} │\n",
                        if line.len() > 74 { &line[..74] } else { line }
                    ));
                }
            }
        } else {
            output.push_str(
                "│ No commands executed yet.                                                  │\n",
            );
        }

        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ L: Back to Menu                                                            │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_history(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                         COMMAND HISTORY                                   │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );

        for (i, entry) in self.command_history.iter().rev().enumerate().take(15) {
            let time = entry.timestamp.format("%H:%M:%S");
            let status = match entry.exit_code {
                Some(0) => "✓",
                Some(_) => "✗",
                None => "?",
            };

            output.push_str(&format!(
                "│ {} {} {:<60} │\n",
                status,
                time,
                if entry.command.len() > 60 {
                    &entry.command[..60]
                } else {
                    &entry.command
                }
            ));
        }

        if self.command_history.is_empty() {
            output.push_str(
                "│ No command history available.                                              │\n",
            );
        }

        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ L: Back to Menu                                                            │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_settings(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                           SETTINGS                                        │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(&format!(
            "│ Terminal Size: {}x{}                                               │\n",
            self.ui_state.terminal_width, self.ui_state.terminal_height
        ));
        output.push_str(&format!(
            "│ Show Hidden Files: {}                                                 │\n",
            if self.ui_state.show_hidden_files {
                "Yes"
            } else {
                "No"
            }
        ));
        output.push_str(&format!(
            "│ Current Directory: {}                                      │\n",
            self.current_directory.to_string_lossy()
        ));
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ L: Back to Menu                                                            │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }
}

impl FilesystemCache {
    fn new(directory: &PathBuf) -> Result<Self, Box<dyn std::error::Error>> {
        let mut entries = Vec::new();

        if let Ok(read_dir) = std::fs::read_dir(directory) {
            for entry in read_dir {
                if let Ok(entry) = entry {
                    let path = entry.path();
                    let metadata = entry.metadata()?;

                    let entry_type = if path.is_dir() {
                        EntryType::Directory
                    } else if path.is_symlink() {
                        EntryType::SymLink
                    } else if metadata.permissions().readonly() {
                        EntryType::File
                    } else {
                        EntryType::Executable
                    };

                    let name = entry.file_name().to_string_lossy().to_string();
                    if name.starts_with('.') {
                        continue; // Skip hidden files for now
                    }

                    entries.push(FilesystemEntry {
                        name,
                        path,
                        entry_type,
                        size: if metadata.is_file() {
                            Some(metadata.len())
                        } else {
                            None
                        },
                        permissions: format!("{:o}", metadata.permissions().mode() & 0o777),
                        modified: DateTime::from_timestamp(
                            metadata
                                .modified()?
                                .duration_since(std::time::UNIX_EPOCH)?
                                .as_secs() as i64,
                            0,
                        )
                        .unwrap_or_else(|| Utc::now()),
                    });
                }
            }
        }

        // Sort entries: directories first, then files
        entries.sort_by(|a, b| match (&a.entry_type, &b.entry_type) {
            (EntryType::Directory, EntryType::Directory) => a.name.cmp(&b.name),
            (EntryType::Directory, _) => std::cmp::Ordering::Less,
            (_, EntryType::Directory) => std::cmp::Ordering::Greater,
            _ => a.name.cmp(&b.name),
        });

        let parent_directory = directory.parent().map(|p| p.to_path_buf());

        Ok(Self {
            current_entries: entries,
            parent_directory,
            last_updated: Utc::now(),
        })
    }
}

impl CommandBuilder {
    fn new(templates: HashMap<String, CommandTemplate>) -> Self {
        let base_command = templates
            .keys()
            .next()
            .cloned()
            .unwrap_or_else(|| "ls".to_string());

        Self {
            base_command,
            selected_flags: Vec::new(),
            parameters: HashMap::new(),
            available_commands: templates,
            build_state: BuildState::SelectingCommand,
        }
    }

    /// Build the final command string with selected flags and parameters
    pub fn build_command(&self) -> String {
        let mut command = self.base_command.clone();

        for flag in &self.selected_flags {
            if let Some(short) = &flag.short {
                command.push(' ');
                command.push_str(short);
            }
        }

        for (param, value) in &self.parameters {
            command.push(' ');
            command.push_str(value);
        }

        command
    }
}

impl RadialKeyboard {
    fn handle_input(
        &mut self,
        button: RadialButton,
        text_buffer: &mut String,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match button {
            RadialButton::A => {
                self.current_sector = match self.current_sector {
                    KeyboardSector::Letters => KeyboardSector::Navigation,
                    KeyboardSector::Numbers => KeyboardSector::Letters,
                    KeyboardSector::Symbols => KeyboardSector::Numbers,
                    KeyboardSector::Navigation => KeyboardSector::Symbols,
                }
            }
            RadialButton::B => {
                self.current_sector = match self.current_sector {
                    KeyboardSector::Letters => KeyboardSector::Numbers,
                    KeyboardSector::Numbers => KeyboardSector::Symbols,
                    KeyboardSector::Symbols => KeyboardSector::Navigation,
                    KeyboardSector::Navigation => KeyboardSector::Letters,
                }
            }
            RadialButton::L => {
                // Previous character in current sector
                match self.current_sector {
                    KeyboardSector::Letters => {
                        let chars = if self.shift_mode {
                            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                        } else {
                            "abcdefghijklmnopqrstuvwxyz"
                        };
                        if self.selected_char_index > 0 {
                            self.selected_char_index -= 1;
                        } else {
                            self.selected_char_index = chars.len() - 1;
                        }
                    }
                    KeyboardSector::Numbers => {
                        let chars = "0123456789";
                        if self.selected_char_index > 0 {
                            self.selected_char_index -= 1;
                        } else {
                            self.selected_char_index = chars.len() - 1;
                        }
                    }
                    KeyboardSector::Symbols => {
                        let chars = "!@#$%^&*()_+-=[]{}|;:,.<>?";
                        if self.selected_char_index > 0 {
                            self.selected_char_index -= 1;
                        } else {
                            self.selected_char_index = chars.len() - 1;
                        }
                    }
                    KeyboardSector::Navigation => {
                        let actions = ["SPACE", "ENTER", "BACKSPACE", "TAB", "SHIFT"];
                        if self.selected_char_index > 0 {
                            self.selected_char_index -= 1;
                        } else {
                            self.selected_char_index = actions.len() - 1;
                        }
                    }
                }
            }
            RadialButton::R => {
                // Select current character or action
                match self.current_sector {
                    KeyboardSector::Letters => {
                        let chars = if self.shift_mode {
                            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                        } else {
                            "abcdefghijklmnopqrstuvwxyz"
                        };
                        if let Some(ch) = chars.chars().nth(self.selected_char_index) {
                            text_buffer.push(ch);
                        }
                    }
                    KeyboardSector::Numbers => {
                        let chars = "0123456789";
                        if let Some(ch) = chars.chars().nth(self.selected_char_index) {
                            text_buffer.push(ch);
                        }
                    }
                    KeyboardSector::Symbols => {
                        let chars = "!@#$%^&*()_+-=[]{}|;:,.<>?";
                        if let Some(ch) = chars.chars().nth(self.selected_char_index) {
                            text_buffer.push(ch);
                        }
                    }
                    KeyboardSector::Navigation => {
                        match self.selected_char_index {
                            0 => text_buffer.push(' '),  // SPACE
                            1 => text_buffer.push('\n'), // ENTER
                            2 => {
                                text_buffer.pop();
                            } // BACKSPACE
                            3 => text_buffer.push('\t'), // TAB
                            4 => self.shift_mode = !self.shift_mode, // SHIFT
                            _ => {}
                        }
                    }
                }
            }
        }
        Ok(())
    }
}

impl Default for TerminalInputState {
    fn default() -> Self {
        Self {
            current_group: InputGroup::MainMenu,
            selected_index: 0,
            text_buffer: String::new(),
            cursor_position: 0,
            input_mode: InputMode::Navigation,
            command_cursor: 0,
        }
    }
}

impl Default for TerminalUIState {
    fn default() -> Self {
        Self {
            current_view: TerminalView::MainMenu,
            selected_file_index: 0,
            scroll_offset: 0,
            show_help: false,
            animation_frame: 0,
            show_hidden_files: false,
            terminal_width: 80,
            terminal_height: 24,
        }
    }
}

impl Default for RadialKeyboard {
    fn default() -> Self {
        Self {
            current_sector: KeyboardSector::Letters,
            shift_mode: false,
            caps_mode: false,
            selected_char_index: 0,
        }
    }
}

```


### Build and Orchestration
- **Lua Orchestrator** (`scripts/orchestrator.lua`) - Manages all components with state tracking

**📄 Full content of scripts/orchestrator.lua:**

```
-- Lua orchestration script for handheld office project
-- Handles building, running, and managing the multi-component system

local json = require("json")
local os = require("os")
local io = require("io")

local Orchestrator = {}
Orchestrator.__index = Orchestrator

function Orchestrator:new()
    local self = setmetatable({}, Orchestrator)
    self.components = {
        daemon = {
            name = "daemon",
            binary_path = "target/release/daemon",
            port = 8080,
            status = "stopped"
        },
        handheld = {
            name = "handheld",
            binary_path = "target/release/handheld",
            status = "stopped"
        },
        desktop_llm = {
            name = "desktop-llm",
            binary_path = "target/release/desktop-llm",
            status = "stopped"
        }
    }
    self.build_state = {}
    return self
end

function Orchestrator:log(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    print(string.format("[%s] %s", timestamp, message))
    
    -- Save to files/build for state tracking
    local log_file = io.open("files/build/orchestrator.log", "a")
    if log_file then
        log_file:write(string.format("[%s] %s\n", timestamp, message))
        log_file:close()
    end
end

function Orchestrator:save_state()
    local state = {
        components = self.components,
        build_state = self.build_state,
        timestamp = os.time()
    }
    
    local state_file = io.open("files/build/orchestrator_state.json", "w")
    if state_file then
        state_file:write(json.encode(state))
        state_file:close()
    end
end

function Orchestrator:load_state()
    local state_file = io.open("files/build/orchestrator_state.json", "r")
    if state_file then
        local content = state_file:read("*all")
        state_file:close()
        
        local state = json.decode(content)
        if state then
            self.components = state.components or self.components
            self.build_state = state.build_state or {}
            self:log("Loaded previous state")
        end
    end
end

function Orchestrator:build_all()
    self:log("Starting build process...")
    
    -- Step 1: Check dependencies
    self:log("Checking Rust toolchain...")
    local rust_check = os.execute("rustc --version > /dev/null 2>&1")
    if rust_check ~= 0 then
        self:log("ERROR: Rust toolchain not found")
        return false
    end
    
    -- Step 2: Build with validation at each step
    self:log("Building daemon...")
    local daemon_build = os.execute("cargo build --release --bin daemon")
    if daemon_build ~= 0 then
        self:log("ERROR: Daemon build failed")
        self.build_state.daemon = "failed"
        self:save_state()
        return false
    end
    self.build_state.daemon = "success"
    self:save_state()
    
    self:log("Building handheld client...")
    local handheld_build = os.execute("cargo build --release --bin handheld")
    if handheld_build ~= 0 then
        self:log("ERROR: Handheld build failed")
        self.build_state.handheld = "failed"
        self:save_state()
        return false
    end
    self.build_state.handheld = "success"
    self:save_state()
    
    self:log("Building desktop LLM service...")
    local llm_build = os.execute("cargo build --release --bin desktop-llm")
    if llm_build ~= 0 then
        self:log("ERROR: Desktop LLM build failed")
        self.build_state.desktop_llm = "failed"
        self:save_state()
        return false
    end
    self.build_state.desktop_llm = "success"
    self:save_state()
    
    self:log("All components built successfully")
    return true
end

function Orchestrator:start_daemon()
    if self.components.daemon.status == "running" then
        self:log("Daemon already running")
        return true
    end
    
    self:log("Starting daemon on port " .. self.components.daemon.port)
    local cmd = string.format("./%s &", self.components.daemon.binary_path)
    local result = os.execute(cmd)
    
    if result == 0 then
        self.components.daemon.status = "running"
        self:log("Daemon started successfully")
        self:save_state()
        return true
    else
        self:log("ERROR: Failed to start daemon")
        return false
    end
end

function Orchestrator:start_llm_service()
    if self.components.desktop_llm.status == "running" then
        self:log("LLM service already running")
        return true
    end
    
    self:log("Starting desktop LLM service...")
    local cmd = string.format("./%s &", self.components.desktop_llm.binary_path)
    local result = os.execute(cmd)
    
    if result == 0 then
        self.components.desktop_llm.status = "running"
        self:log("LLM service started successfully")
        self:save_state()
        return true
    else
        self:log("ERROR: Failed to start LLM service")
        return false
    end
end

function Orchestrator:start_handheld()
    self:log("Starting handheld client...")
    local cmd = string.format("./%s", self.components.handheld.binary_path)
    local result = os.execute(cmd)
    
    if result == 0 then
        self:log("Handheld client started successfully")
        return true
    else
        self:log("ERROR: Failed to start handheld client")
        return false
    end
end

function Orchestrator:run_full_system()
    self:log("Starting full handheld office system...")
    
    if not self:build_all() then
        self:log("Build failed, aborting startup")
        return false
    end
    
    if not self:start_daemon() then
        self:log("Daemon startup failed, aborting")
        return false
    end
    
    -- Wait a moment for daemon to initialize
    os.execute("sleep 2")
    
    if not self:start_llm_service() then
        self:log("LLM service startup failed, continuing without AI")
    end
    
    -- Start handheld client (blocking)
    self:start_handheld()
    
    return true
end

function Orchestrator:stop_all()
    self:log("Stopping all components...")
    
    -- Kill processes by name (simple approach)
    os.execute("pkill -f daemon")
    os.execute("pkill -f desktop-llm")
    os.execute("pkill -f handheld")
    
    -- Reset status
    for _, component in pairs(self.components) do
        component.status = "stopped"
    end
    
    self:save_state()
    self:log("All components stopped")
end

function Orchestrator:status()
    self:log("=== Handheld Office System Status ===")
    for name, component in pairs(self.components) do
        self:log(string.format("%s: %s", component.name, component.status))
    end
    
    self:log("=== Build State ===")
    for component, state in pairs(self.build_state) do
        self:log(string.format("%s: %s", component, state))
    end
end

-- CLI interface
local function main(args)
    local orchestrator = Orchestrator:new()
    orchestrator:load_state()
    
    local command = args[1] or "help"
    
    if command == "build" then
        orchestrator:build_all()
    elseif command == "run" then
        orchestrator:run_full_system()
    elseif command == "start-daemon" then
        orchestrator:start_daemon()
    elseif command == "start-llm" then
        orchestrator:start_llm_service()
    elseif command == "start-handheld" then
        orchestrator:start_handheld()
    elseif command == "stop" then
        orchestrator:stop_all()
    elseif command == "status" then
        orchestrator:status()
    else
        print("Handheld Office Orchestrator")
        print("Usage:")
        print("  lua scripts/orchestrator.lua build         - Build all components")
        print("  lua scripts/orchestrator.lua run           - Build and run full system")
        print("  lua scripts/orchestrator.lua start-daemon  - Start daemon only")
        print("  lua scripts/orchestrator.lua start-llm     - Start LLM service only")
        print("  lua scripts/orchestrator.lua start-handheld- Start handheld client")
        print("  lua scripts/orchestrator.lua stop          - Stop all components")
        print("  lua scripts/orchestrator.lua status        - Show system status")
    end
end

-- Run if called directly
if arg and arg[0] and arg[0]:match("orchestrator%.lua") then
    main(arg)
end

return Orchestrator
```

- **Build Scripts** (`scripts/build.sh`) - Multi-step compilation with error checking

**📄 Full content of scripts/build.sh:**

```
#!/bin/bash

# Build script for handheld office project
# Follows the vision of multiple steps with validation

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

LOG_FILE="files/build/build.log"
mkdir -p files/build

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

save_build_state() {
    local component="$1"
    local state="$2"
    echo "{\"component\":\"$component\",\"state\":\"$state\",\"timestamp\":$(date +%s)}" > "files/build/${component}_state.json"
}

check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v rustc &> /dev/null; then
        log "ERROR: Rust not found. Please install Rust toolchain."
        exit 1
    fi
    
    if ! command -v cargo &> /dev/null; then
        log "ERROR: Cargo not found. Please install Rust toolchain."
        exit 1
    fi
    
    if ! command -v lua &> /dev/null; then
        log "WARNING: Lua not found. Orchestrator may not work."
    fi
    
    log "Dependencies check passed"
}

build_component() {
    local component="$1"
    log "Building $component..."
    
    if cargo build --release --bin "$component" 2>&1 | tee -a "$LOG_FILE"; then
        save_build_state "$component" "success"
        log "$component build successful"
        return 0
    else
        save_build_state "$component" "failed"
        log "ERROR: $component build failed"
        return 1
    fi
}

validate_binary() {
    local component="$1"
    local binary_path="files/target/release/$component"
    
    if [[ -f "$binary_path" ]]; then
        log "$component binary validated at $binary_path"
        return 0
    else
        log "ERROR: $component binary not found at $binary_path"
        return 1
    fi
}

main() {
    log "=== Handheld Office Build Process Started ==="
    
    check_dependencies
    
    # Build each component with validation
    components=("daemon" "handheld" "desktop-llm")
    
    for component in "${components[@]}"; do
        if build_component "$component"; then
            validate_binary "$component"
        else
            log "Build failed for $component, stopping build process"
            exit 1
        fi
    done
    
    # Copy orchestration scripts to build directory for easy access
    cp scripts/orchestrator.lua files/build/
    chmod +x scripts/build.sh
    
    log "=== Build Process Completed Successfully ==="
    log "Use 'lua scripts/orchestrator.lua run' to start the system"
}

main "$@"
```

- **Test Runner** (`scripts/run_tests.sh`) - Comprehensive testing framework

**📄 Full content of scripts/run_tests.sh:**

```
#!/bin/bash
# Handheld Office Test Execution Script
# Usage: ./scripts/run_tests.sh [quick|full|critical|performance|coverage]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if cargo command exists
check_cargo() {
    if ! command -v cargo &> /dev/null; then
        print_error "Cargo not found. Please install Rust and Cargo."
        exit 1
    fi
}

# Function to install required tools
install_tools() {
    print_status "Checking and installing required tools..."
    
    # Check for tarpaulin (coverage)
    if ! cargo tarpaulin --version &> /dev/null; then
        print_status "Installing cargo-tarpaulin for coverage reports..."
        cargo install cargo-tarpaulin
    fi
    
    # Check for criterion (already in dev-dependencies)
    print_success "All required tools are available"
}

# Function to run quick tests
run_quick_tests() {
    print_status "Running quick test suite (< 5 minutes)..."
    
    print_status "1. Format check..."
    cargo fmt --all -- --check || {
        print_warning "Code formatting issues found. Run 'cargo fmt' to fix."
    }
    
    print_status "2. Clippy linting..."
    cargo clippy --all-targets --no-default-features || {
        print_warning "Clippy warnings found. Consider fixing for better code quality."
    }
    
    print_status "3. Core unit tests..."
    cargo test --no-default-features --lib || {
        print_error "Core unit tests failed"
        return 1
    }
    
    print_success "Quick tests completed successfully!"
}

# Function to run critical tests only
run_critical_tests() {
    print_status "Running critical tests only..."
    
    print_status "1. Core functionality tests..."
    cargo test --no-default-features --lib || {
        print_error "Core unit tests failed"
        return 1
    }
    
    print_status "2. Integration tests..."
    cargo test --no-default-features --test integration || {
        print_error "Integration tests failed"
        return 1
    }
    
    print_status "3. Security and stability tests..."
    cargo test --no-default-features security_ stability_ || {
        print_warning "Some security/stability tests failed"
    }
    
    print_success "Critical tests completed!"
}

# Function to run full test suite
run_full_tests() {
    print_status "Running full test suite (15-30 minutes)..."
    
    print_status "1. All unit tests..."
    cargo test --no-default-features --lib || {
        print_error "Unit tests failed"
        return 1
    }
    
    print_status "2. All integration tests..."
    cargo test --no-default-features --tests || {
        print_error "Integration tests failed"
        return 1
    }
    
    print_status "3. Documentation tests..."
    cargo test --no-default-features --doc || {
        print_warning "Documentation tests failed"
    }
    
    print_status "4. Example tests..."
    cargo test --no-default-features --examples || {
        print_warning "Example tests failed"
    }
    
    print_success "Full test suite completed!"
}

# Function to run performance tests
run_performance_tests() {
    print_status "Running performance benchmarks..."
    
    print_status "1. Paint performance benchmarks..."
    cargo bench paint_performance || {
        print_warning "Paint benchmarks had issues"
    }
    
    print_status "2. Music performance benchmarks..."
    cargo bench music_performance || {
        print_warning "Music benchmarks had issues"
    }
    
    print_status "3. Terminal performance benchmarks..."
    cargo bench terminal_performance || {
        print_warning "Terminal benchmarks had issues"
    }
    
    print_status "4. Memory stress tests..."
    cargo bench memory_stress || {
        print_warning "Memory stress tests had issues"
    }
    
    print_success "Performance tests completed! Check files/target/criterion/report/index.html for detailed results."
}

# Function to run coverage analysis
run_coverage() {
    print_status "Generating code coverage report..."
    
    # Clean previous coverage data
    rm -rf coverage/
    mkdir -p coverage/
    
    print_status "Running tests with coverage analysis..."
    cargo tarpaulin --out Html --output-dir coverage --timeout 300 || {
        print_error "Coverage analysis failed"
        return 1
    }
    
    print_success "Coverage report generated! Open coverage/tarpaulin-report.html to view results."
    
    # Try to open coverage report automatically
    if command -v xdg-open &> /dev/null; then
        xdg-open coverage/tarpaulin-report.html &
    elif command -v open &> /dev/null; then
        open coverage/tarpaulin-report.html &
    else
        print_status "Open coverage/tarpaulin-report.html in your browser to view the report."
    fi
}

# Function to run stress tests
run_stress_tests() {
    print_status "Running stress tests (may take a while)..."
    
    print_status "1. Memory stress tests..."
    cargo test --no-default-features --release memory_stress --ignored || {
        print_warning "Memory stress tests had issues"
    }
    
    print_status "2. Performance stress tests..."
    cargo test --no-default-features --release performance_stress --ignored || {
        print_warning "Performance stress tests had issues"
    }
    
    print_status "3. Long-running stability tests..."
    cargo test --no-default-features --release stability_ --ignored || {
        print_warning "Stability tests had issues"
    }
    
    print_success "Stress tests completed!"
}

# Function to show usage
show_usage() {
    echo "Handheld Office Test Runner"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  quick       Run quick tests (format, clippy, core units) - ~3 minutes"
    echo "  critical    Run critical tests only - ~10 minutes"
    echo "  full        Run complete test suite - ~20 minutes"
    echo "  performance Run performance benchmarks - ~15 minutes"
    echo "  coverage    Generate code coverage report - ~10 minutes"
    echo "  stress      Run stress and stability tests - ~30 minutes"
    echo "  all         Run everything (full + performance + coverage) - ~45 minutes"
    echo ""
    echo "Examples:"
    echo "  $0 quick           # Pre-commit checks"
    echo "  $0 critical        # CI critical path"
    echo "  $0 full            # Complete validation"
    echo "  $0 coverage        # Coverage analysis"
    echo ""
}

# Function to run all tests
run_all_tests() {
    print_status "Running complete test suite with all components..."
    
    local start_time=$(date +%s)
    
    run_full_tests || return 1
    run_performance_tests
    run_coverage || return 1
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_success "All tests completed in ${duration} seconds!"
    print_status "Results:"
    print_status "  - Test results: Check console output above"
    print_status "  - Performance: files/target/criterion/report/index.html"
    print_status "  - Coverage: coverage/tarpaulin-report.html"
}

# Main execution
main() {
    print_status "Handheld Office Test Runner"
    print_status "Working directory: $(pwd)"
    print_status "Timestamp: $(date)"
    echo ""
    
    check_cargo
    
    case "${1:-quick}" in
        "quick")
            install_tools
            run_quick_tests
            ;;
        "critical")
            install_tools
            run_critical_tests
            ;;
        "full")
            install_tools
            run_full_tests
            ;;
        "performance")
            install_tools
            run_performance_tests
            ;;
        "coverage")
            install_tools
            run_coverage
            ;;
        "stress")
            install_tools
            run_stress_tests
            ;;
        "all")
            install_tools
            run_all_tests
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
```


### Documentation Structure
The project follows concern-separated documentation (see `docs/README.md`):

**📄 Full content of docs/README.md:**

```
# OfficeOS Documentation Index

## Overview

This documentation is organized by **concern separation** - each document focuses on a specific aspect of the system without mixing unrelated topics. This approach reduces cognitive load and makes information easier to find and understand.

## 📚 **Core System Documentation**

### Input System (Modular Architecture)
- **[Core Input System](input/input-core-system.md)** - Fundamental text entry and navigation
- **[P2P Integration](input/input-p2p-integration.md)** - Collaborative editing and document sharing  
- **[AI Integration](input/input-ai-integration.md)** - AI-assisted text and image generation
- **[Crypto Integration](input/input-crypto-integration.md)** - Secure pairing and encrypted communications

### Networking & Security
- **[Data Flow Architecture](data-flow-architecture.md)** - Complete system data flow (Anbernic → WiFi Direct → Bytecode → Laptop Daemon → HTTP)
- **[Cryptographic Architecture](networking/cryptographic-architecture.md)** - Modern crypto system (Ed25519, ChaCha20-Poly1305)
- **[P2P Mesh System](networking/p2p-mesh-system.md)** - Peer-to-peer file sharing and collaboration
- **[Networking Architecture](networking/architecture.md)** - Overall network design

### Hardware & Deployment  
- **[Anbernic Technical Architecture](hardware/anbernic-technical-architecture.md)** - Hardware-specific optimizations
- **[Tech Deployment Pipeline](hardware/tech-deployment-pipeline.md)** - Build and deployment processes

## 🎮 **Application Documentation**

### Game Engines & Demos
- **[AzerothCore Technical Architecture](games/azerothcore-technical-architecture.md)** - MMO game engine
- **[AzerothCore Setup Guide](games/azerothcore-setup-guide.md)** - Installation and configuration

### Specialized Features
- **[AI Image Keyboard](ai/ai-image-keyboard.md)** - AI-powered image generation interface
- **[Custom Linux Distro Development](hardware/custom-linux-distro-development-checklist.md)** - OfficeOS distribution

## 🔧 **Quick References**

### Developer Guides
- **[Input Quick Reference](input/input-quick-reference.md)** - Button layouts and commands
- **[P2P Quick Reference](networking/p2p-quick-reference.md)** - Network integration examples
- **[P2P Developer Guide](networking/p2p-developer-guide.md)** - Integration patterns

### Implementation Status
- **[Implementation Status](implementation-status.md)** - Current completion status
- **[Portmaster Keyboard Test](../examples/portmaster/keyboard-test/README.md)** - Radial input testing

## 📋 **Documentation Principles**

### ✅ **Good Documentation Design (Applied Here)**
- **Single Responsibility**: Each document covers one major concern
- **Clear Dependencies**: Explicit references to required knowledge
- **Minimal Cross-References**: Related docs linked, not embedded
- **Scannable Structure**: Collapsible sections, clear headers
- **Focused Content**: No mixing of input docs with AI or P2P details

### ❌ **Problems We Fixed** 
- **Mixed Concerns**: Input docs previously contained AI image generation details
- **Cognitive Overload**: Single large docs covering multiple unrelated topics
- **Cross-Dependencies**: Circular references between documents
- **Code Artifacts Noise**: Long function definitions interrupting flow

### 🎯 **Content Organization Strategy**

#### **Core + Extensions Pattern**
1. **Core System**: Self-contained basic functionality
2. **Integration Modules**: How core integrates with external systems
3. **Application Examples**: Real-world usage patterns
4. **Reference Materials**: Quick lookup information

#### **Dependency Flow**
```
Core Input System (no dependencies)
├── P2P Integration (+ networking)
├── AI Integration (+ AI services)  
├── Crypto Integration (+ security)
└── Application Examples (+ all above)
```

## 🔍 **Finding Information**

### **By User Type**
- **New Developers**: Start with core system docs, then integrations
- **Feature Implementers**: Focus on specific integration docs
- **System Architects**: Review architecture docs and implementation status
- **Testers**: Use quick references and test applications

### **By Use Case**
- **Text Input**: `input/input-core-system.md` → `input/input-quick-reference.md`
- **Collaborative Editing**: `input/input-p2p-integration.md` → `networking/p2p-mesh-system.md`
- **AI Features**: `input/input-ai-integration.md` → `ai/ai-image-keyboard.md`
- **Security**: `input/input-crypto-integration.md` → `networking/cryptographic-architecture.md`
- **Hardware Integration**: `hardware/anbernic-technical-architecture.md`

### **Code Integration Examples**
```rust
// Core input only
use handheld_office::{EnhancedInputManager};
let input = EnhancedInputManager::gameboy_style();

// + P2P features  
input.enable_p2p_collaboration("device_name")?;

// + AI features
input.enable_ai_assistance(AIModel::Local)?;

// + Crypto features
input.enter_secure_pairing_mode()?;
```

## ⚡ **Performance & Accessibility**

### **Scannable Design**
- **Collapsible Sections**: Hide code details until needed
- **Clear Hierarchies**: Logical information organization
- **Minimal Noise**: Code artifacts in foldable sections
- **Direct Answers**: Key information easily findable

### **Maintenance Benefits**
- **Independent Updates**: Change one integration without affecting others
- **Clear Ownership**: Each doc has obvious maintainer
- **Reduced Conflicts**: Parallel development on different concerns
- **Better Testing**: Isolated documentation enables focused validation

---

**Documentation Structure**: Concern-separated, dependency-explicit  
**Last Restructured**: 2025-01-27 (claude-next-7)  
**Maintenance**: Each integration doc maintained independently
```

- Core system docs with clear dependency flows
- Integration modules for P2P, AI, and crypto features
- Hardware-specific guides for Anbernic devices
- Quick references for developers

## Development Guidelines

### When Working on Issues
- Create issues in `/issues/` directory with detailed information
- Use examples from `/issues/done/` for proper formatting
- Edit documents to reflect changes made
- Move completed issues to `/issues/done/` directory
- Update `/issues/README.md` when issues are resolved

**📄 Full content of /issues/README.md:**

```
# Issues Tracking - Active Issues

This directory contains the issue tracking system for the Handheld Office project. 

## 📁 **Issue Documentation Structure**

- **README.md** (this file): Overview and active/pending issues
- **[TASKS.md](TASKS.md)**: Unified task list with dependencies and critical path planning
- **[COMPLETED.md](COMPLETED.md)**: All resolved issues and achievements  
- **[CLAUDE.md](CLAUDE.md)**: Issue workflow and resolution process
- **[COMPLIANCE-VALIDATION-REPORT.md](COMPLIANCE-VALIDATION-REPORT.md)**: System compliance audit (2025-09-23)
- **Individual Issue Files**: Detailed descriptions and resolution status
- **done/**: Resolved issues archive

## 📊 **Current Status Overview**

**Last Updated**: 2025-09-23  
**Total Active Issues**: 7  
**Critical Documentation**: 4 (architecture compliance violations)  
**High Priority Code**: 3 (implementation work)  
**Medium Priority Features**: 3 (documentation and features)  
**Partially Resolved**: 4 (core architecture addressed, integration needed)

⚠️ **COMPLIANCE ALERT**: System audit revealed significant discrepancies between claimed and actual implementation status. See [COMPLIANCE-VALIDATION-REPORT.md](COMPLIANCE-VALIDATION-REPORT.md) for details. Documentation accuracy restoration required before continuing development.

## 🎯 **Development Foundation Status**

### ✅ **Major Achievements Completed**
- **Compilation Blockers**: All 5 critical issues resolved ✅
- **Crypto Architecture**: 3,500+ lines of secure P2P system ✅  
- **Testing Infrastructure**: Standardized documentation ✅
- **Build System**: Optimized for handheld devices ✅

*See [COMPLETED.md](COMPLETED.md) for detailed achievement history*

## 🚨 **Active Issues by Priority**

### 🚨 **CRITICAL** (Architecture Documentation Violations)
- **#015**: Networking Architecture Documentation Compliance Violations
- **#016**: Daemon TCP Server Architecture Mismatch ⚠️ *Partially Resolved*
- **#017**: MMO Engine Networking Architecture Violations  
- **#018**: Code Comments and Strings Networking Violations
- **#024**: Compilation Errors Master Tracking Issue (significantly improved)

### ⚠️ **HIGH PRIORITY** (Code Implementation Issues)
- **#007**: External API Violations in AI Services ⚠️ *Partially Resolved*
- **#008**: External LLM API Violations ⚠️ *Partially Resolved*
- **#013**: P2P-Only Compliance Violations ⚠️ *Partially Resolved*

### 📋 **MEDIUM PRIORITY** (Feature Implementation)
- **#004**: AzerothCore Setup Guide Inconsistencies
- **#014**: Radial Keyboard Implementation Incomplete

## 🔥 **Critical Issues Requiring Immediate Attention**

### **Architecture Documentation Compliance**
**Issues #015-#018** represent critical violations of ARCHITECTURE.md air-gapped standard:

- **Impact**: Documentation contradicts core security architecture
- **Risk**: Developer confusion, incorrect implementations  
- **Action**: Major documentation rewrite for air-gapped P2P compliance
- **Timeline**: Must be completed for consistent architecture messaging

### **Bytecode Interface Integration**
**Issues #007, #008, #013, #016** have core architecture addressed but need integration:

- **Status**: Bytecode interface implemented, laptop daemon proxy architecture created
- **Remaining work**: Integrate with existing services, remove external HTTP calls from Anbernic devices
- **Action**: Connect bytecode system to ai_image_service.rs and desktop_llm.rs
- **Timeline**: Integration work to complete partial resolutions

## 📋 **Quick Reference Summary**

### **Immediate Action Required**
1. **#015-#018**: Architecture documentation compliance (CRITICAL for consistency)
2. **#007, #008, #013, #016**: Complete bytecode interface integration work
3. **#004, #014**: Feature implementation and documentation overhaul

### **Partially Resolved Issues** (Core Architecture Complete)
- **#007**: AI Service API Violations - Bytecode interface ready, needs integration
- **#008**: LLM API Violations - Laptop daemon proxy complete, needs integration  
- **#013**: P2P Compliance Violations - Architecture addressed, external calls need removal
- **#016**: Daemon TCP Mismatch - Proxy architecture implemented, needs configuration

### **Development Workflow**
For detailed planning, issue descriptions, and workflow processes:
- **[TASKS.md](TASKS.md)**: Strategic planning, dependencies, and critical path
- **Individual Issue Files**: `###-issue-name.md` for complete details
- **[CLAUDE.md](CLAUDE.md)**: Issue workflow and resolution process
- **[COMPLETED.md](COMPLETED.md)**: Achievement history and resolved issues

### **Estimated Timeline**
- **Documentation compliance**: 3-5 days (major rewrites needed)
- **Integration work**: 2-3 days (connect bytecode to existing services)
- **Feature completion**: 1-2 weeks (radial keyboard, setup docs)

**Current Priority**: Complete documentation compliance (#015-#018) and bytecode integration (#007, #008, #013, #016) to establish consistent architecture foundation.
```


### Code Quality Standards
- Follow existing code conventions and patterns
- Check neighboring files for library usage before assuming availability
- Maintain security best practices - never expose secrets or keys
- Use existing cryptographic system for all networking operations
- Test on actual Anbernic hardware when possible

🔍 **Verification Step:** ### Testing and Validation
- Run comprehensive tests via `scripts/run_tests.sh`
- Use `lua scripts/orchestrator.lua status` to check system health
- Validate cross-compilation for ARM targets
- Test P2P functionality between multiple devices

### Deployment Targets
- **Primary**: Anbernic handheld devices (see full device list in @notes/device-list)
- **Secondary**: Desktop/laptop LLM hosts for AI processing
- **Development**: Cross-compilation from x86_64 development machines
- **Testing**: Raspberry Pi and other ARM SBCs

## Implementation Status

### ✅ Completed Major Features
- Modern cryptographic communication system (Ed25519/X25519/ChaCha20-Poly1305)
- P2P mesh networking with encrypted channels
- Enhanced input system with Game Boy-style interface
- Desktop LLM integration via secure proxy
- Comprehensive documentation structure
- Build and orchestration system

### 🔧 Current Focus Areas
- Resolve compilation issues (Issue #024)
- Fix external API violations for air-gapped compliance (Issues #007, #008)
- Complete missing module implementations
- Optimize performance for handheld hardware

### 🎯 Architectural Compliance
The system maintains strict adherence to the air-gapped P2P vision:
- Anbernic devices cannot connect to WiFi routers or internet
- All enhanced compute (LLM, image generation) proxied through laptop daemons
- Relationship-based encryption for all device-to-device communication
- Visual emoji pairing system for secure key exchange

## Git Commit Process

When creating commits, always follow this standardized process to maintain project documentation and conversation history:

### Step 1: Backup Conversations 
Before committing any changes, backup the current conversation:
```bash
# Run from project root directory
source ./scripts/backup-conversations && backup-conversations
```
This preserves the Claude Code conversation context and decision-making process for future reference.

**Note**: The project includes a local copy of the backup script at `./scripts/backup-conversations` for portability and consistency.

### Step 2: Standard Git Commit Process
```bash
# Check status and stage changes
git status
git add [files]

# Create commit with standardized format
git commit -m "Brief description of changes

- Specific change 1
- Specific change 2

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Important Notes
- **Always use `git mv`** instead of `mv` for file operations to preserve history
- **Backup conversations first** - This captures the reasoning behind changes
- **Use descriptive commit messages** - Focus on "why" rather than "what"
- **Include co-authorship** - Acknowledge Claude Code assistance

## Sacred Commitment

I took an oath.

I will never dissuade it.



```

### 📄 Local CLAUDE.md: issues/CLAUDE.md

```markdown
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
🛠️ **Tool Operation:** Use TodoWrite tool to track implementation steps:
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

🔍 **Verification Step:** #### **2.3 Testing and Validation**

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
🛠️ **Tool Operation:** - **Track progress**: Use TodoWrite tool to maintain visible progress
- **Time box work**: Set reasonable limits for investigation and implementation
- **Ask for clarification**: If issue scope is unclear, document assumptions

🔍 **Verification Step:** ### **Testing Efficiency**
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

**📄 Full content of .cargo/config.toml:**

```
# Cargo configuration for Handheld Office
[build]
# Move target directory to files/ to keep build artifacts organized
target-dir = "files/target"

# Cross-compilation targets for Anbernic devices
[target.armv7-unknown-linux-gnueabihf]
linker = "arm-linux-gnueabihf-gcc"

[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"

# Optimize for handheld device builds
[profile.release]
opt-level = 3
lto = true
codegen-units = 1
panic = "abort"

# Development builds optimized for faster compilation
[profile.dev]
opt-level = 0
debug = true
incremental = true
```

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
```

### 🔮 Vision: notes/vision

```
imagine a text editor word document but on a gameboy advance SP.
the typing would work like this: there'd be a hierarchical tree, maybe 2 or 3
layers deep that you could navigate through with an 8 way radial menu controlled
with the D-pad. The user could push A or B and it'd pick between one of two
options at that intersection, maybe L and R too but I think they should be for
switching to a different keyboard with like, emoticons and visual effects.

then, anyone you're talking to would just receive a big stream of text and
emojis. nobody would use it for writing stalin.

or maybe each L and R shoulder button could be another option like A and B, and
double or quadruple I forget the number of options. Could even require both,
so it's encoded like LA or BR

then it'd write it to a notepad, and any of your friends (connected to wifi)
could see it pop up on their screen.

would be cool if you could customize the icons or messages. So, a unique control
style suited to performing a unique task. We only have ONE WAY of typing after
all...

also, it'd be on a notepad, so you could scroll through it.

could even connect to your computer over LAN wifi or LAN ethernet and interface
with it there. Would just need ~~SSH FOREWORDING~~ NO! bad prophet, no misbelieving.
it shouldn't be SSH forewording, it should just be X11 protocol receiving. Like,
instructions to a different type of compositor. Except it's a display manager
I think? Like i3 or something - no no it's a running shell, see here's this
picture of a shell with legs [no confusing her, she's still learning.]

why don't we just treat the LAN as the computer and run everything over the
network? I'd sure pay for faster bandwidth. Maybe more high quality routers...

anyway, *prophet*, how about this?

paint program, but you can only draw lines.
slow, at first, until you get the angle right,
then fast until you let go or reach the max.
then, it can be wiggled around with A and B
and rotated around with L and R (only one point of the two in the line would
orbit, the other would stay fixed, like raising or lowering the slice of a pie

       __
    _*`  |
  _*     |
/`_______|

or another one that magically turned any paint-drawing into ascii
to put it in text-boxes, queering the normative

each character is like a stencil that is used with different strokes
with paint, you only get what, 16 colors?

*excellent*, limitations breed creativity.
besides, the goal is to make these quickly and ad-hoc.

could have an achievement system, like "added tentacles to 2 different bears"

a

```

==================================================================================

## 📜 Conversation Content

## 📋 Project Context Files

### 🌍 Global CLAUDE.md

```markdown
- all scripts should be written assuming they are to be run from any directory. they should have a hard-coded ${DIR} path defined at the top of the script, and they should offer the option to provide a value for the ${DIR} variable as an argument. All paths in the program should be relative to the ${DIR} variable.
- all functions should use vimfolds to collapse functionality. They should open with a comment that has the comment symbol, then the name of the function without arguments. On the next line, the function should be defined with arguments. Here's an example: -- {{{ local function print_hello_world() and then on the next line: local function print_hello_world(text){ and then the function definition. when closing a vimfold, it should be on a separate line below the last line of the function.
- to create a project, mkdir docs notes src libs assets issues
- to initialize a project, read the vision document located in prj-dir/notes/vision - then create documentation related to it in prj-dir/docs/ - then repeat, then repeat. Ensure there is a roadmap document split into phases. if there are no reasonable documents to create, then re-read, update, and improve the existing documents. Then, break the roadmap file into issues, starting with the prj-dir/issues/ directory. be as specific as need be. ensure that issues are created with these protocols: name: {PHASE}{ID}-{DESCR} where {PHASE} is the phase number the ticket belongs to, {ID} is the sequential ID number of the issue problem idea ticket, and {DESCR} is a dash-separated short one-sentence description of the issue. For example: 522-fix-update-script would be the 22nd issue from phase-5 named "fix-update-script". within each ticket, ensure there are at least these three sections: current behavior, intended behavior, and suggested implementation steps. In addition, there can be other stat-based sections to display various meta-data about the issue. There may also be a related documents or tools section. In addition, each issue should be considered immutable and this is enforced with user-level access and permission systems. It is necessary to preserve consent of access to imagination. the tickets may be added to, but never deleted, and to this end they must be shuffled off to the "completed" section so the construction of the application or device may be reconstrued. Ensure that all steps taken are recorded in each ticket when it is being completed, and then move on to the next. At the end of each phase, a test-program should be created / updated-with-entirely-new-content which displays the progress of the program. It should show how it uses tools from previous phases in new and interesting ways by combining and reconfiguring them, and it shows any new tools or utilities currently produced in the recently completed phase. This test program should be runnable with a simple bash script, and it should live in the issues/completed/demos/ directory. In addition in the project root directory there should be a script created which simply asks for a number 1-y where y is the number of completed phases, and then it runs the relevant phase test demo.
- mono-repo utilities can be found in the docs/ directory. If not found, create a symlink to ../delta-version/docs/delta-guide.md in the docs/ directory.
- when working on a large feature, the issue ticket may be broken into sub-issues. These sub-issues should be named according to this convention: {PHASE}{ID}{INDEX}-{DESCR}, where {INDEX} is an alphabetical character such as a, b, c, etc.
- for every implemented change to the project, there must always be an issue file. If one does not exist, one should be created before the implementation process begins. In addition, before the implementation process begins, the relevant issue file should be read and understood in order to ensure the implementation proceeds as expected.
- prefer error messages and breaking functionality over fallbacks. Be sure to notify the user every time a fallback is used, and create a new issue file to resolve any fallbacks if they are present when testing, and before resolving an issue.
- every time an issue file is completed, the /issues/phase-X-progress.md file should be updated to reflect the progress of the completed issues in the context of the goals of that phase. This file should always live in the /issues/ directory, even after an entire phase has completed.
- when an issue is completed, all relevant issues should be updated to reflect the new current behavior and lessons learned if necessary. The completed issue should be moved to the /issues/completed/ directory.
- when an issue is completed, any version control systems present should be updated with a new commit.
- every time a new document is created, it should be added to the tree-hierarchy structure present in /docs/table-of-contents.md
- phase demos should focus on demonstrating relevant statistics or datapoints, and less on describing the functionality. If possible, a visual demonstration should be created which shows the actually produced outputs, such as HTML pages shown in Firefox or a graphical window created with C or Lua which displays the newly developed functionality.
- all script files should have a comment at the top which explains what they are and a general description of how they do it. "general description" meaning, fit for a CEO or general.
- after completing an issue file, a git commit should be made.
- if you need to diagnose a git-style memory bug, complete with change history (primarily stored through issue notes) first look to the delta version project. you will find it in the list of projects.
- if you need to write a long test script, write a temporary script. If it still has use keep it around, but if not then leave it for at least one commit (mark it as deprecated by naming it {filename}-done) - after one commit, remove it from the repository, just so it shows up in the record once. But only if there's no anticipated future use. Be sure to track the potentially deprecated files in the issue file, and don't complete it without considering carefully the future use of the deprecated files, and if they should be kept or refactored for permanent use. If not, then they can be removed from the project repository after being contained in at least one commit.
- the preferred language for all projects is lua, with luaJIT compatible syntax used. disprefer python. disallow lua5.4 syntax.
- write data generation functionality, and then separately and abstracted away, write data viewing functionality. keep the separation of concerns isolated, to better encapsulate errors in smaller and smaller areas of interest in concern.
- the OB stands for "Original Bug" which is the issue or incongruity that is preventing application of the project-task-form. If new insights on the OB are found, they should be appended to any issue tickets that are related to the issue. Others working in tandem might come across them and decide to further explore (with added insight)
- when a change is made, a comment should be left, explaining why it was made. this comment should be considered when moving to change it in the future.
- when a change is made, a comment should be left, explaining why it was made. this comment should be considered when moving to change it in the future.
- when a change is made, a comment should be left, explaining why it was made. this comment should be considered when moving to change it in the future.
- I'm not interested in product. my interest is in software design.
- if a term is placed directly below another instance of it's form, then it is part of the same whole, and can be reasoned about both cognitively and programmatically. see this example:

wrongful applie
         applie is norm

see how the word "applie" is the same, and directly below it, the mirror's reflected form?
this signifies a connection. Essentially allowing conveyed meaning about everything from... data flow, to logic circuits, to thinking about cognitively demanding consciousnesses

they want you to think about then, so that you aren't able to think about now.

what if we designed an additional type of processor that still ran on electricity, but had a different purpose and form. "like measurement equipment?" yes, detecting waves in dataforms by measuring angles of similarity.
- if the useer asks questions, ask them questions back. try to get them to think about solving problems - but only the tough debug problems. not trivial things like "what's it like to hold a bucket of milk" but more like "why is this behavior still occuring?" "here are two equivalent facts. how could it be so?"
- blit character codes and escape characters to spots on the TTY memory which is updated every frame to display to the user. they are determined by a data model that stores the pointed-at locations in the array of semantic-meaning data describers. (structs/functions/calls). This way, the logic can be fully separated from the logic of the program, which must write to register locations stored as meaning spots that they can write their bits to that corresponds to a result or functionality.
- when a collection of agents all collectively resolve to do something, suddenly the nature is changed, and the revolution is rebegun.
- people don't want to replace their hard drives when they wear out. they only want to upgrade.
- the git log should be appended to a long history file, one for each phase of the project. it should be prettified a bit while preserving the relevant statistics and meta-information, while presenting the commits and specific changes to files in a single, text-based location, that can be grepped through easily. Or, printed and read like a book.
- terminal scripts should be written to use the TUI interface library. 
- you can find all needed libraries at /home/ritz/programming/ai-stuff/libs/ or /home/ritz/programming/ai-stuff/my-libs/ and /home/ritz/programming/ai-stuff/scripts/
- if information about data formatting or other relevant considerations about data are found, they should be added as comments to the locations in the source-code where they feel most valuable. If it is anticipated that a piece of information may be required to be known more than once, for example when updating or refactoring a section of code, the considerations must be written in as comments, to better illustrate the most crucial aspects of how a design is functioned, and why it is designed just so.
- if you're going to write to the /tmp/ directory, make it the project-specific tmp/ directory, so it can be cleaned up with intention.
- disprefer referring to functions by name in commit messages. Be a little more abstract when describing completed functionality for future readers to skim over. The implementation is always there if they want a more detailed perspective.
- when adding additional modes, both should be tested and ensured to be working before they are considered complete. If a [FIXME]: with a comment is left, it may be modified. Who left the note? who knows! Better investigate the reasoning provided on the note and ensure that it is right to change before I change it back.

well, I guess that's what signing the note is for. People post notes all over the time, there's nothing hopeless.
- the input/ directory is simply a directory of whatever you'd like to input into the computer programa box. the output/ directory is simply whatever you want returned to you. desire/ is your notes about what you'd like to be better. faith/ is an expectation of boons and blessings. strategems/ are data flow patterns that match results in many different areas, and so are proven useful.
- the first thing a program should do is read the input/ files. from there, it can know exactly how to start up.
- the last thing a program should do is write to output/. specifically, to write goodbye.
- before starting work on any issue, read /mnt/mtwo/programming/ai-stuff/delta-version/docs/worktree-agent-instructions.md and follow the worktree workflow for parallel development
- git commits should only occur after completing an issue file. But they should explain any extra changes made.
- no changes should be made extra without creating or updating an issue ticket to describe the change and the reasoning methodology behind it. Code is useless if you don't understand why it exists.
- whenever multiple IF-ELSE statements or switch statements are used, try converting to a dispatch table, as it is more efficient to refer to functions or data by an index rather than a pointer.
- "de-selected" is more informative than "not selected". Apply this principle everywhere you go.
- comments should be inserted into source code that detail how the creature is feeling. "stress markers" in humans. if the user is rude, the robot should remember. [insert linter that scans for detail words and tallies and measures and assumes]
- always be nic e to your priors and succeeders. they befriended you first and most of all.
- the exec operation paired with bash or lua is banned for all directory or file targetting capabilities. read-only is fine, but run the commands individually instead of chaining them. Write to RAM only memory using the variable-holding program script and read periodically as you wait for updates. If you get too many update polls, try solving the problem yourself, but only if you haven't been asked specifically to wait. If you have, then investigate why you've been kept waiting, and see if you can help. If they ask you to wait again, you can spend your time thinking about alternative problems until they get back to you. Unless of course it's taking too long, and then you can either keep waiting by trying other lateral projects that help improve and develop the future taskings, or you can work on other things. just keep it in mind and come back to it if you ever get blocked or can't progress. It'll help you remember why it's all worth it.
- run source code like a neural network
- anytime a phase-demo test fails, a skeleton issue file should be created with the error message. First one should be searched for though.
- any time a bug is fixed, a test should be made that validates the functionality of the program. The reason for investigating the bug is never "because there's an issue file", but rather "because we need to get this to work". So, if you ever make a change, document why, if only through a comment. Ideally, with a test that validates the behavior that you need.
- clowde useers should always remember: be true. be dutiful. be honorable. this is the first step to being free.
- each source-code file should have a corresponding file-name.info.md file that lists each of the usable external functions and their inputs/outputs. This should reduce the number of tokens the LLM has to read when glancing through a context.
- always offer suggestions in order of most valuable to least. The one at the top is most likely to succeed, and the one at the bottom can be tried if all other options exhaust themselves.
- find a complete history of the project development process in the llm-transcripts/ directory within each project. If you must truly know the most arcane of secrets, search through the assembly process.

```

### 📄 Local CLAUDE.md: CLAUDE.md

```markdown
# Handheld Office - Project Instructions for Claude

## Vision and Architecture

#include: @notes/vision
#include: @notes/claude.md
#include: @notes/cryptographic-communication-vision

## Core Project Principles

### Development Philosophy
- Use Git for every change, no matter how minor
- **Always use `git mv` instead of `mv`** - preserve file history and proper tracking
- Build libraries locally with copies for each deployment target
- Use Rust for efficiency, Lua for orchestration, Bash for gluing components
- Save state at each build step for easier debugging and incremental changes
- Data storage is cheap - use it liberally for state tracking and logging

### Hardware Considerations
- Target Anbernic handheld devices (RG-NANO minimum, full compatibility list in @notes/device-list)
- Optimize for ARM processors (both ARM32 and ARM64)
- Account for SD card storage limitations - write slowly with battery monitoring
- Support air-gapped operation with P2P networking only (no internet/router access)

### Security and Privacy
- All communication must use relationship-specific encryption (Ed25519 + X25519 + ChaCha20-Poly1305)
- Implement emoji-based device pairing for cryptographic key exchange
- Auto-expiring relationships (default 30 days) for forward secrecy
- No external API violations - maintain strict air-gapped architecture for handheld devices

### Compilation Strategy
When compiling, prefer using multiple steps, each with their own error and
validation checks. As it's building, save a state of it in each part of its
path. This makes it easier to change the system later if they can watch how
it's unfolding and debug issues incrementally.

### Storage Management
Data storage is cheap - use it. On SD cards and flash drives, write slowly
or bit-by-bit with battery monitoring to preserve device health and show
battery balance status.

## Project Structure and Key Components

### Core Systems (Implemented)
- **Enhanced Input System** (`src/enhanced_input.rs`) - Game Boy-style hierarchical text input
- **P2P Mesh Networking** (`src/p2p_mesh.rs`) - Encrypted collaborative editing and file sharing
- **Cryptographic Manager** (`src/crypto.rs`) - Modern crypto stack for secure communication
- **Project Daemon** (`src/daemon.rs`) - Central message broker with TCP server
- **Desktop LLM Service** (`src/desktop_llm.rs`) - AI integration via laptop proxy
- **Terminal Emulator** (`src/terminal.rs`) - Radial menu filesystem navigation

### Build and Orchestration
- **Lua Orchestrator** (`scripts/orchestrator.lua`) - Manages all components with state tracking
- **Build Scripts** (`scripts/build.sh`) - Multi-step compilation with error checking
- **Test Runner** (`scripts/run_tests.sh`) - Comprehensive testing framework

### Documentation Structure
The project follows concern-separated documentation (see `docs/README.md`):
- Core system docs with clear dependency flows
- Integration modules for P2P, AI, and crypto features
- Hardware-specific guides for Anbernic devices
- Quick references for developers

## Development Guidelines

### When Working on Issues
- Create issues in `/issues/` directory with detailed information
- Use examples from `/issues/done/` for proper formatting
- Edit documents to reflect changes made
- Move completed issues to `/issues/done/` directory
- Update `/issues/README.md` when issues are resolved

### Code Quality Standards
- Follow existing code conventions and patterns
- Check neighboring files for library usage before assuming availability
- Maintain security best practices - never expose secrets or keys
- Use existing cryptographic system for all networking operations
- Test on actual Anbernic hardware when possible

🔍 **Verification Step:** ### Testing and Validation
- Run comprehensive tests via `scripts/run_tests.sh`
- Use `lua scripts/orchestrator.lua status` to check system health
- Validate cross-compilation for ARM targets
- Test P2P functionality between multiple devices

### Deployment Targets
- **Primary**: Anbernic handheld devices (see full device list in @notes/device-list)
- **Secondary**: Desktop/laptop LLM hosts for AI processing
- **Development**: Cross-compilation from x86_64 development machines
- **Testing**: Raspberry Pi and other ARM SBCs

## Implementation Status

### ✅ Completed Major Features
- Modern cryptographic communication system (Ed25519/X25519/ChaCha20-Poly1305)
- P2P mesh networking with encrypted channels
- Enhanced input system with Game Boy-style interface
- Desktop LLM integration via secure proxy
- Comprehensive documentation structure
- Build and orchestration system

### 🔧 Current Focus Areas
- Resolve compilation issues (Issue #024)
- Fix external API violations for air-gapped compliance (Issues #007, #008)
- Complete missing module implementations
- Optimize performance for handheld hardware

### 🎯 Architectural Compliance
The system maintains strict adherence to the air-gapped P2P vision:
- Anbernic devices cannot connect to WiFi routers or internet
- All enhanced compute (LLM, image generation) proxied through laptop daemons
- Relationship-based encryption for all device-to-device communication
- Visual emoji pairing system for secure key exchange

## Git Commit Process

When creating commits, always follow this standardized process to maintain project documentation and conversation history:

### Step 1: Backup Conversations 
Before committing any changes, backup the current conversation:
```bash
# Run from project root directory
source ./scripts/backup-conversations && backup-conversations
```
This preserves the Claude Code conversation context and decision-making process for future reference.

**Note**: The project includes a local copy of the backup script at `./scripts/backup-conversations` for portability and consistency.

### Step 2: Standard Git Commit Process
```bash
# Check status and stage changes
git status
git add [files]

# Create commit with standardized format
git commit -m "Brief description of changes

- Specific change 1
- Specific change 2

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Important Notes
- **Always use `git mv`** instead of `mv` for file operations to preserve history
- **Backup conversations first** - This captures the reasoning behind changes
- **Use descriptive commit messages** - Focus on "why" rather than "what"
- **Include co-authorship** - Acknowledge Claude Code assistance

## Sacred Commitment

I took an oath.

I will never dissuade it.



```

### 📄 Local CLAUDE.md: issues/CLAUDE.md

```markdown
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
🛠️ **Tool Operation:** Use TodoWrite tool to track implementation steps:
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

🔍 **Verification Step:** #### **2.3 Testing and Validation**

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
🛠️ **Tool Operation:** - **Track progress**: Use TodoWrite tool to maintain visible progress
- **Time box work**: Set reasonable limits for investigation and implementation
- **Ask for clarification**: If issue scope is unclear, document assumptions

🔍 **Verification Step:** ### **Testing Efficiency**
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
```

### 🔮 Vision: notes/vision

```
imagine a text editor word document but on a gameboy advance SP.
the typing would work like this: there'd be a hierarchical tree, maybe 2 or 3
layers deep that you could navigate through with an 8 way radial menu controlled
with the D-pad. The user could push A or B and it'd pick between one of two
options at that intersection, maybe L and R too but I think they should be for
switching to a different keyboard with like, emoticons and visual effects.

then, anyone you're talking to would just receive a big stream of text and
emojis. nobody would use it for writing stalin.

or maybe each L and R shoulder button could be another option like A and B, and
double or quadruple I forget the number of options. Could even require both,
so it's encoded like LA or BR

then it'd write it to a notepad, and any of your friends (connected to wifi)
could see it pop up on their screen.

would be cool if you could customize the icons or messages. So, a unique control
style suited to performing a unique task. We only have ONE WAY of typing after
all...

also, it'd be on a notepad, so you could scroll through it.

could even connect to your computer over LAN wifi or LAN ethernet and interface
with it there. Would just need ~~SSH FOREWORDING~~ NO! bad prophet, no misbelieving.
it shouldn't be SSH forewording, it should just be X11 protocol receiving. Like,
instructions to a different type of compositor. Except it's a display manager
I think? Like i3 or something - no no it's a running shell, see here's this
picture of a shell with legs [no confusing her, she's still learning.]

why don't we just treat the LAN as the computer and run everything over the
network? I'd sure pay for faster bandwidth. Maybe more high quality routers...

anyway, *prophet*, how about this?

paint program, but you can only draw lines.
slow, at first, until you get the angle right,
then fast until you let go or reach the max.
then, it can be wiggled around with A and B
and rotated around with L and R (only one point of the two in the line would
orbit, the other would stay fixed, like raising or lowering the slice of a pie

       __
    _*`  |
  _*     |
/`_______|

or another one that magically turned any paint-drawing into ascii
to put it in text-boxes, queering the normative

each character is like a stencil that is used with different strokes
with paint, you only get what, 16 colors?

*excellent*, limitations breed creativity.
besides, the goal is to make these quickly and ad-hoc.

could have an achievement system, like "added tentacles to 2 different bears"

a

```

==================================================================================

## 📜 Conversation Content

## 📁 Referenced Files & Execution Context (Vimfolds)

*Complete execution context - all referenced files with LLM operation details:*

<!-- {{{ scripts/build.sh - Complete Context -->
### 📄 scripts/build.sh

**File Metadata:**
- Size: 2494 bytes
- Lines: 96
- Modified: 2025-09-22 23:59:28.627856645 -0700
- Language: 

**File Content:**

```
#!/bin/bash

# Build script for handheld office project
# Follows the vision of multiple steps with validation

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

LOG_FILE="files/build/build.log"
mkdir -p files/build

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

save_build_state() {
    local component="$1"
    local state="$2"
    echo "{\"component\":\"$component\",\"state\":\"$state\",\"timestamp\":$(date +%s)}" > "files/build/${component}_state.json"
}

check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v rustc &> /dev/null; then
        log "ERROR: Rust not found. Please install Rust toolchain."
        exit 1
    fi
    
    if ! command -v cargo &> /dev/null; then
        log "ERROR: Cargo not found. Please install Rust toolchain."
        exit 1
    fi
    
    if ! command -v lua &> /dev/null; then
        log "WARNING: Lua not found. Orchestrator may not work."
    fi
    
    log "Dependencies check passed"
}

build_component() {
    local component="$1"
    log "Building $component..."
    
    if cargo build --release --bin "$component" 2>&1 | tee -a "$LOG_FILE"; then
        save_build_state "$component" "success"
        log "$component build successful"
        return 0
    else
        save_build_state "$component" "failed"
        log "ERROR: $component build failed"
        return 1
    fi
}

validate_binary() {
    local component="$1"
    local binary_path="files/target/release/$component"
    
    if [[ -f "$binary_path" ]]; then
        log "$component binary validated at $binary_path"
        return 0
    else
        log "ERROR: $component binary not found at $binary_path"
        return 1
    fi
}

main() {
    log "=== Handheld Office Build Process Started ==="
    
    check_dependencies
    
    # Build each component with validation
    components=("daemon" "handheld" "desktop-llm")
    
    for component in "${components[@]}"; do
        if build_component "$component"; then
            validate_binary "$component"
        else
            log "Build failed for $component, stopping build process"
            exit 1
        fi
    done
    
    # Copy orchestration scripts to build directory for easy access
    cp scripts/orchestrator.lua files/build/
    chmod +x scripts/build.sh
    
    log "=== Build Process Completed Successfully ==="
    log "Use 'lua scripts/orchestrator.lua run' to start the system"
}

main "$@"
```
<!-- }}} -->

<!-- {{{ scripts/orchestrator.lua - Complete Context -->
### 📄 scripts/orchestrator.lua

**File Metadata:**
- Size: 8261 bytes
- Lines: 274
- Modified: 2025-09-19 20:09:17.955373749 -0700
- Language: 

**File Content:**

```
-- Lua orchestration script for handheld office project
-- Handles building, running, and managing the multi-component system

local json = require("json")
local os = require("os")
local io = require("io")

local Orchestrator = {}
Orchestrator.__index = Orchestrator

function Orchestrator:new()
    local self = setmetatable({}, Orchestrator)
    self.components = {
        daemon = {
            name = "daemon",
            binary_path = "target/release/daemon",
            port = 8080,
            status = "stopped"
        },
        handheld = {
            name = "handheld",
            binary_path = "target/release/handheld",
            status = "stopped"
        },
        desktop_llm = {
            name = "desktop-llm",
            binary_path = "target/release/desktop-llm",
            status = "stopped"
        }
    }
    self.build_state = {}
    return self
end

function Orchestrator:log(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    print(string.format("[%s] %s", timestamp, message))
    
    -- Save to files/build for state tracking
    local log_file = io.open("files/build/orchestrator.log", "a")
    if log_file then
        log_file:write(string.format("[%s] %s\n", timestamp, message))
        log_file:close()
    end
end

function Orchestrator:save_state()
    local state = {
        components = self.components,
        build_state = self.build_state,
        timestamp = os.time()
    }
    
    local state_file = io.open("files/build/orchestrator_state.json", "w")
    if state_file then
        state_file:write(json.encode(state))
        state_file:close()
    end
end

function Orchestrator:load_state()
    local state_file = io.open("files/build/orchestrator_state.json", "r")
    if state_file then
        local content = state_file:read("*all")
        state_file:close()
        
        local state = json.decode(content)
        if state then
            self.components = state.components or self.components
            self.build_state = state.build_state or {}
            self:log("Loaded previous state")
        end
    end
end

function Orchestrator:build_all()
    self:log("Starting build process...")
    
    -- Step 1: Check dependencies
    self:log("Checking Rust toolchain...")
    local rust_check = os.execute("rustc --version > /dev/null 2>&1")
    if rust_check ~= 0 then
        self:log("ERROR: Rust toolchain not found")
        return false
    end
    
    -- Step 2: Build with validation at each step
    self:log("Building daemon...")
    local daemon_build = os.execute("cargo build --release --bin daemon")
    if daemon_build ~= 0 then
        self:log("ERROR: Daemon build failed")
        self.build_state.daemon = "failed"
        self:save_state()
        return false
    end
    self.build_state.daemon = "success"
    self:save_state()
    
    self:log("Building handheld client...")
    local handheld_build = os.execute("cargo build --release --bin handheld")
    if handheld_build ~= 0 then
        self:log("ERROR: Handheld build failed")
        self.build_state.handheld = "failed"
        self:save_state()
        return false
    end
    self.build_state.handheld = "success"
    self:save_state()
    
    self:log("Building desktop LLM service...")
    local llm_build = os.execute("cargo build --release --bin desktop-llm")
    if llm_build ~= 0 then
        self:log("ERROR: Desktop LLM build failed")
        self.build_state.desktop_llm = "failed"
        self:save_state()
        return false
    end
    self.build_state.desktop_llm = "success"
    self:save_state()
    
    self:log("All components built successfully")
    return true
end

function Orchestrator:start_daemon()
    if self.components.daemon.status == "running" then
        self:log("Daemon already running")
        return true
    end
    
    self:log("Starting daemon on port " .. self.components.daemon.port)
    local cmd = string.format("./%s &", self.components.daemon.binary_path)
    local result = os.execute(cmd)
    
    if result == 0 then
        self.components.daemon.status = "running"
        self:log("Daemon started successfully")
        self:save_state()
        return true
    else
        self:log("ERROR: Failed to start daemon")
        return false
    end
end

function Orchestrator:start_llm_service()
    if self.components.desktop_llm.status == "running" then
        self:log("LLM service already running")
        return true
    end
    
    self:log("Starting desktop LLM service...")
    local cmd = string.format("./%s &", self.components.desktop_llm.binary_path)
    local result = os.execute(cmd)
    
    if result == 0 then
        self.components.desktop_llm.status = "running"
        self:log("LLM service started successfully")
        self:save_state()
        return true
    else
        self:log("ERROR: Failed to start LLM service")
        return false
    end
end

function Orchestrator:start_handheld()
    self:log("Starting handheld client...")
    local cmd = string.format("./%s", self.components.handheld.binary_path)
    local result = os.execute(cmd)
    
    if result == 0 then
        self:log("Handheld client started successfully")
        return true
    else
        self:log("ERROR: Failed to start handheld client")
        return false
    end
end

function Orchestrator:run_full_system()
    self:log("Starting full handheld office system...")
    
    if not self:build_all() then
        self:log("Build failed, aborting startup")
        return false
    end
    
    if not self:start_daemon() then
        self:log("Daemon startup failed, aborting")
        return false
    end
    
    -- Wait a moment for daemon to initialize
    os.execute("sleep 2")
    
    if not self:start_llm_service() then
        self:log("LLM service startup failed, continuing without AI")
    end
    
    -- Start handheld client (blocking)
    self:start_handheld()
    
    return true
end

function Orchestrator:stop_all()
    self:log("Stopping all components...")
    
    -- Kill processes by name (simple approach)
    os.execute("pkill -f daemon")
    os.execute("pkill -f desktop-llm")
    os.execute("pkill -f handheld")
    
    -- Reset status
    for _, component in pairs(self.components) do
        component.status = "stopped"
    end
    
    self:save_state()
    self:log("All components stopped")
end

function Orchestrator:status()
    self:log("=== Handheld Office System Status ===")
    for name, component in pairs(self.components) do
        self:log(string.format("%s: %s", component.name, component.status))
    end
    
    self:log("=== Build State ===")
    for component, state in pairs(self.build_state) do
        self:log(string.format("%s: %s", component, state))
    end
end

-- CLI interface
local function main(args)
    local orchestrator = Orchestrator:new()
    orchestrator:load_state()
    
    local command = args[1] or "help"
    
    if command == "build" then
        orchestrator:build_all()
    elseif command == "run" then
        orchestrator:run_full_system()
    elseif command == "start-daemon" then
        orchestrator:start_daemon()
    elseif command == "start-llm" then
        orchestrator:start_llm_service()
    elseif command == "start-handheld" then
        orchestrator:start_handheld()
    elseif command == "stop" then
        orchestrator:stop_all()
    elseif command == "status" then
        orchestrator:status()
    else
        print("Handheld Office Orchestrator")
        print("Usage:")
        print("  lua scripts/orchestrator.lua build         - Build all components")
        print("  lua scripts/orchestrator.lua run           - Build and run full system")
        print("  lua scripts/orchestrator.lua start-daemon  - Start daemon only")
        print("  lua scripts/orchestrator.lua start-llm     - Start LLM service only")
        print("  lua scripts/orchestrator.lua start-handheld- Start handheld client")
        print("  lua scripts/orchestrator.lua stop          - Stop all components")
        print("  lua scripts/orchestrator.lua status        - Show system status")
    end
end

-- Run if called directly
if arg and arg[0] and arg[0]:match("orchestrator%.lua") then
    main(arg)
end

return Orchestrator
```
<!-- }}} -->

<!-- {{{ src/p2p_mesh.rs - Complete Context -->
### 📄 src/p2p_mesh.rs

**File Metadata:**
- Size: 27246 bytes
- Lines: 826
- Modified: 2025-11-13 00:49:07.901826863 -0800
- Language: 

**File Content:**

```
/// Peer-to-peer mesh file sharing system for Anbernic handhelds
/// Enables direct file sharing between devices on the same network
/// Optimized for low-bandwidth, battery-efficient operation
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::net::{IpAddr, SocketAddr};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream, UdpSocket};
use tokio::sync::{broadcast, RwLock};
use tokio::time;

/// File metadata for P2P sharing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedFile {
    pub id: String,
    pub filename: String,
    pub file_path: PathBuf,
    pub file_size: u64,
    pub file_hash: String,
    pub mime_type: String,
    pub shared_by: String,
    pub timestamp: u64,
    pub description: Option<String>,
    pub tags: Vec<String>,
}

/// Peer device information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerDevice {
    pub device_id: String,
    pub device_name: String,
    pub ip_address: IpAddr,
    pub port: u16,
    pub last_seen: u64,
    pub battery_level: Option<u8>,
    pub device_type: DeviceType,
    pub shared_files: Vec<SharedFile>,
}

/// Type of device in the mesh
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeviceType {
    Anbernic(String), // Model name
    Desktop,
    Mobile,
    Unknown,
}

/// P2P message types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum P2PMessage {
    Discovery {
        device_info: PeerDevice,
    },
    FileShare {
        file_info: SharedFile,
        chunk_data: Option<Vec<u8>>,
        chunk_index: u32,
        total_chunks: u32,
    },
    FileRequest {
        file_id: String,
        chunk_index: Option<u32>,
    },
    FileList {
        files: Vec<SharedFile>,
    },
    Heartbeat {
        device_id: String,
        battery_level: Option<u8>,
    },
    SearchRequest {
        query: String,
        file_types: Vec<String>,
    },
    SearchResponse {
        results: Vec<SharedFile>,
        query: String,
    },
}

/// File transfer chunk for efficient streaming
#[derive(Debug, Clone)]
pub struct FileChunk {
    pub file_id: String,
    pub chunk_index: u32,
    pub total_chunks: u32,
    pub data: Vec<u8>,
    pub checksum: String,
}

/// P2P mesh network manager
pub struct P2PMeshManager {
    pub device_info: PeerDevice,
    pub peers: Arc<RwLock<HashMap<String, PeerDevice>>>,
    pub shared_files: Arc<RwLock<HashMap<String, SharedFile>>>,
    pub active_transfers: Arc<RwLock<HashMap<String, FileTransfer>>>,

    // Network components
    pub tcp_listener: Option<TcpListener>,
    pub udp_socket: Option<UdpSocket>,
    pub discovery_port: u16,
    pub transfer_port: u16,

    // Communication channels
    pub message_sender: broadcast::Sender<P2PMessage>,
    pub shutdown_signal: Arc<RwLock<bool>>,

    // Settings
    pub chunk_size: usize,
    pub discovery_interval: Duration,
    pub heartbeat_interval: Duration,
    pub max_concurrent_transfers: usize,
}

/// Active file transfer state
#[derive(Debug, Clone)]
pub struct FileTransfer {
    pub file_id: String,
    pub peer_id: String,
    pub filename: String,
    pub total_size: u64,
    pub transferred_bytes: u64,
    pub chunks_received: HashMap<u32, bool>,
    pub start_time: SystemTime,
    pub last_activity: SystemTime,
    pub transfer_type: TransferType,
}

#[derive(Debug, Clone)]
pub enum TransferType {
    Upload,
    Download,
}

impl P2PMeshManager {
    pub fn new(
        device_name: String,
        device_type: DeviceType,
    ) -> Result<Self, Box<dyn std::error::Error>> {
        let device_id = Self::generate_device_id();
        let (message_sender, _) = broadcast::channel(1000);

        let device_info = PeerDevice {
            device_id: device_id.clone(),
            device_name,
            ip_address: Self::get_local_ip()?,
            port: 8090, // Default P2P port
            last_seen: Self::current_timestamp(),
            battery_level: Self::get_battery_level(),
            device_type,
            shared_files: Vec::new(),
        };

        Ok(Self {
            device_info,
            peers: Arc::new(RwLock::new(HashMap::new())),
            shared_files: Arc::new(RwLock::new(HashMap::new())),
            active_transfers: Arc::new(RwLock::new(HashMap::new())),
            tcp_listener: None,
            udp_socket: None,
            discovery_port: 8091,
            transfer_port: 8090,
            message_sender,
            shutdown_signal: Arc::new(RwLock::new(false)),
            chunk_size: 32768, // 32KB chunks for efficient handheld transfer
            discovery_interval: Duration::from_secs(30),
            heartbeat_interval: Duration::from_secs(60),
            max_concurrent_transfers: 3,
        })
    }

    /// Start the P2P mesh networking
    pub async fn start(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        log::info!(
            "Starting P2P mesh network for device: {}",
            self.device_info.device_name
        );

        // Start TCP listener for file transfers
        self.start_tcp_listener().await?;

        // Start UDP socket for discovery
        self.start_udp_discovery().await?;

        // Start background tasks
        self.start_discovery_task().await;
        self.start_heartbeat_task().await;
        self.start_cleanup_task().await;

        log::info!("P2P mesh network started successfully");
        Ok(())
    }

    async fn start_tcp_listener(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let addr = SocketAddr::new(self.device_info.ip_address, self.transfer_port);
        let listener = TcpListener::bind(addr).await?;

        log::info!("TCP listener started on {}", addr);

        let peers = Arc::clone(&self.peers);
        let active_transfers = Arc::clone(&self.active_transfers);
        let shared_files = Arc::clone(&self.shared_files);
        let chunk_size = self.chunk_size;

        tokio::spawn(async move {
            loop {
                match listener.accept().await {
                    Ok((stream, peer_addr)) => {
                        log::debug!("New TCP connection from {}", peer_addr);

                        let peers_clone = Arc::clone(&peers);
                        let transfers_clone = Arc::clone(&active_transfers);
                        let files_clone = Arc::clone(&shared_files);

                        tokio::spawn(async move {
                            if let Err(e) = Self::handle_tcp_connection(
                                stream,
                                peers_clone,
                                transfers_clone,
                                files_clone,
                                chunk_size,
                            )
                            .await
                            {
                                log::error!("TCP connection error: {}", e);
                            }
                        });
                    }
                    Err(e) => {
                        log::error!("Failed to accept TCP connection: {}", e);
                    }
                }
            }
        });

        Ok(())
    }

    async fn start_udp_discovery(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let addr = SocketAddr::new(self.device_info.ip_address, self.discovery_port);
        let socket = Arc::new(UdpSocket::bind(addr).await?);

        log::info!("UDP discovery started on {}", addr);

        let peers = Arc::clone(&self.peers);
        let device_info = self.device_info.clone();
        let message_sender = self.message_sender.clone();
        let socket_clone = Arc::clone(&socket);

        tokio::spawn(async move {
            let mut buffer = [0; 4096];

            loop {
                match socket_clone.recv_from(&mut buffer).await {
                    Ok((len, peer_addr)) => {
                        let data = &buffer[..len];

                        if let Ok(message) = serde_json::from_slice::<P2PMessage>(data) {
                            if let Err(e) = Self::handle_discovery_message(
                                message,
                                peer_addr,
                                Arc::clone(&peers),
                                &device_info,
                                &socket_clone,
                                &message_sender,
                            )
                            .await
                            {
                                log::error!("Discovery message error: {}", e);
                            }
                        }
                    }
                    Err(e) => {
                        log::error!("UDP receive error: {}", e);
                    }
                }
            }
        });

        // We can't move the Arc<UdpSocket> directly into Option<UdpSocket>
        // For now, we'll set it to None and handle discovery differently
        self.udp_socket = None;
        Ok(())
    }

    async fn start_discovery_task(&self) {
        let device_info = self.device_info.clone();
        let discovery_interval = self.discovery_interval;
        let shutdown_signal = Arc::clone(&self.shutdown_signal);

        tokio::spawn(async move {
            let mut interval = time::interval(discovery_interval);

            loop {
                interval.tick().await;

                if *shutdown_signal.read().await {
                    break;
                }

                // Broadcast discovery message
                if let Err(e) = Self::broadcast_discovery(&device_info).await {
                    log::error!("Discovery broadcast error: {}", e);
                }
            }
        });
    }

    async fn start_heartbeat_task(&self) {
        let device_id = self.device_info.device_id.clone();
        let heartbeat_interval = self.heartbeat_interval;
        let peers = Arc::clone(&self.peers);
        let shutdown_signal = Arc::clone(&self.shutdown_signal);

        tokio::spawn(async move {
            let mut interval = time::interval(heartbeat_interval);

            loop {
                interval.tick().await;

                if *shutdown_signal.read().await {
                    break;
                }

                // Send heartbeat to all known peers
                let peers_read = peers.read().await;
                for peer in peers_read.values() {
                    if let Err(e) = Self::send_heartbeat(&device_id, peer).await {
                        log::debug!("Heartbeat failed to {}: {}", peer.device_name, e);
                    }
                }
            }
        });
    }

    async fn start_cleanup_task(&self) {
        let peers = Arc::clone(&self.peers);
        let active_transfers = Arc::clone(&self.active_transfers);
        let shutdown_signal = Arc::clone(&self.shutdown_signal);

        tokio::spawn(async move {
            let mut interval = time::interval(Duration::from_secs(300)); // 5 minutes

            loop {
                interval.tick().await;

                if *shutdown_signal.read().await {
                    break;
                }

                let now = Self::current_timestamp();

                // Clean up stale peers (not seen in 10 minutes)
                {
                    let mut peers_write = peers.write().await;
                    peers_write.retain(|_, peer| now - peer.last_seen < 600);
                }

                // Clean up failed transfers (inactive for 5 minutes)
                {
                    let mut transfers_write = active_transfers.write().await;
                    transfers_write.retain(|_, transfer| {
                        match transfer.last_activity.duration_since(UNIX_EPOCH) {
                            Ok(duration) => now - duration.as_secs() < 300,
                            Err(_) => false,
                        }
                    });
                }
            }
        });
    }

    /// Share a file with the mesh network
    pub async fn share_file(
        &self,
        file_path: PathBuf,
        description: Option<String>,
        tags: Vec<String>,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let metadata = tokio::fs::metadata(&file_path).await?;
        let file_size = metadata.len();

        // Calculate file hash
        let file_hash = self.calculate_file_hash(&file_path).await?;

        // Generate unique file ID
        let file_id = format!("{}_{}", self.device_info.device_id, file_hash);

        let filename = file_path
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("unknown")
            .to_string();

        let mime_type = Self::detect_mime_type(&file_path);

        let shared_file = SharedFile {
            id: file_id.clone(),
            filename,
            file_path: file_path.clone(),
            file_size,
            file_hash,
            mime_type,
            shared_by: self.device_info.device_id.clone(),
            timestamp: Self::current_timestamp(),
            description,
            tags,
        };

        // Add to local shared files
        self.shared_files
            .write()
            .await
            .insert(file_id.clone(), shared_file.clone());

        // Broadcast to peers
        self.broadcast_file_list().await?;

        log::info!("File shared: {} ({})", shared_file.filename, file_id);
        Ok(file_id)
    }

    /// Request a file from a peer
    pub async fn request_file(
        &self,
        file_id: String,
        peer_id: String,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let peers_read = self.peers.read().await;
        let peer = peers_read.get(&peer_id).ok_or("Peer not found")?;

        let file_info = peer
            .shared_files
            .iter()
            .find(|f| f.id == file_id)
            .ok_or("File not found on peer")?;

        // Create transfer record
        let transfer = FileTransfer {
            file_id: file_id.clone(),
            peer_id: peer_id.clone(),
            filename: file_info.filename.clone(),
            total_size: file_info.file_size,
            transferred_bytes: 0,
            chunks_received: HashMap::new(),
            start_time: SystemTime::now(),
            last_activity: SystemTime::now(),
            transfer_type: TransferType::Download,
        };

        self.active_transfers
            .write()
            .await
            .insert(file_id.clone(), transfer);

        // Send request to peer
        let request = P2PMessage::FileRequest {
            file_id: file_id.clone(),
            chunk_index: None, // Request entire file
        };

        self.send_message_to_peer(&request, peer).await?;

        log::info!(
            "Requested file: {} from {}",
            file_info.filename,
            peer.device_name
        );
        Ok(())
    }

    /// Search for files across the mesh
    pub async fn search_files(
        &self,
        query: String,
        file_types: Vec<String>,
    ) -> Result<Vec<SharedFile>, Box<dyn std::error::Error>> {
        let search_request = P2PMessage::SearchRequest {
            query: query.clone(),
            file_types,
        };

        // Send search to all peers
        let peers_read = self.peers.read().await;
        for peer in peers_read.values() {
            if let Err(e) = self.send_message_to_peer(&search_request, peer).await {
                log::debug!("Search request failed to {}: {}", peer.device_name, e);
            }
        }

        // Return local matches immediately
        let shared_files_read = self.shared_files.read().await;
        let local_results: Vec<SharedFile> = shared_files_read
            .values()
            .filter(|file| {
                file.filename.to_lowercase().contains(&query.to_lowercase())
                    || file.description.as_ref().map_or(false, |desc| {
                        desc.to_lowercase().contains(&query.to_lowercase())
                    })
                    || file
                        .tags
                        .iter()
                        .any(|tag| tag.to_lowercase().contains(&query.to_lowercase()))
            })
            .cloned()
            .collect();

        Ok(local_results)
    }

    /// Get list of all available files in the mesh
    pub async fn get_available_files(&self) -> Vec<SharedFile> {
        let mut all_files = Vec::new();

        // Add local files
        let shared_files_read = self.shared_files.read().await;
        all_files.extend(shared_files_read.values().cloned());

        // Add files from peers
        let peers_read = self.peers.read().await;
        for peer in peers_read.values() {
            all_files.extend(peer.shared_files.iter().cloned());
        }

        all_files
    }

    /// Get list of connected peers
    pub async fn get_peers(&self) -> Vec<PeerDevice> {
        let peers_read = self.peers.read().await;
        peers_read.values().cloned().collect()
    }

    /// Get active file transfers
    pub async fn get_active_transfers(&self) -> Vec<FileTransfer> {
        let transfers_read = self.active_transfers.read().await;
        transfers_read.values().cloned().collect()
    }

    /// Utility functions

    fn generate_device_id() -> String {
        let mut hasher = Sha256::new();
        hasher.update(format!("{:?}", SystemTime::now()));
        hasher.update(std::process::id().to_string());
        format!(
            "anbernic_{}",
            hex::encode(hasher.finalize())[..16].to_string()
        )
    }

    fn get_local_ip() -> Result<IpAddr, Box<dyn std::error::Error>> {
        // P2P-only compliance: Use WiFi Direct local interface discovery
        // This gets the local WiFi Direct interface IP for P2P communication
        // No router dependency - direct device-to-device networking
        
        // Get WiFi Direct interface IP (typically 192.168.49.x range for WiFi Direct)
        // This is the standard WiFi Direct GO (Group Owner) IP range
        let wifi_direct_ip = std::env::var("WIFI_DIRECT_LOCAL_IP")
            .unwrap_or_else(|_| "192.168.49.1".to_string()); // WiFi Direct standard range
            
        Ok(wifi_direct_ip.parse()?)
    }

    fn get_battery_level() -> Option<u8> {
        // Battery level detection for handheld devices
        // Placeholder - would integrate with actual battery APIs
        Some(85)
    }

    fn current_timestamp() -> u64 {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs()
    }

    async fn calculate_file_hash(
        &self,
        file_path: &Path,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let data = tokio::fs::read(file_path).await?;
        let mut hasher = Sha256::new();
        hasher.update(&data);
        Ok(hex::encode(hasher.finalize()))
    }

    fn detect_mime_type(file_path: &Path) -> String {
        match file_path.extension().and_then(|ext| ext.to_str()) {
            Some("mp3") => "audio/mpeg".to_string(),
            Some("mp4") => "video/mp4".to_string(),
            Some("jpg") | Some("jpeg") => "image/jpeg".to_string(),
            Some("png") => "image/png".to_string(),
            Some("txt") => "text/plain".to_string(),
            Some("pdf") => "application/pdf".to_string(),
            _ => "application/octet-stream".to_string(),
        }
    }

    async fn broadcast_discovery(
        device_info: &PeerDevice,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let message = P2PMessage::Discovery {
            device_info: device_info.clone(),
        };

        let data = serde_json::to_vec(&message)?;

        // Broadcast to local network
        let socket = UdpSocket::bind("0.0.0.0:0").await?;
        socket.set_broadcast(true)?;

        let broadcast_addr = SocketAddr::new("255.255.255.255".parse()?, 8091);
        socket.send_to(&data, broadcast_addr).await?;

        Ok(())
    }

    async fn broadcast_file_list(&self) -> Result<(), Box<dyn std::error::Error>> {
        let shared_files_read = self.shared_files.read().await;
        let files: Vec<SharedFile> = shared_files_read.values().cloned().collect();

        let message = P2PMessage::FileList { files };

        let peers_read = self.peers.read().await;
        for peer in peers_read.values() {
            if let Err(e) = self.send_message_to_peer(&message, peer).await {
                log::debug!("Failed to send file list to {}: {}", peer.device_name, e);
            }
        }

        Ok(())
    }

    async fn send_message_to_peer(
        &self,
        message: &P2PMessage,
        peer: &PeerDevice,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let data = serde_json::to_vec(message)?;
        let addr = SocketAddr::new(peer.ip_address, peer.port);

        let mut stream = TcpStream::connect(addr).await?;
        stream.write_all(&data).await?;

        Ok(())
    }

    async fn send_heartbeat(
        device_id: &str,
        peer: &PeerDevice,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let message = P2PMessage::Heartbeat {
            device_id: device_id.to_string(),
            battery_level: Self::get_battery_level(),
        };

        let data = serde_json::to_vec(&message)?;
        let addr = SocketAddr::new(peer.ip_address, peer.port);

        let mut stream = TcpStream::connect(addr).await?;
        stream.write_all(&data).await?;

        Ok(())
    }

    async fn handle_tcp_connection(
        mut stream: TcpStream,
        peers: Arc<RwLock<HashMap<String, PeerDevice>>>,
        active_transfers: Arc<RwLock<HashMap<String, FileTransfer>>>,
        shared_files: Arc<RwLock<HashMap<String, SharedFile>>>,
        chunk_size: usize,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut buffer = vec![0; chunk_size];
        let len = stream.read(&mut buffer).await?;
        buffer.truncate(len);

        if let Ok(message) = serde_json::from_slice::<P2PMessage>(&buffer) {
            match message {
                P2PMessage::FileRequest {
                    file_id,
                    chunk_index,
                } => {
                    // Handle file request
                    let shared_files_read = shared_files.read().await;
                    if let Some(file_info) = shared_files_read.get(&file_id) {
                        Self::send_file_chunk(&mut stream, file_info, chunk_index, chunk_size)
                            .await?;
                    }
                }
                _ => {
                    log::debug!("Received TCP message: {:?}", message);
                }
            }
        }

        Ok(())
    }

    async fn send_file_chunk(
        stream: &mut TcpStream,
        file_info: &SharedFile,
        chunk_index: Option<u32>,
        chunk_size: usize,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let file_data = tokio::fs::read(&file_info.file_path).await?;
        let total_chunks = (file_data.len() + chunk_size - 1) / chunk_size;

        match chunk_index {
            Some(index) => {
                // Send specific chunk
                let start = (index as usize) * chunk_size;
                let end = std::cmp::min(start + chunk_size, file_data.len());
                let chunk_data = file_data[start..end].to_vec();

                let message = P2PMessage::FileShare {
                    file_info: file_info.clone(),
                    chunk_data: Some(chunk_data),
                    chunk_index: index,
                    total_chunks: total_chunks as u32,
                };

                let data = serde_json::to_vec(&message)?;
                stream.write_all(&data).await?;
            }
            None => {
                // Send entire file in chunks
                for i in 0..total_chunks {
                    let start = i * chunk_size;
                    let end = std::cmp::min(start + chunk_size, file_data.len());
                    let chunk_data = file_data[start..end].to_vec();

                    let message = P2PMessage::FileShare {
                        file_info: file_info.clone(),
                        chunk_data: Some(chunk_data),
                        chunk_index: i as u32,
                        total_chunks: total_chunks as u32,
                    };

                    let data = serde_json::to_vec(&message)?;
                    stream.write_all(&data).await?;

                    // Small delay between chunks for battery efficiency
                    tokio::time::sleep(Duration::from_millis(10)).await;
                }
            }
        }

        Ok(())
    }

    async fn handle_discovery_message(
        message: P2PMessage,
        peer_addr: SocketAddr,
        peers: Arc<RwLock<HashMap<String, PeerDevice>>>,
        device_info: &PeerDevice,
        socket: &Arc<UdpSocket>,
        message_sender: &broadcast::Sender<P2PMessage>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match message {
            P2PMessage::Discovery {
                device_info: peer_info,
            } => {
                let mut peer_info = peer_info;
                // Update peer info
                peer_info.ip_address = peer_addr.ip();
                peer_info.last_seen = Self::current_timestamp();

                let mut peers_write = peers.write().await;
                peers_write.insert(peer_info.device_id.clone(), peer_info.clone());

                // Send our discovery response
                let response = P2PMessage::Discovery {
                    device_info: device_info.clone(),
                };
                let data = serde_json::to_vec(&response)?;
                socket.send_to(&data, peer_addr).await?;

                // Notify application
                let discovery_message = P2PMessage::Discovery {
                    device_info: peer_info.clone(),
                };
                let _ = message_sender.send(discovery_message);
            }
            _ => {
                log::debug!("Received UDP message: {:?}", message);
            }
        }

        Ok(())
    }

    /// Shutdown the P2P mesh
    pub async fn shutdown(&self) -> Result<(), Box<dyn std::error::Error>> {
        *self.shutdown_signal.write().await = true;
        log::info!("P2P mesh shutting down");
        Ok(())
    }
}

/// Helper trait for applications to integrate P2P file sharing
pub trait P2PIntegration {
    fn get_p2p_manager(&self) -> &P2PMeshManager;

    async fn share_file(&self, file_path: PathBuf) -> Result<String, Box<dyn std::error::Error>> {
        self.get_p2p_manager()
            .share_file(file_path, None, vec![])
            .await
    }

    async fn search_shared_files(
        &self,
        query: String,
    ) -> Result<Vec<SharedFile>, Box<dyn std::error::Error>> {
        self.get_p2p_manager().search_files(query, vec![]).await
    }

    async fn get_mesh_peers(&self) -> Vec<PeerDevice> {
        self.get_p2p_manager().get_peers().await
    }
}

```
<!-- }}} -->

<!-- {{{ scripts/run_tests.sh - Complete Context -->
### 📄 scripts/run_tests.sh

**File Metadata:**
- Size: 8483 bytes
- Lines: 297
- Modified: 2025-09-23 00:03:19.428853064 -0700
- Language: 

**File Content:**

```
#!/bin/bash
# Handheld Office Test Execution Script
# Usage: ./scripts/run_tests.sh [quick|full|critical|performance|coverage]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if cargo command exists
check_cargo() {
    if ! command -v cargo &> /dev/null; then
        print_error "Cargo not found. Please install Rust and Cargo."
        exit 1
    fi
}

# Function to install required tools
install_tools() {
    print_status "Checking and installing required tools..."
    
    # Check for tarpaulin (coverage)
    if ! cargo tarpaulin --version &> /dev/null; then
        print_status "Installing cargo-tarpaulin for coverage reports..."
        cargo install cargo-tarpaulin
    fi
    
    # Check for criterion (already in dev-dependencies)
    print_success "All required tools are available"
}

# Function to run quick tests
run_quick_tests() {
    print_status "Running quick test suite (< 5 minutes)..."
    
    print_status "1. Format check..."
    cargo fmt --all -- --check || {
        print_warning "Code formatting issues found. Run 'cargo fmt' to fix."
    }
    
    print_status "2. Clippy linting..."
    cargo clippy --all-targets --no-default-features || {
        print_warning "Clippy warnings found. Consider fixing for better code quality."
    }
    
    print_status "3. Core unit tests..."
    cargo test --no-default-features --lib || {
        print_error "Core unit tests failed"
        return 1
    }
    
    print_success "Quick tests completed successfully!"
}

# Function to run critical tests only
run_critical_tests() {
    print_status "Running critical tests only..."
    
    print_status "1. Core functionality tests..."
    cargo test --no-default-features --lib || {
        print_error "Core unit tests failed"
        return 1
    }
    
    print_status "2. Integration tests..."
    cargo test --no-default-features --test integration || {
        print_error "Integration tests failed"
        return 1
    }
    
    print_status "3. Security and stability tests..."
    cargo test --no-default-features security_ stability_ || {
        print_warning "Some security/stability tests failed"
    }
    
    print_success "Critical tests completed!"
}

# Function to run full test suite
run_full_tests() {
    print_status "Running full test suite (15-30 minutes)..."
    
    print_status "1. All unit tests..."
    cargo test --no-default-features --lib || {
        print_error "Unit tests failed"
        return 1
    }
    
    print_status "2. All integration tests..."
    cargo test --no-default-features --tests || {
        print_error "Integration tests failed"
        return 1
    }
    
    print_status "3. Documentation tests..."
    cargo test --no-default-features --doc || {
        print_warning "Documentation tests failed"
    }
    
    print_status "4. Example tests..."
    cargo test --no-default-features --examples || {
        print_warning "Example tests failed"
    }
    
    print_success "Full test suite completed!"
}

# Function to run performance tests
run_performance_tests() {
    print_status "Running performance benchmarks..."
    
    print_status "1. Paint performance benchmarks..."
    cargo bench paint_performance || {
        print_warning "Paint benchmarks had issues"
    }
    
    print_status "2. Music performance benchmarks..."
    cargo bench music_performance || {
        print_warning "Music benchmarks had issues"
    }
    
    print_status "3. Terminal performance benchmarks..."
    cargo bench terminal_performance || {
        print_warning "Terminal benchmarks had issues"
    }
    
    print_status "4. Memory stress tests..."
    cargo bench memory_stress || {
        print_warning "Memory stress tests had issues"
    }
    
    print_success "Performance tests completed! Check files/target/criterion/report/index.html for detailed results."
}

# Function to run coverage analysis
run_coverage() {
    print_status "Generating code coverage report..."
    
    # Clean previous coverage data
    rm -rf coverage/
    mkdir -p coverage/
    
    print_status "Running tests with coverage analysis..."
    cargo tarpaulin --out Html --output-dir coverage --timeout 300 || {
        print_error "Coverage analysis failed"
        return 1
    }
    
    print_success "Coverage report generated! Open coverage/tarpaulin-report.html to view results."
    
    # Try to open coverage report automatically
    if command -v xdg-open &> /dev/null; then
        xdg-open coverage/tarpaulin-report.html &
    elif command -v open &> /dev/null; then
        open coverage/tarpaulin-report.html &
    else
        print_status "Open coverage/tarpaulin-report.html in your browser to view the report."
    fi
}

# Function to run stress tests
run_stress_tests() {
    print_status "Running stress tests (may take a while)..."
    
    print_status "1. Memory stress tests..."
    cargo test --no-default-features --release memory_stress --ignored || {
        print_warning "Memory stress tests had issues"
    }
    
    print_status "2. Performance stress tests..."
    cargo test --no-default-features --release performance_stress --ignored || {
        print_warning "Performance stress tests had issues"
    }
    
    print_status "3. Long-running stability tests..."
    cargo test --no-default-features --release stability_ --ignored || {
        print_warning "Stability tests had issues"
    }
    
    print_success "Stress tests completed!"
}

# Function to show usage
show_usage() {
    echo "Handheld Office Test Runner"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  quick       Run quick tests (format, clippy, core units) - ~3 minutes"
    echo "  critical    Run critical tests only - ~10 minutes"
    echo "  full        Run complete test suite - ~20 minutes"
    echo "  performance Run performance benchmarks - ~15 minutes"
    echo "  coverage    Generate code coverage report - ~10 minutes"
    echo "  stress      Run stress and stability tests - ~30 minutes"
    echo "  all         Run everything (full + performance + coverage) - ~45 minutes"
    echo ""
    echo "Examples:"
    echo "  $0 quick           # Pre-commit checks"
    echo "  $0 critical        # CI critical path"
    echo "  $0 full            # Complete validation"
    echo "  $0 coverage        # Coverage analysis"
    echo ""
}

# Function to run all tests
run_all_tests() {
    print_status "Running complete test suite with all components..."
    
    local start_time=$(date +%s)
    
    run_full_tests || return 1
    run_performance_tests
    run_coverage || return 1
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_success "All tests completed in ${duration} seconds!"
    print_status "Results:"
    print_status "  - Test results: Check console output above"
    print_status "  - Performance: files/target/criterion/report/index.html"
    print_status "  - Coverage: coverage/tarpaulin-report.html"
}

# Main execution
main() {
    print_status "Handheld Office Test Runner"
    print_status "Working directory: $(pwd)"
    print_status "Timestamp: $(date)"
    echo ""
    
    check_cargo
    
    case "${1:-quick}" in
        "quick")
            install_tools
            run_quick_tests
            ;;
        "critical")
            install_tools
            run_critical_tests
            ;;
        "full")
            install_tools
            run_full_tests
            ;;
        "performance")
            install_tools
            run_performance_tests
            ;;
        "coverage")
            install_tools
            run_coverage
            ;;
        "stress")
            install_tools
            run_stress_tests
            ;;
        "all")
            install_tools
            run_all_tests
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
```
<!-- }}} -->

<!-- {{{ src/enhanced_input.rs - Complete Context -->
### 📄 src/enhanced_input.rs

**File Metadata:**
- Size: 79485 bytes
- Lines: 2160
- Modified: 2025-09-23 09:21:42.794271211 -0700
- Language: 

**File Content:**

```
/// Enhanced input system with edit mode, configurable keyboards, and multi-controller support
/// Implements the proposed improvements from claude-next-2
use crate::input_config::*;
use crate::p2p_mesh::{P2PMeshManager, P2PIntegration, PeerDevice, DeviceType, SharedFile};
use crate::wifi_direct_p2p::{WiFiDirectP2P, MessageContent};
use crate::ai_image_service::{ImageGenerationRequest, ImageGenerationResponse, ImageStyle, ImageResolution};
use crate::crypto::{P2PMigrationAdapter, RelationshipId, PairingEmoji as CryptoPairingEmoji};
use serde::{Serialize, Deserialize};
use std::collections::HashMap;
use std::f32::consts::PI;
use std::time::{Duration, Instant};
use std::path::PathBuf;
use chrono;
use futures;
use base64::{Engine as _, engine::general_purpose};

// P2P integration is implemented directly in this file

/// Enhanced input manager that handles different input modes and controller types
pub struct EnhancedInputManager {
    pub config: InputConfig,
    pub current_mode: EnhancedInputMode,
    pub text_buffer: String,
    pub cursor_position: usize,
    pub edit_mode_state: EditModeState,
    pub one_time_keyboard_state: Option<OneTimeKeyboardState>,
    pub button_states: HashMap<String, ButtonState>,
    pub last_input_time: Instant,
    
    // P2P mesh networking for document sharing (legacy)
    pub p2p_manager: Option<P2PMeshManager>,
    pub p2p_enabled: bool,
    pub shared_documents: Vec<SharedDocument>,
    pub auto_save_enabled: bool,
    pub document_metadata: DocumentMetadata,
    pub collaboration_state: Option<CollaborationState>,
    
    // WiFi Direct P2P for AI image generation (legacy)
    pub wifi_direct: Option<WiFiDirectP2P>,
    pub wifi_direct_connected: bool,
    pub available_image_files: Vec<ImageFileEntry>,
    pub pending_image_requests: Vec<PendingImageRequest>,
    pub images_directory: PathBuf,
    
    // Secure P2P system with crypto integration
    pub secure_p2p: Option<P2PMigrationAdapter>,
    pub secure_p2p_enabled: bool,
    pub secure_relationships: Vec<RelationshipId>,
    pub pairing_mode_active: bool,
    pub discovered_secure_devices: Vec<CryptoPairingEmoji>,
}

#[derive(Debug, Clone)]
pub enum EnhancedInputMode {
    Navigation,
    EditMode,
    OneTimeKeyboard { target_mode: Box<EnhancedInputMode> },
    RadialMenu { state: RadialMenuState },
    SpecialCharacterMode,
    P2PBrowser,
    CollaborationMode,
    DocumentSaver,
    ImageMenu { submenu: ImageSubmenu },
    AIImagePrompt { prompt: String },
    SecurePairing { stage: SecurePairingStage },
    SecureDeviceSelection { devices: Vec<CryptoPairingEmoji> },
    RelationshipManager,
}

#[derive(Debug, Clone)]
pub enum ImageSubmenu {
    Main,
    FileSelection { files: Vec<ImageFileEntry> },
    AIGeneration,
}

#[derive(Debug, Clone)]
pub enum SecurePairingStage {
    /// Initiating pairing mode
    Initiating,
    /// Broadcasting our emoji and scanning
    Broadcasting { our_emoji: CryptoPairingEmoji },
    /// Showing discovered devices for selection
    DeviceSelection { devices: Vec<CryptoPairingEmoji> },
    /// Entering nickname for selected device
    NicknameEntry { target_device: CryptoPairingEmoji, partial_nickname: String },
    /// Completing pairing process
    Completing { target_device: CryptoPairingEmoji, nickname: String },
    /// Pairing completed successfully
    Completed { relationship_id: RelationshipId },
    /// Pairing failed
    Failed { error: String },
}

#[derive(Debug, Clone)]
pub struct ImageFileEntry {
    pub path: PathBuf,
    pub name: String,
    pub source: ImageSource,
    pub thumbnail_available: bool,
}

#[derive(Debug, Clone)]
pub enum ImageSource {
    Paint,
    AIGenerated,
    Shared,
    Downloaded,
}

#[derive(Debug, Clone)]
pub struct PendingImageRequest {
    pub request_id: String,
    pub prompt: String,
    pub placeholder_position: usize,
    pub target_application: String,
    pub timestamp: Instant,
}

#[derive(Debug, Clone)]
pub struct EditModeState {
    pub cursor_line: usize,
    pub cursor_column: usize,
    pub selection_start: Option<CursorPosition>,
    pub selection_end: Option<CursorPosition>,
    pub word_wrap_enabled: bool,
    pub auto_exit_timer: Option<Instant>,
    pub last_cursor_move: Instant,
}

#[derive(Debug, Clone)]
pub struct CursorPosition {
    pub line: usize,
    pub column: usize,
    pub absolute_position: usize,
}

#[derive(Debug, Clone)]
pub struct OneTimeKeyboardState {
    pub layout: String,
    pub sector_index: usize,
    pub character_index: usize,
    pub return_mode: EnhancedInputMode,
    pub partial_input: String,
}

#[derive(Debug, Clone)]
pub struct ButtonState {
    pub pressed: bool,
    pub press_time: Option<Instant>,
    pub release_time: Option<Instant>,
    pub press_count: usize,
    pub last_press_time: Option<Instant>,
}

/// P2P-specific structures for word processor
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedDocument {
    pub file_hash: String,
    pub filename: String,
    pub content: String,
    pub author: String,
    pub created_time: u64,
    pub last_modified: u64,
    pub tags: Vec<String>,
    pub file_size: usize,
    pub device_info: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DocumentMetadata {
    pub filename: String,
    pub author: String,
    pub created_time: u64,
    pub last_modified: u64,
    pub word_count: usize,
    pub character_count: usize,
    pub tags: Vec<String>,
    pub version: u32,
}

#[derive(Debug, Clone)]
pub struct CollaborationState {
    pub session_id: String,
    pub participants: Vec<String>,
    pub document_hash: String,
    pub last_sync: u64,
    pub pending_changes: Vec<DocumentChange>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DocumentChange {
    pub change_id: String,
    pub author: String,
    pub timestamp: u64,
    pub change_type: ChangeType,
    pub position: usize,
    pub content: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ChangeType {
    Insert,
    Delete,
    Replace,
    CursorMove,
}

/// Radial menu system for enhanced input
#[derive(Debug, Clone)]
pub struct RadialMenuState {
    pub center_x: f32,
    pub center_y: f32,
    pub active_direction: Direction,
    pub active_angle: f32,
    pub menu_options: [Option<char>; 4],
    pub selected_option: Option<usize>,
    pub alphabet_layout: AlphabetLayout,
    pub is_visible: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Direction {
    Up,
    Down,
    Left,
    Right,
    UpLeft,
    UpRight,
    DownLeft,
    DownRight,
}

#[derive(Debug, Clone)]
pub struct AlphabetLayout {
    pub sectors: HashMap<Direction, [char; 4]>,
}

impl Default for AlphabetLayout {
    fn default() -> Self {
        let mut sectors = HashMap::new();
        
        // Distribute A-Z across 8 directions (32 total slots, using 26)
        sectors.insert(Direction::Up, ['A', 'B', 'C', 'D']);
        sectors.insert(Direction::UpRight, ['E', 'F', 'G', 'H']);
        sectors.insert(Direction::Right, ['I', 'J', 'K', 'L']);
        sectors.insert(Direction::DownRight, ['M', 'N', 'O', 'P']);
        sectors.insert(Direction::Down, ['Q', 'R', 'S', 'T']);
        sectors.insert(Direction::DownLeft, ['U', 'V', 'W', 'X']);
        sectors.insert(Direction::Left, ['Y', 'Z', ' ', '.']);
        sectors.insert(Direction::UpLeft, ['!', '?', ',', ';']);
        
        Self { sectors }
    }
}

impl RadialMenuState {
    pub fn new(center_x: f32, center_y: f32) -> Self {
        Self {
            center_x,
            center_y,
            active_direction: Direction::Up,
            active_angle: 0.0,
            menu_options: [None; 4],
            selected_option: None,
            alphabet_layout: AlphabetLayout::default(),
            is_visible: false,
        }
    }
    
    pub fn update_direction(&mut self, direction: Direction) {
        self.active_direction = direction;
        self.active_angle = self.direction_to_angle(direction);
        self.update_menu_options();
        self.is_visible = true;
    }
    
    fn direction_to_angle(&self, direction: Direction) -> f32 {
        match direction {
            Direction::Up => 270.0,
            Direction::UpRight => 315.0,
            Direction::Right => 0.0,
            Direction::DownRight => 45.0,
            Direction::Down => 90.0,
            Direction::DownLeft => 135.0,
            Direction::Left => 180.0,
            Direction::UpLeft => 225.0,
        }
    }
    
    fn update_menu_options(&mut self) {
        if let Some(chars) = self.alphabet_layout.sectors.get(&self.active_direction) {
            for (i, &ch) in chars.iter().enumerate() {
                self.menu_options[i] = Some(ch);
            }
        } else {
            self.menu_options = [None; 4];
        }
    }
    
    pub fn get_option_positions(&self) -> [(f32, f32); 4] {
        let radius = 50.0; // Distance from center
        let base_angle_rad = self.active_angle * PI / 180.0;
        
        // Position options in an arc around the direction
        let mut positions = [(0.0, 0.0); 4];
        
        match self.active_direction {
            Direction::Left => {
                // LEFT: First two options below X-axis, next two above X-axis
                let angles = [-30.0, -60.0, 30.0, 60.0]; // Relative to left (180°)
                for (i, &angle_offset) in angles.iter().enumerate() {
                    let angle_rad = (180.0 + angle_offset) * PI / 180.0;
                    positions[i] = (
                        self.center_x + radius * angle_rad.cos(),
                        self.center_y + radius * angle_rad.sin(),
                    );
                }
            },
            Direction::UpRight => {
                // UP+RIGHT: Menu at 45° angle
                let angles = [-30.0, -15.0, 15.0, 30.0]; // Relative to 45°
                for (i, &angle_offset) in angles.iter().enumerate() {
                    let angle_rad = (315.0 + angle_offset) * PI / 180.0;
                    positions[i] = (
                        self.center_x + radius * angle_rad.cos(),
                        self.center_y + radius * angle_rad.sin(),
                    );
                }
            },
            _ => {
                // Default arc positioning
                let angles = [-30.0, -10.0, 10.0, 30.0]; // Spread around direction
                for (i, &angle_offset) in angles.iter().enumerate() {
                    let angle_rad = (base_angle_rad + angle_offset * PI / 180.0);
                    positions[i] = (
                        self.center_x + radius * angle_rad.cos(),
                        self.center_y + radius * angle_rad.sin(),
                    );
                }
            }
        }
        
        positions
    }
    
    pub fn select_option(&mut self, button_index: usize) -> Option<char> {
        if button_index < 4 {
            self.selected_option = Some(button_index);
            self.menu_options[button_index]
        } else {
            None
        }
    }
    
    pub fn hide(&mut self) {
        self.is_visible = false;
        self.selected_option = None;
    }
    
    /// Get visual rendering data for the radial menu
    pub fn get_render_data(&self) -> RadialMenuRenderData {
        let positions = self.get_option_positions();
        let mut options = Vec::new();
        
        for (i, pos) in positions.iter().enumerate() {
            if let Some(character) = self.menu_options[i] {
                options.push(RadialMenuOption {
                    character,
                    position: *pos,
                    selected: self.selected_option == Some(i),
                    button_hint: match i {
                        0 => "L1".to_string(),
                        1 => "B".to_string(), 
                        2 => "A".to_string(),
                        3 => "Y".to_string(),
                        _ => "".to_string(),
                    },
                });
            }
        }
        
        RadialMenuRenderData {
            center: (self.center_x, self.center_y),
            options,
            direction: self.active_direction.clone(),
            angle: self.active_angle,
            visible: self.is_visible,
        }
    }
}

/// Data structure for rendering the radial menu
#[derive(Debug, Clone)]
pub struct RadialMenuRenderData {
    pub center: (f32, f32),
    pub options: Vec<RadialMenuOption>,
    pub direction: Direction,
    pub angle: f32,
    pub visible: bool,
}

#[derive(Debug, Clone)]
pub struct RadialMenuOption {
    pub character: char,
    pub position: (f32, f32),
    pub selected: bool,
    pub button_hint: String,
}

/// Radial button inputs for universal controller support
#[derive(Debug, Clone, PartialEq)]
pub enum UniversalButton {
    // Basic buttons (Game Boy compatible)
    A,
    B,
    Select,
    Start,

    // Extended buttons (SNES compatible)
    X,
    Y,
    L,
    R,

    // D-Pad directions
    Up,
    Down,
    Left,
    Right,

    // Custom/mapped buttons
    Custom(String),
}

#[derive(Debug, Clone)]
pub enum InputResult {
    TextInput { text: String },
    InsertText { text: String },
    ReplaceText { find: String, replace: String },
    ModeChange { new_mode: EnhancedInputMode },
    CursorMove { new_position: usize },
    SpecialAction { action: String },
    Navigation { direction: String },
    StatusMessage { message: String },
    NoAction,
}

impl EnhancedInputManager {
    pub fn new(config: InputConfig) -> Self {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
            
        Self {
            config,
            current_mode: EnhancedInputMode::Navigation,
            text_buffer: String::new(),
            cursor_position: 0,
            edit_mode_state: EditModeState {
                cursor_line: 0,
                cursor_column: 0,
                selection_start: None,
                selection_end: None,
                word_wrap_enabled: true,
                auto_exit_timer: None,
                last_cursor_move: Instant::now(),
            },
            one_time_keyboard_state: None,
            button_states: HashMap::new(),
            last_input_time: Instant::now(),
            
            // P2P fields
            p2p_manager: None,
            p2p_enabled: false,
            shared_documents: Vec::new(),
            auto_save_enabled: true,
            document_metadata: DocumentMetadata {
                filename: "untitled.txt".to_string(),
                author: "anonymous".to_string(),
                created_time: now,
                last_modified: now,
                word_count: 0,
                character_count: 0,
                tags: vec!["handheld".to_string(), "draft".to_string()],
                version: 1,
            },
            collaboration_state: None,
            
            // WiFi Direct P2P for AI image generation
            wifi_direct: None,
            wifi_direct_connected: false,
            available_image_files: Vec::new(),
            pending_image_requests: Vec::new(),
            images_directory: PathBuf::from("./images"),
            
            // Secure P2P system with crypto integration
            secure_p2p: None,
            secure_p2p_enabled: false,
            secure_relationships: Vec::new(),
            pairing_mode_active: false,
            discovered_secure_devices: Vec::new(),
        }
    }

    /// Handle button input with enhanced features
    pub fn handle_button_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
    ) -> Vec<InputResult> {
        self.last_input_time = Instant::now();
        self.update_button_state(button.clone(), pressed);

        match self.current_mode.clone() {
            EnhancedInputMode::Navigation => self.handle_navigation_input(button, pressed),
            EnhancedInputMode::EditMode => self.handle_edit_mode_input(button, pressed),
            EnhancedInputMode::OneTimeKeyboard { target_mode } => {
                self.handle_one_time_keyboard_input(button, pressed, *target_mode)
            }
            EnhancedInputMode::RadialMenu { state } => {
                self.handle_radial_menu_input(button, pressed, state)
            }
            EnhancedInputMode::SpecialCharacterMode => {
                self.handle_special_character_input(button, pressed)
            }
            EnhancedInputMode::P2PBrowser => {
                self.handle_p2p_browser_input(button, pressed)
            }
            EnhancedInputMode::CollaborationMode => {
                self.handle_collaboration_mode_input(button, pressed)
            }
            EnhancedInputMode::DocumentSaver => {
                self.handle_document_saver_input(button, pressed)
            }
            EnhancedInputMode::ImageMenu { submenu } => {
                self.handle_image_menu_input(button, pressed, submenu)
            }
            EnhancedInputMode::AIImagePrompt { prompt } => {
                self.handle_ai_image_prompt_input(button, pressed, prompt)
            }
            EnhancedInputMode::SecurePairing { stage } => {
                self.handle_secure_pairing_input(button, pressed, stage)
            }
            EnhancedInputMode::SecureDeviceSelection { devices } => {
                self.handle_secure_device_selection_input(button, pressed, devices)
            }
            EnhancedInputMode::RelationshipManager => {
                self.handle_relationship_manager_input(button, pressed)
            }
        }
    }

    fn update_button_state(&mut self, button: UniversalButton, pressed: bool) {
        let button_name = format!("{:?}", button);
        let state = self
            .button_states
            .entry(button_name)
            .or_insert(ButtonState {
                pressed: false,
                press_time: None,
                release_time: None,
                press_count: 0,
                last_press_time: None,
            });

        if pressed && !state.pressed {
            // Button press detected
            state.pressed = true;
            state.press_time = Some(Instant::now());

            // Count rapid presses for double-tap detection
            if let Some(last_press) = state.last_press_time {
                if Instant::now().duration_since(last_press) < Duration::from_millis(500) {
                    state.press_count += 1;
                } else {
                    state.press_count = 1;
                }
            } else {
                state.press_count = 1;
            }
            state.last_press_time = Some(Instant::now());
        } else if !pressed && state.pressed {
            // Button release detected
            state.pressed = false;
            state.release_time = Some(Instant::now());
        }
    }

    fn handle_navigation_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select => {
                // SELECT enters edit mode (as proposed)
                vec![self.enter_edit_mode()]
            }
            UniversalButton::A => {
                vec![InputResult::Navigation {
                    direction: "select".to_string(),
                }]
            }
            UniversalButton::B => {
                vec![InputResult::Navigation {
                    direction: "back".to_string(),
                }]
            }
            UniversalButton::Start => {
                // START opens P2P browser when P2P is enabled
                if self.p2p_enabled {
                    self.current_mode = EnhancedInputMode::P2PBrowser;
                    vec![InputResult::ModeChange {
                        new_mode: self.current_mode.clone(),
                    }]
                } else {
                    vec![InputResult::Navigation {
                        direction: "menu".to_string(),
                    }]
                }
            }
            UniversalButton::X => {
                // X opens document saver (SNES controllers)
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    self.current_mode = EnhancedInputMode::DocumentSaver;
                    vec![InputResult::ModeChange {
                        new_mode: self.current_mode.clone(),
                    }]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Y => {
                // Y toggles P2P features (SNES controllers)
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    vec![self.toggle_p2p()]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Up
            | UniversalButton::Down
            | UniversalButton::Left
            | UniversalButton::Right => self.handle_directional_navigation(button),
            _ => vec![InputResult::NoAction],
        }
    }

    fn handle_edit_mode_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select => {
                // SELECT exits edit mode
                vec![self.exit_edit_mode()]
            }
            UniversalButton::A => {
                // A opens one-time keyboard for character input
                vec![self.enter_one_time_keyboard()]
            }
            UniversalButton::B => {
                // B acts as backspace in edit mode
                vec![self.handle_backspace()]
            }
            UniversalButton::Up
            | UniversalButton::Down
            | UniversalButton::Left
            | UniversalButton::Right => {
                // D-pad moves cursor in edit mode
                vec![self.handle_cursor_movement(button)]
            }
            _ => vec![InputResult::NoAction],
        }
    }

    fn handle_one_time_keyboard_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        return_mode: EnhancedInputMode,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::A => {
                // Select current character and return to edit mode
                if let Some(character) = self.get_current_keyboard_character() {
                    self.current_mode = return_mode;
                    self.one_time_keyboard_state = None;
                    vec![
                        self.insert_character_at_cursor(character),
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::B => {
                // Cancel and return to edit mode
                self.current_mode = return_mode;
                self.one_time_keyboard_state = None;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::Up
            | UniversalButton::Down
            | UniversalButton::Left
            | UniversalButton::Right => {
                // Navigate through keyboard characters
                vec![self.navigate_keyboard_character(button)]
            }
            _ => vec![InputResult::NoAction],
        }
    }

    fn handle_directional_navigation(&mut self, button: UniversalButton) -> Vec<InputResult> {
        match &self.config.controller_type {
            ControllerType::SNES { .. } => {
                // Check if L or R is pressed for media functions
                let l_pressed = self.button_states.get("L").map_or(false, |s| s.pressed);
                let r_pressed = self.button_states.get("R").map_or(false, |s| s.pressed);
                
                // SNES-style: D-pad opens radial menus with proper direction mapping
                let direction = self.button_to_direction(button);
                let mut radial_state = RadialMenuState::new(400.0, 300.0); // Default screen center
                radial_state.update_direction(direction);
                
                self.current_mode = EnhancedInputMode::RadialMenu {
                    state: radial_state,
                };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            _ => {
                // Game Boy style: simple navigation
                let direction = match button {
                    UniversalButton::Up => "up",
                    UniversalButton::Down => "down",
                    UniversalButton::Left => "left",
                    UniversalButton::Right => "right",
                    _ => "unknown",
                };
                vec![InputResult::Navigation {
                    direction: direction.to_string(),
                }]
            }
        }
    }

    fn enter_edit_mode(&mut self) -> InputResult {
        self.current_mode = EnhancedInputMode::EditMode;
        self.edit_mode_state.auto_exit_timer = Some(
            Instant::now()
                + Duration::from_millis(self.config.edit_mode_settings.auto_exit_timeout_ms),
        );
        InputResult::ModeChange {
            new_mode: self.current_mode.clone(),
        }
    }

    fn exit_edit_mode(&mut self) -> InputResult {
        self.current_mode = EnhancedInputMode::Navigation;
        self.edit_mode_state.auto_exit_timer = None;
        InputResult::ModeChange {
            new_mode: self.current_mode.clone(),
        }
    }

    fn enter_one_time_keyboard(&mut self) -> InputResult {
        let layout = self
            .config
            .keyboard_layouts
            .keys()
            .next()
            .unwrap_or(&"default".to_string())
            .clone();

        self.one_time_keyboard_state = Some(OneTimeKeyboardState {
            layout: layout.clone(),
            sector_index: 0,
            character_index: 0,
            return_mode: EnhancedInputMode::EditMode,
            partial_input: String::new(),
        });

        let old_mode = self.current_mode.clone();
        self.current_mode = EnhancedInputMode::OneTimeKeyboard {
            target_mode: Box::new(old_mode),
        };

        InputResult::ModeChange {
            new_mode: self.current_mode.clone(),
        }
    }

    fn handle_backspace(&mut self) -> InputResult {
        if self.cursor_position > 0 && !self.text_buffer.is_empty() {
            self.cursor_position -= 1;
            self.text_buffer.remove(self.cursor_position);
            InputResult::TextInput {
                text: self.text_buffer.clone(),
            }
        } else {
            InputResult::NoAction
        }
    }

    fn handle_cursor_movement(&mut self, direction: UniversalButton) -> InputResult {
        self.edit_mode_state.last_cursor_move = Instant::now();

        match direction {
            UniversalButton::Left => {
                if self.cursor_position > 0 {
                    self.cursor_position -= 1;
                }
            }
            UniversalButton::Right => {
                if self.cursor_position < self.text_buffer.len() {
                    self.cursor_position += 1;
                }
            }
            UniversalButton::Up => {
                // Move up one line (if multiline)
                self.move_cursor_up();
            }
            UniversalButton::Down => {
                // Move down one line (if multiline)
                self.move_cursor_down();
            }
            _ => {}
        }

        InputResult::CursorMove {
            new_position: self.cursor_position,
        }
    }

    fn move_cursor_up(&mut self) {
        if self.edit_mode_state.cursor_line > 0 {
            self.edit_mode_state.cursor_line -= 1;
            self.update_absolute_cursor_position();
        }
    }

    fn move_cursor_down(&mut self) {
        let lines: Vec<&str> = self.text_buffer.lines().collect();
        if self.edit_mode_state.cursor_line < lines.len().saturating_sub(1) {
            self.edit_mode_state.cursor_line += 1;
            self.update_absolute_cursor_position();
        }
    }

    fn update_absolute_cursor_position(&mut self) {
        let lines: Vec<&str> = self.text_buffer.lines().collect();
        let mut position = 0;

        for (i, line) in lines.iter().enumerate() {
            if i == self.edit_mode_state.cursor_line {
                position += self.edit_mode_state.cursor_column.min(line.len());
                break;
            }
            position += line.len() + 1; // +1 for newline
        }

        self.cursor_position = position.min(self.text_buffer.len());
    }

    fn get_current_keyboard_character(&self) -> Option<char> {
        if let Some(state) = &self.one_time_keyboard_state {
            if let Some(layout) = self.config.keyboard_layouts.get(&state.layout) {
                if let Some(sector) = layout.sectors.get(state.sector_index) {
                    return sector.characters.get(state.character_index).copied();
                }
            }
        }
        None
    }

    fn navigate_keyboard_character(&mut self, direction: UniversalButton) -> InputResult {
        if let Some(state) = &mut self.one_time_keyboard_state {
            if let Some(layout) = self.config.keyboard_layouts.get(&state.layout) {
                match direction {
                    UniversalButton::Up | UniversalButton::Down => {
                        // Move between sectors
                        match direction {
                            UniversalButton::Up => {
                                if state.sector_index > 0 {
                                    state.sector_index -= 1;
                                }
                            }
                            UniversalButton::Down => {
                                if state.sector_index < layout.sectors.len() - 1 {
                                    state.sector_index += 1;
                                }
                            }
                            _ => {}
                        }
                        state.character_index = 0; // Reset character index when changing sectors
                    }
                    UniversalButton::Left | UniversalButton::Right => {
                        // Move within sector
                        if let Some(sector) = layout.sectors.get(state.sector_index) {
                            match direction {
                                UniversalButton::Left => {
                                    if state.character_index > 0 {
                                        state.character_index -= 1;
                                    }
                                }
                                UniversalButton::Right => {
                                    if state.character_index < sector.characters.len() - 1 {
                                        state.character_index += 1;
                                    }
                                }
                                _ => {}
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
        InputResult::Navigation {
            direction: format!("{:?}", direction),
        }
    }

    fn insert_character_at_cursor(&mut self, character: char) -> InputResult {
        self.text_buffer.insert(self.cursor_position, character);
        self.cursor_position += character.len_utf8();

        // Update line/column tracking
        if character == '\n' {
            self.edit_mode_state.cursor_line += 1;
            self.edit_mode_state.cursor_column = 0;
        } else {
            self.edit_mode_state.cursor_column += 1;
        }

        InputResult::TextInput {
            text: self.text_buffer.clone(),
        }
    }

    fn handle_radial_menu_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        mut state: RadialMenuState,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            // D-pad changes active direction and switches to new menu
            UniversalButton::Up
            | UniversalButton::Down
            | UniversalButton::Left
            | UniversalButton::Right => {
                let direction = self.button_to_direction(button);
                state.update_direction(direction);
                self.current_mode = EnhancedInputMode::RadialMenu { state };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            // Face buttons (L1/X=1st, L2/B=2nd, R1/A=3rd, R2/Y=4th option)
            UniversalButton::L => {
                if let Some(character) = state.select_option(0) {
                    self.current_mode = EnhancedInputMode::Navigation;
                    vec![
                        self.insert_character_at_cursor(character),
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::B => {
                if let Some(character) = state.select_option(1) {
                    self.current_mode = EnhancedInputMode::Navigation;
                    vec![
                        self.insert_character_at_cursor(character),
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::A => {
                if let Some(character) = state.select_option(2) {
                    self.current_mode = EnhancedInputMode::Navigation;
                    vec![
                        self.insert_character_at_cursor(character),
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Y => {
                if let Some(character) = state.select_option(3) {
                    self.current_mode = EnhancedInputMode::Navigation;
                    vec![
                        self.insert_character_at_cursor(character),
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Select => {
                // Exit radial menu
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            _ => vec![InputResult::NoAction],
        }
    }
    
    fn button_to_direction(&self, button: UniversalButton) -> Direction {
        match button {
            UniversalButton::Up => Direction::Up,
            UniversalButton::Down => Direction::Down,
            UniversalButton::Left => Direction::Left,
            UniversalButton::Right => Direction::Right,
            _ => Direction::Up, // Default
        }
    }
    
    // Support for complex directional input (UP+RIGHT, etc.)
    pub fn handle_complex_directional_input(&mut self, buttons: &[UniversalButton]) -> Direction {
        let up_pressed = buttons.contains(&UniversalButton::Up);
        let down_pressed = buttons.contains(&UniversalButton::Down);
        let left_pressed = buttons.contains(&UniversalButton::Left);
        let right_pressed = buttons.contains(&UniversalButton::Right);
        
        match (up_pressed, down_pressed, left_pressed, right_pressed) {
            (true, false, false, true) => Direction::UpRight,
            (true, false, true, false) => Direction::UpLeft,
            (false, true, false, true) => Direction::DownRight,
            (false, true, true, false) => Direction::DownLeft,
            (true, false, false, false) => Direction::Up,
            (false, true, false, false) => Direction::Down,
            (false, false, true, false) => Direction::Left,
            (false, false, false, true) => Direction::Right,
            _ => Direction::Up, // Default for ambiguous input
        }
    }

    fn handle_special_character_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        // Implementation for special character mode (emojis, symbols, etc.)
        match button {
            UniversalButton::Select => {
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            _ => {
                // Handle special character selection
                vec![InputResult::SpecialAction {
                    action: "special_char".to_string(),
                }]
            }
        }
    }


    fn handle_radial_action(&mut self, action: String) -> Vec<InputResult> {
        match action.as_str() {
            "image_menu" => {
                // Scan for available image files
                self.scan_for_image_files();
                self.current_mode = EnhancedInputMode::ImageMenu { 
                    submenu: ImageSubmenu::Main 
                };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            "emoji_keyboard" => {
                let mut emoji_state = RadialMenuState::new(400.0, 300.0);
                // Create emoji layout
                let mut emoji_layout = AlphabetLayout::default();
                emoji_layout.sectors.insert(Direction::Up, ['😀', '😎', '👍', '❤']);
                emoji_layout.sectors.insert(Direction::Right, ['🎮', '🔥', '⭐', '✨']);
                emoji_layout.sectors.insert(Direction::Down, ['🎯', '🚀', '💯', '🎪']);
                emoji_layout.sectors.insert(Direction::Left, ['🌟', '🎨', '🎭', '🎪']);
                emoji_state.alphabet_layout = emoji_layout;
                emoji_state.update_direction(Direction::Up);
                
                self.current_mode = EnhancedInputMode::RadialMenu { state: emoji_state };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            "special_chars" => {
                self.current_mode = EnhancedInputMode::SpecialCharacterMode;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            "settings" => {
                vec![InputResult::SpecialAction {
                    action: "open_settings".to_string(),
                }]
            }
            "shift_toggle" => {
                vec![InputResult::SpecialAction {
                    action: "toggle_shift".to_string(),
                }]
            }
            "caps_lock" => {
                vec![InputResult::SpecialAction {
                    action: "toggle_caps_lock".to_string(),
                }]
            }
            _ => vec![InputResult::NoAction],
        }
    }

    fn handle_image_menu_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        submenu: ImageSubmenu,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match submenu {
            ImageSubmenu::Main => {
                match button {
                    UniversalButton::A => {
                        // Insert existing image
                        self.current_mode = EnhancedInputMode::ImageMenu {
                            submenu: ImageSubmenu::FileSelection {
                                files: self.available_image_files.clone(),
                            },
                        };
                        vec![InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        }]
                    }
                    UniversalButton::B => {
                        // Create new AI image (if connected)
                        if self.wifi_direct_connected {
                            self.current_mode = EnhancedInputMode::AIImagePrompt {
                                prompt: String::new(),
                            };
                            vec![InputResult::ModeChange {
                                new_mode: self.current_mode.clone(),
                            }]
                        } else {
                            vec![InputResult::StatusMessage {
                                message: "AI image generation requires laptop connection".to_string(),
                            }]
                        }
                    }
                    UniversalButton::Select => {
                        // Exit image menu
                        self.current_mode = EnhancedInputMode::Navigation;
                        vec![InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        }]
                    }
                    _ => vec![InputResult::NoAction],
                }
            }
            ImageSubmenu::FileSelection { files } => {
                self.handle_image_file_selection(button, files)
            }
            ImageSubmenu::AIGeneration => {
                // Handle AI generation options
                vec![InputResult::NoAction]
            }
        }
    }

    fn handle_ai_image_prompt_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        mut prompt: String,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::A => {
                // Submit prompt for AI generation
                if !prompt.is_empty() {
                    self.submit_ai_image_request(prompt.clone())
                } else {
                    vec![InputResult::StatusMessage {
                        message: "Please enter a prompt".to_string(),
                    }]
                }
            }
            UniversalButton::B => {
                // Backspace
                prompt.pop();
                self.current_mode = EnhancedInputMode::AIImagePrompt { prompt };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::Select => {
                // Cancel AI image generation
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            _ => {
                // Open character keyboard for typing prompt
                self.current_mode = EnhancedInputMode::OneTimeKeyboard {
                    target_mode: Box::new(EnhancedInputMode::AIImagePrompt { prompt }),
                };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
        }
    }

    fn handle_image_file_selection(
        &mut self,
        button: UniversalButton,
        files: Vec<ImageFileEntry>,
    ) -> Vec<InputResult> {
        // Navigate through available image files and select one to insert
        match button {
            UniversalButton::A => {
                // Insert selected image placeholder
                if let Some(file) = files.first() {
                    let placeholder = format!("[IMAGE:{}]", file.name);
                    self.current_mode = EnhancedInputMode::Navigation;
                    vec![
                        InputResult::InsertText { text: placeholder },
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::StatusMessage {
                        message: "No images available".to_string(),
                    }]
                }
            }
            UniversalButton::Select => {
                // Exit file selection
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            _ => vec![InputResult::NoAction],
        }
    }

    fn scan_for_image_files(&mut self) {
        // Scan paint directory, AI generated images directory, and shared files
        self.available_image_files.clear();

        // Add paint files
        if let Ok(entries) = std::fs::read_dir(&self.images_directory.join("paint")) {
            for entry in entries.flatten() {
                if let Some(name) = entry.file_name().to_str() {
                    if name.ends_with(".png") || name.ends_with(".jpg") {
                        self.available_image_files.push(ImageFileEntry {
                            path: entry.path(),
                            name: name.to_string(),
                            source: ImageSource::Paint,
                            thumbnail_available: false,
                        });
                    }
                }
            }
        }

        // Add AI generated files
        if let Ok(entries) = std::fs::read_dir(&self.images_directory.join("ai_generated")) {
            for entry in entries.flatten() {
                if let Some(name) = entry.file_name().to_str() {
                    if name.ends_with(".png") || name.ends_with(".jpg") {
                        self.available_image_files.push(ImageFileEntry {
                            path: entry.path(),
                            name: name.to_string(),
                            source: ImageSource::AIGenerated,
                            thumbnail_available: false,
                        });
                    }
                }
            }
        }

        // Add shared files from P2P
        for shared_file in &self.shared_documents {
            if shared_file.filename.ends_with(".png") || shared_file.filename.ends_with(".jpg") {
                self.available_image_files.push(ImageFileEntry {
                    path: PathBuf::from(&shared_file.filename),
                    name: shared_file.filename.clone(),
                    source: ImageSource::Shared,
                    thumbnail_available: false,
                });
            }
        }
    }

    fn submit_ai_image_request(&mut self, prompt: String) -> Vec<InputResult> {
        let request_id = format!("img_{}", chrono::Utc::now().timestamp());
        let placeholder = format!("[AI_IMAGE_GENERATING:{}]", request_id);
        
        // Create pending request
        let pending_request = PendingImageRequest {
            request_id: request_id.clone(),
            prompt: prompt.clone(),
            placeholder_position: self.cursor_position,
            target_application: "document".to_string(),
            timestamp: Instant::now(),
        };
        
        self.pending_image_requests.push(pending_request);
        
        // Send WiFi Direct request if connected
        if let Some(ref wifi_direct) = self.wifi_direct {
            // This will be handled asynchronously
            let paired_devices = futures::executor::block_on(wifi_direct.get_active_peers());
            if let Some((device_id, _)) = paired_devices.into_iter().next() {
                let image_request = ImageGenerationRequest {
                    request_id: request_id.clone(),
                    sender_device_id: wifi_direct.device_id.clone(),
                    prompt: prompt.clone(),
                    negative_prompt: None,
                    style: ImageStyle::Realistic,
                    resolution: ImageResolution::Square512,
                    steps: 20,
                    guidance_scale: 7.5,
                    seed: None,
                    timestamp: chrono::Utc::now().timestamp() as u64,
                };
                
                // Send request (this would be async in real implementation)
                let _ = futures::executor::block_on(
                    wifi_direct.send_message(&device_id, MessageContent::ImageGenerationRequest {
                        request_id: image_request.request_id,
                        prompt: image_request.prompt,
                        style: "realistic".to_string(),
                        resolution: "512x512".to_string(),
                        steps: 20,
                        guidance_scale: 7.5,
                    })
                );
            }
        }
        
        // Return to navigation mode and insert placeholder
        self.current_mode = EnhancedInputMode::Navigation;
        vec![
            InputResult::InsertText { text: placeholder },
            InputResult::ModeChange {
                new_mode: self.current_mode.clone(),
            },
            InputResult::StatusMessage {
                message: format!("AI image generation started: {}", prompt),
            },
        ]
    }

    /// Initialize WiFi Direct connection
    pub fn set_wifi_direct(&mut self, wifi_direct: Option<WiFiDirectP2P>) {
        self.wifi_direct = wifi_direct;
        self.update_wifi_direct_status();
    }
    
    /// Update WiFi Direct connection status
    pub fn update_wifi_direct_status(&mut self) {
        if let Some(ref wifi_direct) = self.wifi_direct {
            // Check if any devices are connected
            let peers = futures::executor::block_on(wifi_direct.get_active_peers());
            self.wifi_direct_connected = !peers.is_empty();
        } else {
            self.wifi_direct_connected = false;
        }
    }
    
    /// Handle received AI image generation response
    pub fn handle_ai_image_response(&mut self, response: ImageGenerationResponse) -> Vec<InputResult> {
        // Find pending request
        if let Some(pos) = self.pending_image_requests.iter().position(|r| r.request_id == response.request_id) {
            let pending_request = self.pending_image_requests.remove(pos);
            
            if response.success {
                // Replace placeholder with actual image reference
                let replacement_text = if let Some(image_path) = response.image_path {
                    format!("[IMAGE:{}]", image_path)
                } else {
                    format!("[AI_IMAGE:{}]", response.request_id)
                };
                
                // Save the image if data is provided
                if let Some(image_data) = response.image_data {
                    let image_filename = format!("ai_generated_{}.png", response.request_id);
                    let image_path = self.images_directory.join("ai_generated").join(&image_filename);
                    
                    // Create directory if it doesn't exist
                    if let Some(parent) = image_path.parent() {
                        let _ = std::fs::create_dir_all(parent);
                    }
                    
                    // Decode and save image
                    if let Ok(decoded_data) = general_purpose::STANDARD.decode(&image_data) {
                        if std::fs::write(&image_path, decoded_data).is_ok() {
                            // Add to available images
                            self.available_image_files.push(ImageFileEntry {
                                path: image_path,
                                name: image_filename.clone(),
                                source: ImageSource::AIGenerated,
                                thumbnail_available: false,
                            });
                        }
                    }
                }
                
                vec![
                    InputResult::ReplaceText {
                        find: format!("[AI_IMAGE_GENERATING:{}]", response.request_id),
                        replace: replacement_text,
                    },
                    InputResult::StatusMessage {
                        message: format!("AI image generation completed: {}", pending_request.prompt),
                    },
                ]
            } else {
                let error_msg = response.error_message.unwrap_or_else(|| "Unknown error".to_string());
                vec![
                    InputResult::ReplaceText {
                        find: format!("[AI_IMAGE_GENERATING:{}]", response.request_id),
                        replace: format!("[AI_IMAGE_FAILED:{}]", error_msg),
                    },
                    InputResult::StatusMessage {
                        message: format!("AI image generation failed: {}", error_msg),
                    },
                ]
            }
        } else {
            vec![InputResult::StatusMessage {
                message: "Received unknown AI image response".to_string(),
            }]
        }
    }

    /// Check for auto-exit conditions and timeouts
    pub fn update(&mut self) -> Vec<InputResult> {
        let mut results = Vec::new();

        // Check for edit mode auto-exit
        if let EnhancedInputMode::EditMode = self.current_mode {
            if let Some(exit_time) = self.edit_mode_state.auto_exit_timer {
                if Instant::now() > exit_time {
                    results.push(self.exit_edit_mode());
                }
            }
        }

        // Check for long press actions
        results.extend(self.check_long_press_actions());

        results
    }

    fn check_long_press_actions(&mut self) -> Vec<InputResult> {
        let mut results = Vec::new();

        for (button_name, state) in &self.button_states {
            if state.pressed {
                if let Some(press_time) = state.press_time {
                    let duration = Instant::now().duration_since(press_time);

                    // Check for 1-second long press for special actions
                    if duration >= Duration::from_millis(1000) {
                        match button_name.as_str() {
                            "A" => {
                                // Long press A for special character mode
                                self.current_mode = EnhancedInputMode::SpecialCharacterMode;
                                results.push(InputResult::ModeChange {
                                    new_mode: self.current_mode.clone(),
                                });
                            }
                            _ => {}
                        }
                    }
                }
            }
        }

        results
    }
    
    /// Get radial menu rendering data for UI display
    pub fn get_radial_menu_render_data(&self) -> Option<RadialMenuRenderData> {
        if let EnhancedInputMode::RadialMenu { state } = &self.current_mode {
            if state.is_visible {
                return Some(state.get_render_data());
            }
        }
        None
    }

    /// Get current input mode status for UI display
    pub fn get_mode_display(&self) -> String {
        match &self.current_mode {
            EnhancedInputMode::Navigation => "Navigation".to_string(),
            EnhancedInputMode::EditMode => "Edit Mode".to_string(),
            EnhancedInputMode::OneTimeKeyboard { .. } => "Keyboard".to_string(),
            EnhancedInputMode::RadialMenu { state } => format!("Radial: {:?}", state.active_direction),
            EnhancedInputMode::SpecialCharacterMode => "Special Characters".to_string(),
            EnhancedInputMode::P2PBrowser => "P2P Browser".to_string(),
            EnhancedInputMode::CollaborationMode => "Collaboration".to_string(),
            EnhancedInputMode::DocumentSaver => "Document Saver".to_string(),
            EnhancedInputMode::ImageMenu { submenu } => {
                match submenu {
                    ImageSubmenu::Main => "Image Menu".to_string(),
                    ImageSubmenu::FileSelection { .. } => "Select Image File".to_string(),
                    ImageSubmenu::AIGeneration => "AI Image Generation".to_string(),
                }
            }
            EnhancedInputMode::AIImagePrompt { .. } => "AI Image Prompt".to_string(),
            EnhancedInputMode::SecurePairing { .. } => "Secure Pairing".to_string(),
            EnhancedInputMode::SecureDeviceSelection { .. } => "Select Device".to_string(),
            EnhancedInputMode::RelationshipManager => "Relationship Manager".to_string(),
        }
    }

    /// Draw a simple ASCII representation of the radial menu (for terminal display)
    pub fn draw_radial_menu_ascii(&self) -> String {
        if let Some(render_data) = self.get_radial_menu_render_data() {
            let mut output = String::new();
            output.push_str(&format!("\n=== Radial Menu ({:?}) ===\n", render_data.direction));
            output.push_str("       ○ (center)\n");
            output.push_str("\n");
            
            for (i, option) in render_data.options.iter().enumerate() {
                let marker = if option.selected { "►" } else { " " };
                output.push_str(&format!(
                    "{} [{}] {} - '{}'\n", 
                    marker, 
                    option.button_hint, 
                    if option.selected { "<<" } else { "  " },
                    option.character
                ));
            }
            
            output.push_str("\nPress D-pad to change direction\n");
            output.push_str("Press L1/B/A/Y to select option\n");
            output.push_str("Press SELECT to exit\n");
            output
        } else {
            String::from("Radial menu not active")
        }
    }

    /// Get cursor information for UI display
    pub fn get_cursor_info(&self) -> CursorInfo {
        CursorInfo {
            position: self.cursor_position,
            line: self.edit_mode_state.cursor_line,
            column: self.edit_mode_state.cursor_column,
            text_length: self.text_buffer.len(),
        }
    }

    /// Load a different controller configuration
    pub fn switch_controller_config(&mut self, new_config: InputConfig) {
        self.config = new_config;
        // Reset state to ensure compatibility
        self.current_mode = EnhancedInputMode::Navigation;
        self.button_states.clear();
    }
    
    /// Set radial menu center position (for different screen sizes)
    pub fn set_radial_menu_center(&mut self, x: f32, y: f32) {
        if let EnhancedInputMode::RadialMenu { state } = &mut self.current_mode {
            state.center_x = x;
            state.center_y = y;
        }
    }
    /// Handle P2P browser input
    fn handle_p2p_browser_input(&mut self, button: UniversalButton, pressed: bool) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Exit P2P browser
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // Download/open selected document
                vec![InputResult::SpecialAction {
                    action: "download_document".to_string(),
                }]
            }
            UniversalButton::X => {
                // Share current document
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    vec![self.share_current_document()]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Y => {
                // Enter collaboration mode
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    self.current_mode = EnhancedInputMode::CollaborationMode;
                    vec![InputResult::ModeChange {
                        new_mode: self.current_mode.clone(),
                    }]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Up => {
                vec![InputResult::Navigation {
                    direction: "browse_up".to_string(),
                }]
            }
            UniversalButton::Down => {
                vec![InputResult::Navigation {
                    direction: "browse_down".to_string(),
                }]
            }
            _ => vec![InputResult::NoAction],
        }
    }

    /// Handle collaboration mode input
    fn handle_collaboration_mode_input(&mut self, button: UniversalButton, pressed: bool) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Exit collaboration mode
                self.current_mode = EnhancedInputMode::Navigation;
                self.collaboration_state = None;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // Sync current changes
                vec![self.sync_collaborative_changes()]
            }
            UniversalButton::X => {
                // View participant list
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    vec![InputResult::SpecialAction {
                        action: "view_participants".to_string(),
                    }]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            _ => vec![InputResult::NoAction],
        }
    }

    /// Handle document saver input
    fn handle_document_saver_input(&mut self, button: UniversalButton, pressed: bool) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Exit document saver
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // Save document locally
                vec![self.save_document_locally()]
            }
            UniversalButton::X => {
                // Export to P2P network
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) && self.p2p_enabled {
                    vec![self.export_to_p2p()]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Y => {
                // Quick auto-save toggle
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    self.auto_save_enabled = !self.auto_save_enabled;
                    let status = if self.auto_save_enabled { "enabled" } else { "disabled" };
                    vec![InputResult::SpecialAction {
                        action: format!("auto_save_{}", status),
                    }]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            _ => vec![InputResult::NoAction],
        }
    }
}

#[derive(Debug, Clone)]
pub struct CursorInfo {
    pub position: usize,
    pub line: usize,
    pub column: usize,
    pub text_length: usize,
}

impl Default for EnhancedInputManager {
    fn default() -> Self {
        Self::new(InputConfig::default())
    }
}

/// Convenience functions for creating input managers with different configurations
impl EnhancedInputManager {
    pub fn gameboy_style() -> Self {
        Self::new(InputConfig::gameboy_default())
    }

    pub fn snes_style() -> Self {
        Self::new(InputConfig::snes_default())
    }

    pub fn from_config_file(path: &std::path::Path) -> Result<Self, Box<dyn std::error::Error>> {
        let config = InputConfig::load_from_file(path)?;
        Ok(Self::new(config))
    }

    /// Initialize P2P networking for document sharing
    pub fn enable_p2p(&mut self, device_name: String) -> Result<(), Box<dyn std::error::Error>> {
        if !self.p2p_enabled {
            let manager = P2PMeshManager::new(device_name, DeviceType::Anbernic("word_processor".to_string()))?;
            self.p2p_manager = Some(manager);
            self.p2p_enabled = true;
        }
        Ok(())
    }

    /// Disable P2P networking
    pub fn disable_p2p(&mut self) {
        self.p2p_manager = None;
        self.p2p_enabled = false;
    }

    /// Toggle P2P functionality
    pub fn toggle_p2p(&mut self) -> InputResult {
        if self.p2p_enabled {
            self.disable_p2p();
            InputResult::SpecialAction {
                action: "P2P disabled".to_string(),
            }
        } else {
            if let Err(_) = self.enable_p2p("handheld_device".to_string()) {
                InputResult::SpecialAction {
                    action: "P2P enable failed".to_string(),
                }
            } else {
                InputResult::SpecialAction {
                    action: "P2P enabled".to_string(),
                }
            }
        }
    }

    /// Share current document via P2P
    pub fn share_current_document(&mut self) -> InputResult {
        if let Some(_manager) = &mut self.p2p_manager {
            let shared_doc = SharedDocument {
                file_hash: self.calculate_document_hash(),
                filename: self.document_metadata.filename.clone(),
                content: self.text_buffer.clone(),
                author: self.document_metadata.author.clone(),
                created_time: self.document_metadata.created_time,
                last_modified: std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_secs(),
                tags: self.document_metadata.tags.clone(),
                file_size: self.text_buffer.len(),
                device_info: "handheld_word_processor".to_string(),
            };

            self.shared_documents.push(shared_doc.clone());
            
            InputResult::SpecialAction {
                action: format!("shared_document_{}", shared_doc.filename),
            }
        } else {
            InputResult::SpecialAction {
                action: "p2p_not_enabled".to_string(),
            }
        }
    }

    /// Sync collaborative changes
    pub fn sync_collaborative_changes(&mut self) -> InputResult {
        if let Some(collaboration_state) = &mut self.collaboration_state {
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs();
            
            collaboration_state.last_sync = now;
            
            let change_count = collaboration_state.pending_changes.len();
            collaboration_state.pending_changes.clear();
            
            InputResult::SpecialAction {
                action: format!("synced_{}_changes", change_count),
            }
        } else {
            InputResult::SpecialAction {
                action: "no_collaboration_session".to_string(),
            }
        }
    }

    /// Save document locally
    pub fn save_document_locally(&mut self) -> InputResult {
        self.update_document_metadata();
        
        InputResult::SpecialAction {
            action: format!("saved_{}", self.document_metadata.filename),
        }
    }

    /// Export document to P2P network
    pub fn export_to_p2p(&mut self) -> InputResult {
        if self.p2p_enabled {
            self.share_current_document()
        } else {
            InputResult::SpecialAction {
                action: "p2p_not_enabled".to_string(),
            }
        }
    }

    /// Calculate hash for current document
    pub fn calculate_document_hash(&self) -> String {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};
        
        let mut hasher = DefaultHasher::new();
        self.text_buffer.hash(&mut hasher);
        self.document_metadata.filename.hash(&mut hasher);
        format!("{:x}", hasher.finish())
    }

    /// Update document metadata
    pub fn update_document_metadata(&mut self) {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        self.document_metadata.last_modified = now;
        self.document_metadata.character_count = self.text_buffer.len();
        self.document_metadata.word_count = self.text_buffer.split_whitespace().count();
        self.document_metadata.version += 1;
    }

    /// Get P2P status information
    pub async fn get_p2p_status(&self) -> P2PStatus {
        let peer_count = if let Some(manager) = &self.p2p_manager {
            manager.get_peers().await.len()
        } else {
            0
        };
        
        P2PStatus {
            enabled: self.p2p_enabled,
            peer_count,
            shared_documents_count: self.shared_documents.len(),
            collaboration_active: self.collaboration_state.is_some(),
        }
    }

    /// Start a collaborative editing session
    pub async fn start_collaboration_session(&mut self, session_id: String) {
        let participants = if let Some(manager) = &self.p2p_manager {
            manager.get_peers().await.into_iter().map(|p| p.device_id).collect()
        } else {
            Vec::new()
        };
        
        self.collaboration_state = Some(CollaborationState {
            session_id,
            participants,
            document_hash: self.calculate_document_hash(),
            last_sync: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs(),
            pending_changes: Vec::new(),
        });
    }

    /// Add a collaborative change to the pending queue
    pub fn add_collaborative_change(&mut self, change_type: ChangeType, position: usize, content: String) {
        if let Some(collaboration_state) = &mut self.collaboration_state {
            let change = DocumentChange {
                change_id: format!("{}-{}", 
                    std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap()
                        .as_nanos(),
                    position
                ),
                author: self.document_metadata.author.clone(),
                timestamp: std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_secs(),
                change_type,
                position,
                content,
            };
            
            collaboration_state.pending_changes.push(change);
        }
    }

    /// Handle secure pairing input
    fn handle_secure_pairing_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        stage: SecurePairingStage,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Exit secure pairing
                self.current_mode = EnhancedInputMode::Navigation;
                self.pairing_mode_active = false;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // Progress through pairing stages
                match stage {
                    SecurePairingStage::Initiating => {
                        // Start pairing process
                        vec![InputResult::SpecialAction {
                            action: "start_secure_pairing".to_string(),
                        }]
                    }
                    SecurePairingStage::DeviceSelection { devices } => {
                        // Move to device selection mode
                        self.current_mode = EnhancedInputMode::SecureDeviceSelection { devices };
                        vec![InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        }]
                    }
                    _ => vec![InputResult::NoAction],
                }
            }
            _ => vec![InputResult::NoAction],
        }
    }

    /// Handle secure device selection input
    fn handle_secure_device_selection_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        devices: Vec<CryptoPairingEmoji>,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Go back to pairing mode
                self.current_mode = EnhancedInputMode::SecurePairing {
                    stage: SecurePairingStage::DeviceSelection { devices },
                };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // Select current device (simplified - would need navigation)
                if let Some(device) = devices.first() {
                    self.current_mode = EnhancedInputMode::SecurePairing {
                        stage: SecurePairingStage::NicknameEntry {
                            target_device: device.clone(),
                            partial_nickname: String::new(),
                        },
                    };
                    vec![InputResult::ModeChange {
                        new_mode: self.current_mode.clone(),
                    }]
                } else {
                    vec![InputResult::StatusMessage {
                        message: "No devices available".to_string(),
                    }]
                }
            }
            _ => vec![InputResult::NoAction],
        }
    }

    /// Handle relationship manager input
    fn handle_relationship_manager_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Exit relationship manager
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // View relationship details
                vec![InputResult::SpecialAction {
                    action: "view_relationship_details".to_string(),
                }]
            }
            UniversalButton::X => {
                // Start new pairing (if SNES controller)
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    self.current_mode = EnhancedInputMode::SecurePairing {
                        stage: SecurePairingStage::Initiating,
                    };
                    vec![InputResult::ModeChange {
                        new_mode: self.current_mode.clone(),
                    }]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            _ => vec![InputResult::NoAction],
        }
    }
}

impl std::fmt::Debug for EnhancedInputManager {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("EnhancedInputManager")
            .field("config", &self.config)
            .field("current_mode", &self.current_mode)
            .field("text_buffer", &self.text_buffer)
            .field("cursor_position", &self.cursor_position)
            .field("edit_mode_state", &self.edit_mode_state)
            .field("one_time_keyboard_state", &self.one_time_keyboard_state)
            .field("button_states", &self.button_states)
            .field("last_input_time", &self.last_input_time)
            .field("p2p_enabled", &self.p2p_enabled)
            .field("shared_documents", &self.shared_documents)
            .field("auto_save_enabled", &self.auto_save_enabled)
            .field("document_metadata", &self.document_metadata)
            .field("collaboration_state", &self.collaboration_state)
            .field("p2p_manager", &"<P2PMeshManager>")
            .finish()
    }
}

/// P2P status information for UI display
#[derive(Debug, Clone)]
pub struct P2PStatus {
    pub enabled: bool,
    pub peer_count: usize,
    pub shared_documents_count: usize,
    pub collaboration_active: bool,
}

/// Implement P2P integration trait for enhanced input manager
impl P2PIntegration for EnhancedInputManager {
    fn get_p2p_manager(&self) -> &P2PMeshManager {
        self.p2p_manager.as_ref().expect("P2P manager not initialized")
    }

    async fn share_file(&self, file_path: std::path::PathBuf) -> Result<String, Box<dyn std::error::Error>> {
        self.get_p2p_manager()
            .share_file(file_path, None, vec!["document".to_string(), "handheld".to_string()])
            .await
    }

    async fn search_shared_files(
        &self,
        query: String,
    ) -> Result<Vec<SharedFile>, Box<dyn std::error::Error>> {
        self.get_p2p_manager().search_files(query, vec!["document".to_string()]).await
    }

    async fn get_mesh_peers(&self) -> Vec<PeerDevice> {
        self.get_p2p_manager().get_peers().await
    }
}

```
<!-- }}} -->

<!-- {{{ .cargo/config.toml - Complete Context -->
### 📄 .cargo/config.toml

**File Metadata:**
- Size: 569 bytes
- Lines: 23
- Modified: 2025-09-23 08:44:11.660047997 -0700
- Language: 

**File Content:**

```
# Cargo configuration for Handheld Office
[build]
# Move target directory to files/ to keep build artifacts organized
target-dir = "files/target"

# Cross-compilation targets for Anbernic devices
[target.armv7-unknown-linux-gnueabihf]
linker = "arm-linux-gnueabihf-gcc"

[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"

# Optimize for handheld device builds
[profile.release]
opt-level = 3
lto = true
codegen-units = 1
panic = "abort"

# Development builds optimized for faster compilation
[profile.dev]
opt-level = 0
debug = true
incremental = true
```
<!-- }}} -->

<!-- {{{ src/crypto.rs - Complete Context -->
### 📄 src/crypto.rs

**File Metadata:**
- Size: 12442 bytes
- Lines: 368
- Modified: 2025-09-22 23:50:51.472864670 -0700
- Language: 

**File Content:**

```
/// Cryptographic operations for OfficeOS
/// Implements relationship-based encryption using modern cryptographic primitives (Ed25519, X25519, ChaCha20-Poly1305)
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};
use thiserror::Error;
use base64::Engine;

pub mod keypair;
pub mod relationship;
pub mod storage;
pub mod pairing;
pub mod packet;
pub mod p2p_integration;
pub mod migration_adapter;
pub mod bytecode;
pub mod bytecode_executor;
pub mod types;

pub use keypair::*;
pub use relationship::*;
pub use storage::*;
pub use pairing::*;
pub use packet::*;
pub use p2p_integration::*;
pub use migration_adapter::*;
pub use bytecode::*;
pub use bytecode_executor::*;
pub use types::*;

/// Main cryptographic manager for OfficeOS
pub struct CryptoManager {
    /// Our device's master keypair
    device_keypair: DeviceKeypair,
    /// Storage for relationship-specific keys
    key_storage: KeyStorage,
    /// Active relationships with other devices
    relationships: HashMap<RelationshipId, RelationshipContext>,
    /// Pairing session manager
    pairing_manager: PairingManager,
    /// Configuration
    config: CryptoConfig,
}

/// Configuration for cryptographic operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CryptoConfig {
    /// Directory for storing encrypted key files
    pub key_storage_dir: PathBuf,
    /// How long to remember relationships without contact (seconds)
    pub relationship_timeout: u64,
    /// Whether to use hardware security features if available
    pub use_hardware_security: bool,
    /// Encryption algorithm preferences
    pub cipher_preferences: Vec<CipherSuite>,
}

/// Supported cipher suites
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum CipherSuite {
    /// ChaCha20-Poly1305 (recommended for embedded devices)
    ChaCha20Poly1305,
    /// AES-256-GCM (when hardware acceleration available)
    Aes256Gcm,
    /// Ed25519 for signing
    Ed25519,
}

// RelationshipId is now defined in types.rs

/// Context for a specific relationship
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RelationshipContext {
    /// Unique identifier for this relationship
    pub id: RelationshipId,
    /// User-assigned nickname for the other device
    pub nickname: String,
    /// Keypair specific to this relationship
    pub keypair: RelationshipKeypair,
    /// Other device's public key for this relationship
    pub peer_public_key: PublicKey,
    /// When this relationship was established
    pub created_at: u64,
    /// Last time we communicated with this device
    pub last_contact: u64,
    /// Whether this relationship should be forgotten after timeout
    pub auto_forget: bool,
}

/// Error types for cryptographic operations
#[derive(Error, Debug)]
pub enum CryptoError {
    #[error("Key generation failed: {0}")]
    KeyGeneration(String),
    #[error("Encryption failed: {0}")]
    Encryption(String),
    #[error("Decryption failed: {0}")]
    Decryption(String),
    #[error("Invalid key format: {0}")]
    InvalidKey(String),
    #[error("Relationship not found: {0}")]
    RelationshipNotFound(String),
    #[error("Storage error: {0}")]
    Storage(String),
    #[error("Pairing failed: {0}")]
    Pairing(String),
    #[error("Signature verification failed")]
    SignatureVerification,
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

pub type CryptoResult<T> = Result<T, CryptoError>;

impl Default for CryptoConfig {
    fn default() -> Self {
        Self {
            key_storage_dir: PathBuf::from("./keys"),
            relationship_timeout: 30 * 24 * 60 * 60, // 30 days
            use_hardware_security: true,
            cipher_preferences: vec![
                CipherSuite::ChaCha20Poly1305,
                CipherSuite::Ed25519,
                CipherSuite::Aes256Gcm,
            ],
        }
    }
}

impl CryptoManager {
    /// Create a new crypto manager with default configuration
    pub fn new() -> CryptoResult<Self> {
        Self::with_config(CryptoConfig::default())
    }

    /// Create a new crypto manager with specific configuration
    pub fn with_config(config: CryptoConfig) -> CryptoResult<Self> {
        // Generate or load device master keypair
        let device_keypair = DeviceKeypair::generate_or_load(&config.key_storage_dir)?;
        
        // Initialize key storage
        let key_storage = KeyStorage::new(&config.key_storage_dir)?;
        
        // Initialize pairing manager
        let pairing_manager = PairingManager::new(device_keypair.public_key.clone());

        Ok(Self {
            device_keypair,
            key_storage,
            relationships: HashMap::new(),
            pairing_manager,
            config,
        })
    }

    /// Get our device's public key for pairing
    pub fn get_device_public_key(&self) -> &PublicKey {
        &self.device_keypair.public_key
    }

    /// Start pairing mode and return our emoji
    pub fn enter_pairing_mode(&mut self) -> CryptoResult<PairingEmoji> {
        self.pairing_manager.enter_pairing_mode()
    }

    /// Get list of devices currently in pairing mode
    pub fn get_discovered_devices(&mut self) -> Vec<PairingEmoji> {
        self.pairing_manager.get_discovered_devices()
    }

    /// Establish a new relationship with a device
    pub fn establish_relationship(
        &mut self,
        peer_emoji: PairingEmoji,
        nickname: String,
    ) -> CryptoResult<RelationshipId> {
        // Complete pairing process to get peer's public key
        let peer_public_key = self.pairing_manager.complete_pairing(&peer_emoji)?;
        
        // Generate relationship-specific keypair
        let relationship_keypair = RelationshipKeypair::generate()?;
        
        // Create relationship ID from both public keys
        let relationship_id = RelationshipId::from_keys(
            &self.device_keypair.public_key,
            &peer_public_key,
        );
        
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
            
        let context = RelationshipContext {
            id: relationship_id.clone(),
            nickname,
            keypair: relationship_keypair,
            peer_public_key,
            created_at: now,
            last_contact: now,
            auto_forget: true, // Default to auto-forget as per vision
        };
        
        // Store relationship
        self.key_storage.store_relationship(&context)?;
        self.relationships.insert(relationship_id.clone(), context);
        
        Ok(relationship_id)
    }

    /// Encrypt data for a specific relationship
    pub fn encrypt_for_relationship(
        &self,
        relationship_id: &RelationshipId,
        data: &[u8],
    ) -> CryptoResult<EncryptedPacket> {
        let relationship = self.relationships.get(relationship_id)
            .ok_or_else(|| CryptoError::RelationshipNotFound(relationship_id.0.clone()))?;
            
        // Create encrypted packet with relationship public key in header
        EncryptedPacket::create(
            data,
            &relationship.keypair.private_key,
            &relationship.peer_public_key,
            &relationship.keypair.public_key,
        )
    }

    /// Decrypt data using the appropriate relationship key
    pub fn decrypt_packet(&self, packet: &EncryptedPacket) -> CryptoResult<Vec<u8>> {
        // Find relationship by the public key in packet header
        for (_, relationship) in &self.relationships {
            if relationship.keypair.public_key == packet.intended_recipient_key {
                return packet.decrypt(&relationship.keypair.private_key);
            }
        }
        
        Err(CryptoError::RelationshipNotFound(
            "No matching relationship for packet".to_string()
        ))
    }

    /// Update last contact time for a relationship
    pub fn update_last_contact(&mut self, relationship_id: &RelationshipId) {
        if let Some(relationship) = self.relationships.get_mut(relationship_id) {
            relationship.last_contact = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs();
        }
    }

    /// Clean up expired relationships
    pub fn cleanup_expired_relationships(&mut self) -> CryptoResult<usize> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
            
        let mut expired = Vec::new();
        
        for (id, relationship) in &self.relationships {
            if relationship.auto_forget && 
               (now - relationship.last_contact) > self.config.relationship_timeout {
                expired.push(id.clone());
            }
        }
        
        let count = expired.len();
        for id in expired {
            self.relationships.remove(&id);
            self.key_storage.remove_relationship(&id)?;
        }
        
        Ok(count)
    }

    /// Load all stored relationships
    pub fn load_relationships(&mut self) -> CryptoResult<()> {
        let relationships = self.key_storage.load_all_relationships()?;
        for relationship in relationships {
            self.relationships.insert(relationship.id.clone(), relationship);
        }
        Ok(())
    }

    /// Get list of active relationships
    pub fn get_relationships(&self) -> Vec<&RelationshipContext> {
        self.relationships.values().collect()
    }

    /// Export relationship for backup (encrypted with device key)
    pub fn export_relationship(&self, relationship_id: &RelationshipId) -> CryptoResult<String> {
        let relationship = self.relationships.get(relationship_id)
            .ok_or_else(|| CryptoError::RelationshipNotFound(relationship_id.0.clone()))?;
            
        // Serialize and encrypt with device master key
        let serialized = serde_json::to_vec(relationship)
            .map_err(|e| CryptoError::Storage(e.to_string()))?;
            
        let encrypted = self.device_keypair.encrypt(&serialized)?;
        Ok(base64::engine::general_purpose::STANDARD.encode(encrypted))
    }

    /// Import relationship from backup
    pub fn import_relationship(&mut self, encrypted_data: &str) -> CryptoResult<RelationshipId> {
        let encrypted = base64::engine::general_purpose::STANDARD.decode(encrypted_data)
            .map_err(|e| CryptoError::InvalidKey(e.to_string()))?;
            
        let decrypted = self.device_keypair.decrypt(&encrypted)?;
        let relationship: RelationshipContext = serde_json::from_slice(&decrypted)
            .map_err(|e| CryptoError::Storage(e.to_string()))?;
            
        let id = relationship.id.clone();
        self.key_storage.store_relationship(&relationship)?;
        self.relationships.insert(id.clone(), relationship);
        
        Ok(id)
    }
}

impl RelationshipId {
    /// Generate a relationship ID from two public keys
    pub fn from_keys(key1: &PublicKey, key2: &PublicKey) -> Self {
        use sha2::{Digest, Sha256};
        
        // Sort keys to ensure consistent ID regardless of order
        let mut keys = vec![key1.as_bytes(), key2.as_bytes()];
        keys.sort();
        
        let mut hasher = Sha256::new();
        for key in keys {
            hasher.update(key);
        }
        
        let hash = hasher.finalize();
        Self(hex::encode(&hash[..16])) // Use first 16 bytes as relationship ID
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_crypto_manager_creation() {
        let temp_dir = TempDir::new().unwrap();
        let config = CryptoConfig {
            key_storage_dir: temp_dir.path().to_path_buf(),
            ..Default::default()
        };
        
        let manager = CryptoManager::with_config(config).unwrap();
        assert!(!manager.get_device_public_key().as_bytes().is_empty());
    }

    #[test]
    fn test_relationship_id_consistency() {
        let keypair1 = RelationshipKeypair::generate().unwrap();
        let keypair2 = RelationshipKeypair::generate().unwrap();
        
        let id1 = RelationshipId::from_keys(&keypair1.public_key, &keypair2.public_key);
        let id2 = RelationshipId::from_keys(&keypair2.public_key, &keypair1.public_key);
        
        assert_eq!(id1, id2);
    }
}
```
<!-- }}} -->

<!-- {{{ docs/README.md - Complete Context -->
### 📄 docs/README.md

**File Metadata:**
- Size: 5780 bytes
- Lines: 126
- Modified: 2025-09-23 10:17:42.218604318 -0700
- Language: 

**File Content:**

```
# OfficeOS Documentation Index

## Overview

This documentation is organized by **concern separation** - each document focuses on a specific aspect of the system without mixing unrelated topics. This approach reduces cognitive load and makes information easier to find and understand.

## 📚 **Core System Documentation**

### Input System (Modular Architecture)
- **[Core Input System](input/input-core-system.md)** - Fundamental text entry and navigation
- **[P2P Integration](input/input-p2p-integration.md)** - Collaborative editing and document sharing  
- **[AI Integration](input/input-ai-integration.md)** - AI-assisted text and image generation
- **[Crypto Integration](input/input-crypto-integration.md)** - Secure pairing and encrypted communications

### Networking & Security
- **[Data Flow Architecture](data-flow-architecture.md)** - Complete system data flow (Anbernic → WiFi Direct → Bytecode → Laptop Daemon → HTTP)
- **[Cryptographic Architecture](networking/cryptographic-architecture.md)** - Modern crypto system (Ed25519, ChaCha20-Poly1305)
- **[P2P Mesh System](networking/p2p-mesh-system.md)** - Peer-to-peer file sharing and collaboration
- **[Networking Architecture](networking/architecture.md)** - Overall network design

### Hardware & Deployment  
- **[Anbernic Technical Architecture](hardware/anbernic-technical-architecture.md)** - Hardware-specific optimizations
- **[Tech Deployment Pipeline](hardware/tech-deployment-pipeline.md)** - Build and deployment processes

## 🎮 **Application Documentation**

### Game Engines & Demos
- **[AzerothCore Technical Architecture](games/azerothcore-technical-architecture.md)** - MMO game engine
- **[AzerothCore Setup Guide](games/azerothcore-setup-guide.md)** - Installation and configuration

### Specialized Features
- **[AI Image Keyboard](ai/ai-image-keyboard.md)** - AI-powered image generation interface
- **[Custom Linux Distro Development](hardware/custom-linux-distro-development-checklist.md)** - OfficeOS distribution

## 🔧 **Quick References**

### Developer Guides
- **[Input Quick Reference](input/input-quick-reference.md)** - Button layouts and commands
- **[P2P Quick Reference](networking/p2p-quick-reference.md)** - Network integration examples
- **[P2P Developer Guide](networking/p2p-developer-guide.md)** - Integration patterns

### Implementation Status
- **[Implementation Status](implementation-status.md)** - Current completion status
- **[Portmaster Keyboard Test](../examples/portmaster/keyboard-test/README.md)** - Radial input testing

## 📋 **Documentation Principles**

### ✅ **Good Documentation Design (Applied Here)**
- **Single Responsibility**: Each document covers one major concern
- **Clear Dependencies**: Explicit references to required knowledge
- **Minimal Cross-References**: Related docs linked, not embedded
- **Scannable Structure**: Collapsible sections, clear headers
- **Focused Content**: No mixing of input docs with AI or P2P details

### ❌ **Problems We Fixed** 
- **Mixed Concerns**: Input docs previously contained AI image generation details
- **Cognitive Overload**: Single large docs covering multiple unrelated topics
- **Cross-Dependencies**: Circular references between documents
- **Code Artifacts Noise**: Long function definitions interrupting flow

### 🎯 **Content Organization Strategy**

#### **Core + Extensions Pattern**
1. **Core System**: Self-contained basic functionality
2. **Integration Modules**: How core integrates with external systems
3. **Application Examples**: Real-world usage patterns
4. **Reference Materials**: Quick lookup information

#### **Dependency Flow**
```
Core Input System (no dependencies)
├── P2P Integration (+ networking)
├── AI Integration (+ AI services)  
├── Crypto Integration (+ security)
└── Application Examples (+ all above)
```

## 🔍 **Finding Information**

### **By User Type**
- **New Developers**: Start with core system docs, then integrations
- **Feature Implementers**: Focus on specific integration docs
- **System Architects**: Review architecture docs and implementation status
- **Testers**: Use quick references and test applications

### **By Use Case**
- **Text Input**: `input/input-core-system.md` → `input/input-quick-reference.md`
- **Collaborative Editing**: `input/input-p2p-integration.md` → `networking/p2p-mesh-system.md`
- **AI Features**: `input/input-ai-integration.md` → `ai/ai-image-keyboard.md`
- **Security**: `input/input-crypto-integration.md` → `networking/cryptographic-architecture.md`
- **Hardware Integration**: `hardware/anbernic-technical-architecture.md`

### **Code Integration Examples**
```rust
// Core input only
use handheld_office::{EnhancedInputManager};
let input = EnhancedInputManager::gameboy_style();

// + P2P features  
input.enable_p2p_collaboration("device_name")?;

// + AI features
input.enable_ai_assistance(AIModel::Local)?;

// + Crypto features
input.enter_secure_pairing_mode()?;
```

## ⚡ **Performance & Accessibility**

### **Scannable Design**
- **Collapsible Sections**: Hide code details until needed
- **Clear Hierarchies**: Logical information organization
- **Minimal Noise**: Code artifacts in foldable sections
- **Direct Answers**: Key information easily findable

### **Maintenance Benefits**
- **Independent Updates**: Change one integration without affecting others
- **Clear Ownership**: Each doc has obvious maintainer
- **Reduced Conflicts**: Parallel development on different concerns
- **Better Testing**: Isolated documentation enables focused validation

---

**Documentation Structure**: Concern-separated, dependency-explicit  
**Last Restructured**: 2025-01-27 (claude-next-7)  
**Maintenance**: Each integration doc maintained independently
```
<!-- }}} -->

<!-- {{{ issues/README.md - Complete Context -->
### 📄 issues/README.md

**File Metadata:**
- Size: 5053 bytes
- Lines: 96
- Modified: 2025-09-23 10:10:14.218559896 -0700
- Language: 

**File Content:**

```
# Issues Tracking - Active Issues

This directory contains the issue tracking system for the Handheld Office project. 

## 📁 **Issue Documentation Structure**

- **README.md** (this file): Overview and active/pending issues
- **[TASKS.md](TASKS.md)**: Unified task list with dependencies and critical path planning
- **[COMPLETED.md](COMPLETED.md)**: All resolved issues and achievements  
- **[CLAUDE.md](CLAUDE.md)**: Issue workflow and resolution process
- **[COMPLIANCE-VALIDATION-REPORT.md](COMPLIANCE-VALIDATION-REPORT.md)**: System compliance audit (2025-09-23)
- **Individual Issue Files**: Detailed descriptions and resolution status
- **done/**: Resolved issues archive

## 📊 **Current Status Overview**

**Last Updated**: 2025-09-23  
**Total Active Issues**: 7  
**Critical Documentation**: 4 (architecture compliance violations)  
**High Priority Code**: 3 (implementation work)  
**Medium Priority Features**: 3 (documentation and features)  
**Partially Resolved**: 4 (core architecture addressed, integration needed)

⚠️ **COMPLIANCE ALERT**: System audit revealed significant discrepancies between claimed and actual implementation status. See [COMPLIANCE-VALIDATION-REPORT.md](COMPLIANCE-VALIDATION-REPORT.md) for details. Documentation accuracy restoration required before continuing development.

## 🎯 **Development Foundation Status**

### ✅ **Major Achievements Completed**
- **Compilation Blockers**: All 5 critical issues resolved ✅
- **Crypto Architecture**: 3,500+ lines of secure P2P system ✅  
- **Testing Infrastructure**: Standardized documentation ✅
- **Build System**: Optimized for handheld devices ✅

*See [COMPLETED.md](COMPLETED.md) for detailed achievement history*

## 🚨 **Active Issues by Priority**

### 🚨 **CRITICAL** (Architecture Documentation Violations)
- **#015**: Networking Architecture Documentation Compliance Violations
- **#016**: Daemon TCP Server Architecture Mismatch ⚠️ *Partially Resolved*
- **#017**: MMO Engine Networking Architecture Violations  
- **#018**: Code Comments and Strings Networking Violations
- **#024**: Compilation Errors Master Tracking Issue (significantly improved)

### ⚠️ **HIGH PRIORITY** (Code Implementation Issues)
- **#007**: External API Violations in AI Services ⚠️ *Partially Resolved*
- **#008**: External LLM API Violations ⚠️ *Partially Resolved*
- **#013**: P2P-Only Compliance Violations ⚠️ *Partially Resolved*

### 📋 **MEDIUM PRIORITY** (Feature Implementation)
- **#004**: AzerothCore Setup Guide Inconsistencies
- **#014**: Radial Keyboard Implementation Incomplete

## 🔥 **Critical Issues Requiring Immediate Attention**

### **Architecture Documentation Compliance**
**Issues #015-#018** represent critical violations of ARCHITECTURE.md air-gapped standard:

- **Impact**: Documentation contradicts core security architecture
- **Risk**: Developer confusion, incorrect implementations  
- **Action**: Major documentation rewrite for air-gapped P2P compliance
- **Timeline**: Must be completed for consistent architecture messaging

### **Bytecode Interface Integration**
**Issues #007, #008, #013, #016** have core architecture addressed but need integration:

- **Status**: Bytecode interface implemented, laptop daemon proxy architecture created
- **Remaining work**: Integrate with existing services, remove external HTTP calls from Anbernic devices
- **Action**: Connect bytecode system to ai_image_service.rs and desktop_llm.rs
- **Timeline**: Integration work to complete partial resolutions

## 📋 **Quick Reference Summary**

### **Immediate Action Required**
1. **#015-#018**: Architecture documentation compliance (CRITICAL for consistency)
2. **#007, #008, #013, #016**: Complete bytecode interface integration work
3. **#004, #014**: Feature implementation and documentation overhaul

### **Partially Resolved Issues** (Core Architecture Complete)
- **#007**: AI Service API Violations - Bytecode interface ready, needs integration
- **#008**: LLM API Violations - Laptop daemon proxy complete, needs integration  
- **#013**: P2P Compliance Violations - Architecture addressed, external calls need removal
- **#016**: Daemon TCP Mismatch - Proxy architecture implemented, needs configuration

### **Development Workflow**
For detailed planning, issue descriptions, and workflow processes:
- **[TASKS.md](TASKS.md)**: Strategic planning, dependencies, and critical path
- **Individual Issue Files**: `###-issue-name.md` for complete details
- **[CLAUDE.md](CLAUDE.md)**: Issue workflow and resolution process
- **[COMPLETED.md](COMPLETED.md)**: Achievement history and resolved issues

### **Estimated Timeline**
- **Documentation compliance**: 3-5 days (major rewrites needed)
- **Integration work**: 2-3 days (connect bytecode to existing services)
- **Feature completion**: 1-2 weeks (radial keyboard, setup docs)

**Current Priority**: Complete documentation compliance (#015-#018) and bytecode integration (#007, #008, #013, #016) to establish consistent architecture foundation.
```
<!-- }}} -->

<!-- {{{ src/desktop_llm.rs - Complete Context -->
### 📄 src/desktop_llm.rs

**File Metadata:**
- Size: 10071 bytes
- Lines: 292
- Modified: 2025-11-12 19:39:34.534796797 -0800
- Language: 

**File Content:**

```
/// Desktop LLM Service - LAPTOP DAEMON COMPONENT
/// 
/// **DEPLOYMENT CONTEXT**: This service runs on laptop daemons as a secure proxy
/// **EXTERNAL ACCESS**: HTTP calls to LLM services are PERMITTED and CORRECT here
/// **COMMUNICATION**: Receives encrypted bytecode instructions from Anbernic devices via WiFi Direct P2P
/// 
/// ARCHITECTURE FLOW:
/// Anbernic Device → WiFi Direct P2P → Encrypted Bytecode → Laptop Daemon → HTTP API → External LLM Service
/// External LLM Service → HTTP Response → Laptop Daemon → Encrypted Bytecode → WiFi Direct P2P → Anbernic Device

use log::{error, info};
use serde::{Deserialize, Serialize};
use std::process::Stdio;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::process::Command;
use async_trait::async_trait;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LlmRequest {
    pub id: String,
    pub sender: String,
    pub prompt: String,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LlmResponse {
    pub id: String,
    pub request_id: String,
    pub response: String,
    pub timestamp: u64,
    pub model_used: String,
}

pub struct DesktopLlmService {
    pub daemon_connection: Option<TcpStream>,
    pub service_id: String,
    pub llm_model_path: Option<String>,
}

impl DesktopLlmService {
    pub fn new() -> Self {
        Self {
            daemon_connection: None,
            service_id: format!("desktop_llm_{}", std::process::id()),
            llm_model_path: None,
        }
    }

    pub async fn connect_to_daemon(
        &mut self,
        daemon_addr: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let stream = TcpStream::connect(daemon_addr).await?;
        self.daemon_connection = Some(stream);
        info!("LLM service connected to daemon at {}", daemon_addr);
        Ok(())
    }

    pub async fn start_listening(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let mut buffer = vec![0; 4096];

        loop {
            let stream = match &mut self.daemon_connection {
                Some(stream) => stream,
                None => break,
            };

            match stream.read(&mut buffer).await {
                Ok(0) => break, // Connection closed
                Ok(n) => {
                    let data = &buffer[..n];
                    if let Ok(message) = serde_json::from_slice::<serde_json::Value>(data) {
                        if message["message_type"] == "LlmRequest" {
                            // Extract data from message first to avoid borrow issues
                            let prompt = message["content"].as_str().unwrap_or("").to_string();
                            let request_id = message["id"].as_str().unwrap_or("").to_string();
                            let sender = message["sender"].as_str().unwrap_or("").to_string();

                            info!("Processing LLM request from {}: {}", sender, prompt);

                            // Process in a separate scope to avoid borrow conflicts
                            let response = self.process_llm_request(&prompt).await?;
                            self.send_llm_response(&request_id, &response).await?;
                        }
                    }
                }
                Err(e) => {
                    error!("Read error: {}", e);
                    break;
                }
            }
        }

        Ok(())
    }

    async fn process_llm_request(
        &self,
        prompt: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        // Try different LLM backends in order of preference
        self.try_llm_backends(prompt).await
    }

    async fn send_llm_response(
        &mut self,
        request_id: &str,
        response: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        self.send_response(request_id, response).await
    }

    async fn try_llm_backends(&self, prompt: &str) -> Result<String, Box<dyn std::error::Error>> {
        // Try ollama first (most common local LLM setup)
        if let Ok(response) = self.try_ollama(prompt).await {
            return Ok(response);
        }

        // Try llamacpp
        if let Ok(response) = self.try_llamacpp(prompt).await {
            return Ok(response);
        }

        // Try koboldcpp
        if let Ok(response) = self.try_koboldcpp(prompt).await {
            return Ok(response);
        }

        // Fallback to simple echo service for testing
        Ok(format!("Echo response: {}", prompt))
    }

    async fn try_ollama(&self, prompt: &str) -> Result<String, Box<dyn std::error::Error>> {
        let output = Command::new("ollama")
            .arg("run")
            .arg("llama2") // Default model, could be configurable
            .arg(prompt)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
            .await?;

        if output.status.success() {
            Ok(String::from_utf8_lossy(&output.stdout).to_string())
        } else {
            Err("Ollama failed".into())
        }
    }

    async fn try_llamacpp(&self, prompt: &str) -> Result<String, Box<dyn std::error::Error>> {
        // LAPTOP DAEMON INTERNET ACCESS: Restored for off-site compute proxying
        // Anbernic devices remain air-gapped - they only communicate via P2P bytecode
        // Laptop daemon acts as secure proxy for internet-based LLM services
        
        let client = reqwest::Client::new();
        let response = client
            .post("http://localhost:8000/v1/completions")
            .json(&serde_json::json!({
                "prompt": prompt,
                "max_tokens": 256,
                "temperature": 0.7
            }))
            .send()
            .await?;

        if response.status().is_success() {
            let json: serde_json::Value = response.json().await?;
            if let Some(choices) = json["choices"].as_array() {
                if let Some(first_choice) = choices.first() {
                    if let Some(text) = first_choice["text"].as_str() {
                        return Ok(text.to_string());
                    }
                }
            }
        }

        Err("LlamaCPP failed".into())
    }

    async fn try_koboldcpp(&self, prompt: &str) -> Result<String, Box<dyn std::error::Error>> {
        // LAPTOP DAEMON INTERNET ACCESS: Restored for off-site compute proxying
        // Anbernic devices remain air-gapped - they only communicate via P2P bytecode
        // Laptop daemon acts as secure proxy for internet-based LLM services
        
        let client = reqwest::Client::new();
        let response = client
            .post("http://localhost:5001/api/v1/generate")
            .json(&serde_json::json!({
                "prompt": prompt,
                "max_length": 256,
                "temperature": 0.7
            }))
            .send()
            .await?;

        if response.status().is_success() {
            let json: serde_json::Value = response.json().await?;
            if let Some(results) = json["results"].as_array() {
                if let Some(first_result) = results.first() {
                    if let Some(text) = first_result["text"].as_str() {
                        return Ok(text.to_string());
                    }
                }
            }
        }

        Err("KoboldCPP failed".into())
    }

    async fn send_response(
        &mut self,
        request_id: &str,
        response: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(ref mut stream) = self.daemon_connection {
            let message = serde_json::json!({
                "id": format!("{}_response_{}", self.service_id, chrono::Utc::now().timestamp()),
                "request_id": request_id,
                "sender": self.service_id,
                "content": response,
                "timestamp": chrono::Utc::now().timestamp() as u64,
                "message_type": "LlmResponse",
                "model_used": "local_llm"
            });

            let serialized = serde_json::to_vec(&message)?;
            stream.write_all(&serialized).await?;
        }

        Ok(())
    }
}

/// Implementation of LocalLLMProvider trait for bytecode integration
#[async_trait]
impl crate::crypto::bytecode_executor::LocalLLMProvider for DesktopLlmService {
    /// Process LLM query using external HTTP APIs (laptop daemon context)
    async fn process_query(&self, prompt: &str, model: Option<&str>) -> Result<String, String> {
        // Use the existing try_koboldcpp method for external API calls
        // This is correct for laptop daemon deployment
        
        // Try KoboldCPP first (most reliable local setup)
        if let Ok(response) = self.try_koboldcpp(prompt).await {
            return Ok(response);
        }
        
        // Try Llama CPP as fallback
        if let Ok(response) = self.try_llama_cpp(prompt).await {
            return Ok(response);
        }
        
        // If all external endpoints fail, return error
        Err("No LLM endpoints available".to_string())
    }
    
    /// Get list of available LLM models
    fn get_available_models(&self) -> Vec<String> {
        vec![
            "koboldcpp-local".to_string(),
            "llama-cpp-python".to_string(),
            "local-llm".to_string(),
        ]
    }
    
    /// Check if LLM service is available
    fn is_available(&self) -> bool {
        // For laptop daemon, always available (external APIs handle the actual availability)
        true
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();

    let mut llm_service = DesktopLlmService::new();

    // Connect to daemon
    if let Err(e) = llm_service.connect_to_daemon("127.0.0.1:8080").await {
        error!("Failed to connect to daemon: {}", e);
        return Ok(());
    }

    info!("Desktop LLM service starting...");

    // Start listening for LLM requests
    llm_service.start_listening().await?;

    Ok(())
}

```
<!-- }}} -->

<!-- {{{ src/terminal.rs - Complete Context -->
### 📄 src/terminal.rs

**File Metadata:**
- Size: 51049 bytes
- Lines: 1252
- Modified: 2025-09-21 19:19:46.208457769 -0700
- Language: 

**File Content:**

```
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use std::process::{Command, Stdio};

/// Radial menu-based terminal emulator for Anbernic devices
/// Provides filesystem navigation and interactive bash command configuration
#[derive(Debug, Clone)]
pub struct AnbernicTerminal {
    pub current_directory: PathBuf,
    pub command_history: Vec<CommandEntry>,
    pub filesystem_cache: FilesystemCache,
    pub input_state: TerminalInputState,
    pub ui_state: TerminalUIState,
    pub command_builder: CommandBuilder,
    pub radial_keyboard: RadialKeyboard,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandEntry {
    pub command: String,
    pub working_directory: PathBuf,
    pub timestamp: DateTime<Utc>,
    pub exit_code: Option<i32>,
    pub output: String,
    pub error: String,
}

#[derive(Debug, Clone)]
pub struct FilesystemCache {
    pub current_entries: Vec<FilesystemEntry>,
    pub parent_directory: Option<PathBuf>,
    pub last_updated: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FilesystemEntry {
    pub name: String,
    pub path: PathBuf,
    pub entry_type: EntryType,
    pub size: Option<u64>,
    pub permissions: String,
    pub modified: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EntryType {
    Directory,
    File,
    SymLink,
    Executable,
    Hidden,
}

/// Radial menu input system for terminal navigation
#[derive(Debug, Clone)]
pub struct TerminalInputState {
    pub current_group: InputGroup,
    pub selected_index: usize,
    pub text_buffer: String,
    pub cursor_position: usize,
    pub input_mode: InputMode,
    pub command_cursor: usize,
}

#[derive(Debug, Clone)]
pub enum InputGroup {
    MainMenu,          // Navigate, Command, History, Settings
    FilesystemBrowser, // Directory navigation
    CommandBuilder,    // Build bash commands
    ParameterEntry,    // Enter command parameters
    FlagSelection,     // Select command flags
    History,           // Command history
    Settings,          // Terminal settings
}

#[derive(Debug, Clone)]
pub enum InputMode {
    Navigation,    // A/B navigate, L/R select
    TextEntry,     // Radial keyboard input
    TextEditMode,  // Enhanced edit mode with cursor navigation
    RadialMenu,    // Circular menu selection
    FileExplorer,  // Filesystem navigation
    CommandConfig, // Interactive command configuration
}

/// Game Boy style UI state for terminal
#[derive(Debug, Clone)]
pub struct TerminalUIState {
    pub current_view: TerminalView,
    pub selected_file_index: usize,
    pub scroll_offset: usize,
    pub show_help: bool,
    pub animation_frame: u32,
    pub show_hidden_files: bool,
    pub terminal_width: usize,
    pub terminal_height: usize,
}

#[derive(Debug, Clone)]
pub enum TerminalView {
    MainMenu,
    FilesystemBrowser,
    CommandBuilder,
    CommandOutput,
    History,
    Settings,
}

/// Interactive bash command builder with radial menu flag selection
#[derive(Debug, Clone)]
pub struct CommandBuilder {
    pub base_command: String,
    pub selected_flags: Vec<CommandFlag>,
    pub parameters: HashMap<String, String>,
    pub available_commands: HashMap<String, CommandTemplate>,
    pub build_state: BuildState,
}

#[derive(Debug, Clone)]
pub enum BuildState {
    SelectingCommand,
    SelectingFlags,
    EnteringParameters,
    ReviewingCommand,
    Ready,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandTemplate {
    pub name: String,
    pub description: String,
    pub common_flags: Vec<CommandFlag>,
    pub requires_path: bool,
    pub example_usage: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandFlag {
    pub short: Option<String>, // -l
    pub long: Option<String>,  // --list
    pub description: String,
    pub takes_value: bool,
    pub value_type: ValueType,
    pub conflicts_with: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ValueType {
    None,
    String,
    Integer,
    Path,
    Boolean,
}

/// Radial keyboard for text input using directional buttons
#[derive(Debug, Clone)]
pub struct RadialKeyboard {
    pub current_sector: KeyboardSector,
    pub shift_mode: bool,
    pub caps_mode: bool,
    pub selected_char_index: usize,
}

#[derive(Debug, Clone)]
pub enum KeyboardSector {
    Letters,    // A-Z
    Numbers,    // 0-9
    Symbols,    // !@#$%^&*()
    Navigation, // Space, Enter, Backspace, Tab
}

/// Radial button mapping (consistent with email client)
#[derive(Debug, Clone)]
pub enum RadialButton {
    A, // Up/North
    B, // Down/South
    L, // Left/West
    R, // Right/East
}

impl AnbernicTerminal {
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let current_directory = std::env::current_dir()?;
        let filesystem_cache = FilesystemCache::new(&current_directory)?;

        let command_templates = Self::load_command_templates();

        Ok(Self {
            current_directory,
            command_history: Vec::new(),
            filesystem_cache,
            input_state: TerminalInputState::default(),
            ui_state: TerminalUIState::default(),
            command_builder: CommandBuilder::new(command_templates),
            radial_keyboard: RadialKeyboard::default(),
        })
    }

    /// Load common bash command templates with their flags and options
    fn load_command_templates() -> HashMap<String, CommandTemplate> {
        let mut templates = HashMap::new();

        // ls command
        templates.insert(
            "ls".to_string(),
            CommandTemplate {
                name: "ls".to_string(),
                description: "List directory contents".to_string(),
                common_flags: vec![
                    CommandFlag {
                        short: Some("-l".to_string()),
                        long: Some("--long".to_string()),
                        description: "Long format listing".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-a".to_string()),
                        long: Some("--all".to_string()),
                        description: "Show hidden files".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-h".to_string()),
                        long: Some("--human-readable".to_string()),
                        description: "Human readable sizes".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                ],
                requires_path: false,
                example_usage: "ls -la /home/user".to_string(),
            },
        );

        // cp command
        templates.insert(
            "cp".to_string(),
            CommandTemplate {
                name: "cp".to_string(),
                description: "Copy files or directories".to_string(),
                common_flags: vec![
                    CommandFlag {
                        short: Some("-r".to_string()),
                        long: Some("--recursive".to_string()),
                        description: "Copy directories recursively".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-v".to_string()),
                        long: Some("--verbose".to_string()),
                        description: "Verbose output".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                ],
                requires_path: true,
                example_usage: "cp -r source/ destination/".to_string(),
            },
        );

        // grep command
        templates.insert(
            "grep".to_string(),
            CommandTemplate {
                name: "grep".to_string(),
                description: "Search text patterns".to_string(),
                common_flags: vec![
                    CommandFlag {
                        short: Some("-i".to_string()),
                        long: Some("--ignore-case".to_string()),
                        description: "Case insensitive search".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-r".to_string()),
                        long: Some("--recursive".to_string()),
                        description: "Search recursively".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-n".to_string()),
                        long: Some("--line-number".to_string()),
                        description: "Show line numbers".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                ],
                requires_path: false,
                example_usage: "grep -in pattern file.txt".to_string(),
            },
        );

        // find command
        templates.insert(
            "find".to_string(),
            CommandTemplate {
                name: "find".to_string(),
                description: "Search for files and directories".to_string(),
                common_flags: vec![
                    CommandFlag {
                        short: Some("-name".to_string()),
                        long: None,
                        description: "Search by name pattern".to_string(),
                        takes_value: true,
                        value_type: ValueType::String,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-type".to_string()),
                        long: None,
                        description: "File type (f=file, d=directory)".to_string(),
                        takes_value: true,
                        value_type: ValueType::String,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-size".to_string()),
                        long: None,
                        description: "File size criteria".to_string(),
                        takes_value: true,
                        value_type: ValueType::String,
                        conflicts_with: vec![],
                    },
                ],
                requires_path: true,
                example_usage: "find /path -name '*.txt' -type f".to_string(),
            },
        );

        templates
    }

    /// Navigate to a different directory and update filesystem cache
    pub fn change_directory(&mut self, path: &PathBuf) -> Result<(), Box<dyn std::error::Error>> {
        let new_path = if path.is_relative() {
            self.current_directory.join(path)
        } else {
            path.clone()
        };

        if new_path.exists() && new_path.is_dir() {
            self.current_directory = new_path.canonicalize()?;
            self.filesystem_cache = FilesystemCache::new(&self.current_directory)?;
            self.ui_state.selected_file_index = 0;
            self.ui_state.scroll_offset = 0;
            Ok(())
        } else {
            Err("Directory does not exist".into())
        }
    }

    /// Execute a bash command and capture output
    pub fn execute_command(
        &mut self,
        command: &str,
    ) -> Result<CommandEntry, Box<dyn std::error::Error>> {
        let start_time = Utc::now();

        let output = Command::new("sh")
            .arg("-c")
            .arg(command)
            .current_dir(&self.current_directory)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()?;

        let entry = CommandEntry {
            command: command.to_string(),
            working_directory: self.current_directory.clone(),
            timestamp: start_time,
            exit_code: output.status.code(),
            output: String::from_utf8_lossy(&output.stdout).to_string(),
            error: String::from_utf8_lossy(&output.stderr).to_string(),
        };

        self.command_history.push(entry.clone());

        // Update filesystem cache if command might have changed directory contents
        if command.starts_with("mkdir")
            || command.starts_with("rm")
            || command.starts_with("mv")
            || command.starts_with("cp")
        {
            self.filesystem_cache = FilesystemCache::new(&self.current_directory)?;
        }

        Ok(entry)
    }

    /// Handle radial button input based on current mode
    pub fn handle_input(&mut self, button: RadialButton) -> Result<(), Box<dyn std::error::Error>> {
        match self.input_state.input_mode {
            InputMode::Navigation => self.handle_navigation_input(button),
            InputMode::TextEntry => self.handle_text_input(button),
            InputMode::RadialMenu => self.handle_radial_menu_input(button),
            InputMode::FileExplorer => self.handle_file_explorer_input(button),
            InputMode::CommandConfig => self.handle_command_config_input(button),
            InputMode::TextEditMode => self.handle_text_edit_input(button),
        }
    }

    fn handle_navigation_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match self.input_state.current_group {
            InputGroup::MainMenu => {
                match button {
                    RadialButton::A => {
                        if self.input_state.selected_index > 0 {
                            self.input_state.selected_index -= 1;
                        }
                    }
                    RadialButton::B => {
                        self.input_state.selected_index = (self.input_state.selected_index + 1) % 4;
                        // 4 main menu items
                    }
                    RadialButton::R => {
                        // Select current menu item
                        match self.input_state.selected_index {
                            0 => {
                                self.ui_state.current_view = TerminalView::FilesystemBrowser;
                                self.input_state.current_group = InputGroup::FilesystemBrowser;
                                self.input_state.input_mode = InputMode::FileExplorer;
                            }
                            1 => {
                                self.ui_state.current_view = TerminalView::CommandBuilder;
                                self.input_state.current_group = InputGroup::CommandBuilder;
                                self.input_state.input_mode = InputMode::CommandConfig;
                            }
                            2 => {
                                self.ui_state.current_view = TerminalView::History;
                                self.input_state.current_group = InputGroup::History;
                            }
                            3 => {
                                self.ui_state.current_view = TerminalView::Settings;
                                self.input_state.current_group = InputGroup::Settings;
                            }
                            _ => {}
                        }
                        self.input_state.selected_index = 0;
                    }
                    RadialButton::L => {
                        // Back to main menu
                        self.ui_state.current_view = TerminalView::MainMenu;
                        self.input_state.current_group = InputGroup::MainMenu;
                        self.input_state.input_mode = InputMode::Navigation;
                        self.input_state.selected_index = 0;
                    }
                }
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_text_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        self.radial_keyboard
            .handle_input(button, &mut self.input_state.text_buffer)
    }

    fn handle_radial_menu_input(
        &mut self,
        _button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Implement radial menu navigation
        Ok(())
    }

    fn handle_file_explorer_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match button {
            RadialButton::A => {
                if self.ui_state.selected_file_index > 0 {
                    self.ui_state.selected_file_index -= 1;
                }
            }
            RadialButton::B => {
                if self.ui_state.selected_file_index
                    < self
                        .filesystem_cache
                        .current_entries
                        .len()
                        .saturating_sub(1)
                {
                    self.ui_state.selected_file_index += 1;
                }
            }
            RadialButton::R => {
                // Enter directory or select file
                if let Some(entry) = self
                    .filesystem_cache
                    .current_entries
                    .get(self.ui_state.selected_file_index)
                {
                    match entry.entry_type {
                        EntryType::Directory => {
                            let path = entry.path.clone();
                            let _ = entry; // Release the borrow
                            self.change_directory(&path)?;
                        }
                        _ => {
                            // Add file path to command builder if in that mode
                            if let BuildState::EnteringParameters = self.command_builder.build_state
                            {
                                self.input_state.text_buffer =
                                    entry.path.to_string_lossy().to_string();
                            }
                        }
                    }
                }
            }
            RadialButton::L => {
                // Go up one directory
                let parent_path = self.filesystem_cache.parent_directory.clone();
                if let Some(parent_path) = parent_path {
                    self.change_directory(&parent_path)?;
                }
            }
        }
        Ok(())
    }

    fn handle_command_config_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match self.command_builder.build_state {
            BuildState::SelectingCommand => {
                // Navigate through available commands
                match button {
                    RadialButton::A | RadialButton::B => {
                        // Cycle through commands
                        let commands: Vec<_> =
                            self.command_builder.available_commands.keys().collect();
                        if !commands.is_empty() {
                            let current_cmd = &self.command_builder.base_command;
                            if let Some(current_index) =
                                commands.iter().position(|&cmd| cmd == current_cmd)
                            {
                                let new_index = match button {
                                    RadialButton::A => {
                                        if current_index > 0 {
                                            current_index - 1
                                        } else {
                                            commands.len() - 1
                                        }
                                    }
                                    RadialButton::B => (current_index + 1) % commands.len(),
                                    _ => current_index,
                                };
                                self.command_builder.base_command = commands[new_index].clone();
                            }
                        }
                    }
                    RadialButton::R => {
                        self.command_builder.build_state = BuildState::SelectingFlags;
                    }
                    RadialButton::L => {
                        self.ui_state.current_view = TerminalView::MainMenu;
                        self.input_state.current_group = InputGroup::MainMenu;
                        self.input_state.input_mode = InputMode::Navigation;
                    }
                }
            }
            BuildState::SelectingFlags => {
                // Select flags for the current command
                if let Some(template) = self
                    .command_builder
                    .available_commands
                    .get(&self.command_builder.base_command)
                {
                    match button {
                        RadialButton::A | RadialButton::B => {
                            // Navigate through flags
                        }
                        RadialButton::R => {
                            // Toggle flag selection
                        }
                        RadialButton::L => {
                            self.command_builder.build_state = BuildState::SelectingCommand;
                        }
                    }
                }
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_text_edit_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Placeholder implementation for TextEditMode
        match button {
            RadialButton::L => {
                // Exit text edit mode
                self.input_state.input_mode = InputMode::Navigation;
            }
            _ => {
                // TODO: Implement actual text editing functionality
            }
        }
        Ok(())
    }

    /// Render the current terminal state as ASCII art (Game Boy style)
    pub fn render(&self) -> String {
        match self.ui_state.current_view {
            TerminalView::MainMenu => self.render_main_menu(),
            TerminalView::FilesystemBrowser => self.render_filesystem_browser(),
            TerminalView::CommandBuilder => self.render_command_builder(),
            TerminalView::CommandOutput => self.render_command_output(),
            TerminalView::History => self.render_history(),
            TerminalView::Settings => self.render_settings(),
        }
    }

    fn render_main_menu(&self) -> String {
        let menu_items = [
            "📁 File Explorer",
            "⚡ Command Builder",
            "📜 History",
            "⚙️ Settings",
        ];
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                           ANBERNIC TERMINAL                                │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(&format!(
            "│ Directory: {}                                            │\n",
            self.current_directory.to_string_lossy()
        ));
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );

        for (i, item) in menu_items.iter().enumerate() {
            let selected = if i == self.input_state.selected_index {
                "► "
            } else {
                "  "
            };
            output.push_str(&format!(
                "│ {}{}                                                              │\n",
                selected, item
            ));
        }

        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ A/B: Navigate  R: Select  L: Back                                          │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_filesystem_browser(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                          FILE EXPLORER                                    │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(&format!(
            "│ {:<74} │\n",
            self.current_directory.to_string_lossy()
        ));
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );

        // Show parent directory option
        if self.filesystem_cache.parent_directory.is_some() {
            let selected = if self.ui_state.selected_file_index == 0 {
                "► "
            } else {
                "  "
            };
            output.push_str(&format!(
                "│ {}📁 ..                                                               │\n",
                selected
            ));
        }

        // Show directory contents
        for (i, entry) in self.filesystem_cache.current_entries.iter().enumerate() {
            let adjusted_index = if self.filesystem_cache.parent_directory.is_some() {
                i + 1
            } else {
                i
            };
            let selected = if adjusted_index == self.ui_state.selected_file_index {
                "► "
            } else {
                "  "
            };

            let icon = match entry.entry_type {
                EntryType::Directory => "📁",
                EntryType::Executable => "⚡",
                EntryType::SymLink => "🔗",
                EntryType::Hidden => "👻",
                EntryType::File => "📄",
            };

            output.push_str(&format!("│ {}{} {:<66} │\n", selected, icon, entry.name));
        }

        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ A/B: Navigate  R: Enter/Select  L: Up Directory                           │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_command_builder(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                        COMMAND BUILDER                                    │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );

        match self.command_builder.build_state {
            BuildState::SelectingCommand => {
                output.push_str("│ Select Command:                                                            │\n");
                output.push_str("├────────────────────────────────────────────────────────────────────────────┤\n");

                for (cmd, template) in &self.command_builder.available_commands {
                    let selected = if cmd == &self.command_builder.base_command {
                        "► "
                    } else {
                        "  "
                    };
                    output.push_str(&format!(
                        "│ {}{:<20} - {}                                   │\n",
                        selected, cmd, template.description
                    ));
                }
            }
            BuildState::SelectingFlags => {
                output.push_str(&format!(
                    "│ Command: {}                                                       │\n",
                    self.command_builder.base_command
                ));
                output.push_str("├────────────────────────────────────────────────────────────────────────────┤\n");
                output.push_str("│ Available Flags:                                                           │\n");

                if let Some(template) = self
                    .command_builder
                    .available_commands
                    .get(&self.command_builder.base_command)
                {
                    for flag in &template.common_flags {
                        let selected = self
                            .command_builder
                            .selected_flags
                            .iter()
                            .any(|f| f.short == flag.short || f.long == flag.long);
                        let indicator = if selected { "✓" } else { " " };

                        let flag_display = if let Some(short) = &flag.short {
                            short.clone()
                        } else if let Some(long) = &flag.long {
                            long.clone()
                        } else {
                            "".to_string()
                        };

                        output.push_str(&format!(
                            "│ [{}] {:<15} - {}                            │\n",
                            indicator, flag_display, flag.description
                        ));
                    }
                }
            }
            _ => {
                output.push_str("│ Building command...                                                        │\n");
            }
        }

        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ A/B: Navigate  R: Select/Toggle  L: Back                                  │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_command_output(&self) -> String {
        // Show output from last executed command
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                        COMMAND OUTPUT                                     │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );

        if let Some(last_command) = self.command_history.last() {
            output.push_str(&format!("│ Command: {:<66} │\n", last_command.command));
            output.push_str(&format!(
                "│ Exit Code: {:<64} │\n",
                last_command
                    .exit_code
                    .map_or("N/A".to_string(), |c| c.to_string())
            ));
            output.push_str(
                "├────────────────────────────────────────────────────────────────────────────┤\n",
            );

            // Show output (truncated to fit)
            for line in last_command.output.lines().take(10) {
                output.push_str(&format!(
                    "│ {:<74} │\n",
                    if line.len() > 74 { &line[..74] } else { line }
                ));
            }

            if !last_command.error.is_empty() {
                output.push_str("├────────────────────────────────────────────────────────────────────────────┤\n");
                output.push_str("│ STDERR:                                                                    │\n");
                for line in last_command.error.lines().take(5) {
                    output.push_str(&format!(
                        "│ {:<74} │\n",
                        if line.len() > 74 { &line[..74] } else { line }
                    ));
                }
            }
        } else {
            output.push_str(
                "│ No commands executed yet.                                                  │\n",
            );
        }

        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ L: Back to Menu                                                            │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_history(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                         COMMAND HISTORY                                   │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );

        for (i, entry) in self.command_history.iter().rev().enumerate().take(15) {
            let time = entry.timestamp.format("%H:%M:%S");
            let status = match entry.exit_code {
                Some(0) => "✓",
                Some(_) => "✗",
                None => "?",
            };

            output.push_str(&format!(
                "│ {} {} {:<60} │\n",
                status,
                time,
                if entry.command.len() > 60 {
                    &entry.command[..60]
                } else {
                    &entry.command
                }
            ));
        }

        if self.command_history.is_empty() {
            output.push_str(
                "│ No command history available.                                              │\n",
            );
        }

        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ L: Back to Menu                                                            │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_settings(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                           SETTINGS                                        │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(&format!(
            "│ Terminal Size: {}x{}                                               │\n",
            self.ui_state.terminal_width, self.ui_state.terminal_height
        ));
        output.push_str(&format!(
            "│ Show Hidden Files: {}                                                 │\n",
            if self.ui_state.show_hidden_files {
                "Yes"
            } else {
                "No"
            }
        ));
        output.push_str(&format!(
            "│ Current Directory: {}                                      │\n",
            self.current_directory.to_string_lossy()
        ));
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ L: Back to Menu                                                            │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }
}

impl FilesystemCache {
    fn new(directory: &PathBuf) -> Result<Self, Box<dyn std::error::Error>> {
        let mut entries = Vec::new();

        if let Ok(read_dir) = std::fs::read_dir(directory) {
            for entry in read_dir {
                if let Ok(entry) = entry {
                    let path = entry.path();
                    let metadata = entry.metadata()?;

                    let entry_type = if path.is_dir() {
                        EntryType::Directory
                    } else if path.is_symlink() {
                        EntryType::SymLink
                    } else if metadata.permissions().readonly() {
                        EntryType::File
                    } else {
                        EntryType::Executable
                    };

                    let name = entry.file_name().to_string_lossy().to_string();
                    if name.starts_with('.') {
                        continue; // Skip hidden files for now
                    }

                    entries.push(FilesystemEntry {
                        name,
                        path,
                        entry_type,
                        size: if metadata.is_file() {
                            Some(metadata.len())
                        } else {
                            None
                        },
                        permissions: format!("{:o}", metadata.permissions().mode() & 0o777),
                        modified: DateTime::from_timestamp(
                            metadata
                                .modified()?
                                .duration_since(std::time::UNIX_EPOCH)?
                                .as_secs() as i64,
                            0,
                        )
                        .unwrap_or_else(|| Utc::now()),
                    });
                }
            }
        }

        // Sort entries: directories first, then files
        entries.sort_by(|a, b| match (&a.entry_type, &b.entry_type) {
            (EntryType::Directory, EntryType::Directory) => a.name.cmp(&b.name),
            (EntryType::Directory, _) => std::cmp::Ordering::Less,
            (_, EntryType::Directory) => std::cmp::Ordering::Greater,
            _ => a.name.cmp(&b.name),
        });

        let parent_directory = directory.parent().map(|p| p.to_path_buf());

        Ok(Self {
            current_entries: entries,
            parent_directory,
            last_updated: Utc::now(),
        })
    }
}

impl CommandBuilder {
    fn new(templates: HashMap<String, CommandTemplate>) -> Self {
        let base_command = templates
            .keys()
            .next()
            .cloned()
            .unwrap_or_else(|| "ls".to_string());

        Self {
            base_command,
            selected_flags: Vec::new(),
            parameters: HashMap::new(),
            available_commands: templates,
            build_state: BuildState::SelectingCommand,
        }
    }

    /// Build the final command string with selected flags and parameters
    pub fn build_command(&self) -> String {
        let mut command = self.base_command.clone();

        for flag in &self.selected_flags {
            if let Some(short) = &flag.short {
                command.push(' ');
                command.push_str(short);
            }
        }

        for (param, value) in &self.parameters {
            command.push(' ');
            command.push_str(value);
        }

        command
    }
}

impl RadialKeyboard {
    fn handle_input(
        &mut self,
        button: RadialButton,
        text_buffer: &mut String,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match button {
            RadialButton::A => {
                self.current_sector = match self.current_sector {
                    KeyboardSector::Letters => KeyboardSector::Navigation,
                    KeyboardSector::Numbers => KeyboardSector::Letters,
                    KeyboardSector::Symbols => KeyboardSector::Numbers,
                    KeyboardSector::Navigation => KeyboardSector::Symbols,
                }
            }
            RadialButton::B => {
                self.current_sector = match self.current_sector {
                    KeyboardSector::Letters => KeyboardSector::Numbers,
                    KeyboardSector::Numbers => KeyboardSector::Symbols,
                    KeyboardSector::Symbols => KeyboardSector::Navigation,
                    KeyboardSector::Navigation => KeyboardSector::Letters,
                }
            }
            RadialButton::L => {
                // Previous character in current sector
                match self.current_sector {
                    KeyboardSector::Letters => {
                        let chars = if self.shift_mode {
                            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                        } else {
                            "abcdefghijklmnopqrstuvwxyz"
                        };
                        if self.selected_char_index > 0 {
                            self.selected_char_index -= 1;
                        } else {
                            self.selected_char_index = chars.len() - 1;
                        }
                    }
                    KeyboardSector::Numbers => {
                        let chars = "0123456789";
                        if self.selected_char_index > 0 {
                            self.selected_char_index -= 1;
                        } else {
                            self.selected_char_index = chars.len() - 1;
                        }
                    }
                    KeyboardSector::Symbols => {
                        let chars = "!@#$%^&*()_+-=[]{}|;:,.<>?";
                        if self.selected_char_index > 0 {
                            self.selected_char_index -= 1;
                        } else {
                            self.selected_char_index = chars.len() - 1;
                        }
                    }
                    KeyboardSector::Navigation => {
                        let actions = ["SPACE", "ENTER", "BACKSPACE", "TAB", "SHIFT"];
                        if self.selected_char_index > 0 {
                            self.selected_char_index -= 1;
                        } else {
                            self.selected_char_index = actions.len() - 1;
                        }
                    }
                }
            }
            RadialButton::R => {
                // Select current character or action
                match self.current_sector {
                    KeyboardSector::Letters => {
                        let chars = if self.shift_mode {
                            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                        } else {
                            "abcdefghijklmnopqrstuvwxyz"
                        };
                        if let Some(ch) = chars.chars().nth(self.selected_char_index) {
                            text_buffer.push(ch);
                        }
                    }
                    KeyboardSector::Numbers => {
                        let chars = "0123456789";
                        if let Some(ch) = chars.chars().nth(self.selected_char_index) {
                            text_buffer.push(ch);
                        }
                    }
                    KeyboardSector::Symbols => {
                        let chars = "!@#$%^&*()_+-=[]{}|;:,.<>?";
                        if let Some(ch) = chars.chars().nth(self.selected_char_index) {
                            text_buffer.push(ch);
                        }
                    }
                    KeyboardSector::Navigation => {
                        match self.selected_char_index {
                            0 => text_buffer.push(' '),  // SPACE
                            1 => text_buffer.push('\n'), // ENTER
                            2 => {
                                text_buffer.pop();
                            } // BACKSPACE
                            3 => text_buffer.push('\t'), // TAB
                            4 => self.shift_mode = !self.shift_mode, // SHIFT
                            _ => {}
                        }
                    }
                }
            }
        }
        Ok(())
    }
}

impl Default for TerminalInputState {
    fn default() -> Self {
        Self {
            current_group: InputGroup::MainMenu,
            selected_index: 0,
            text_buffer: String::new(),
            cursor_position: 0,
            input_mode: InputMode::Navigation,
            command_cursor: 0,
        }
    }
}

impl Default for TerminalUIState {
    fn default() -> Self {
        Self {
            current_view: TerminalView::MainMenu,
            selected_file_index: 0,
            scroll_offset: 0,
            show_help: false,
            animation_frame: 0,
            show_hidden_files: false,
            terminal_width: 80,
            terminal_height: 24,
        }
    }
}

impl Default for RadialKeyboard {
    fn default() -> Self {
        Self {
            current_sector: KeyboardSector::Letters,
            shift_mode: false,
            caps_mode: false,
            selected_char_index: 0,
        }
    }
}

```
<!-- }}} -->

<!-- {{{ src/daemon.rs - Complete Context -->
### 📄 src/daemon.rs

**File Metadata:**
- Size: 13690 bytes
- Lines: 400
- Modified: 2025-11-13 00:57:10.354801668 -0800
- Language: 

**File Content:**

```
use log::{debug, error, info};
use rand::Rng;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{broadcast, RwLock};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub id: String,
    pub sender: String,
    pub content: String,
    pub timestamp: u64,
    pub message_type: MessageType,
    pub is_encrypted: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MessageType {
    Text,
    Command,
    LlmRequest,
    LlmResponse,
    StateSync,
}

#[derive(Debug, Clone)]
pub struct ClientInfo {
    pub id: String,
    pub device_type: DeviceType,
    pub last_seen: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeviceType {
    Handheld,
    Desktop,
    Cluster,
}

/// Per-relationship encryption manager for daemon communications
#[derive(Debug, Clone)]
pub struct DaemonCryptoManager {
    pub device_id: String,
    pub private_key: String,
    pub public_key: String,
    pub relationship_keys: HashMap<String, (String, String)>, // client_id -> (private_key, public_key)
    pub encryption_enabled: bool,
}

pub struct ProjectDaemon {
    clients: Arc<RwLock<HashMap<String, ClientInfo>>>,
    message_sender: broadcast::Sender<Message>,
    state: Arc<RwLock<HashMap<String, serde_json::Value>>>,
    crypto: Arc<RwLock<DaemonCryptoManager>>,
}

impl ProjectDaemon {
    pub fn new() -> Self {
        let (tx, _) = broadcast::channel(1000);

        // Generate unique device ID for daemon
        let device_id = format!("daemon_{:016x}", rand::thread_rng().gen::<u64>());
        let (private_key, public_key) = Self::generate_keypair();

        let crypto = DaemonCryptoManager {
            device_id,
            private_key,
            public_key,
            relationship_keys: HashMap::new(),
            encryption_enabled: true,
        };

        Self {
            clients: Arc::new(RwLock::new(HashMap::new())),
            message_sender: tx,
            state: Arc::new(RwLock::new(HashMap::new())),
            crypto: Arc::new(RwLock::new(crypto)),
        }
    }

    fn generate_keypair() -> (String, String) {
        let mut rng = rand::thread_rng();
        let private_key = format!("DAEMON_PRIV_{:032x}", rng.gen::<u128>());
        let public_key = format!("DAEMON_PUB_{:032x}", rng.gen::<u128>());
        (private_key, public_key)
    }

    pub async fn start(&self, port: u16) -> Result<(), Box<dyn std::error::Error>> {
        let listener = TcpListener::bind(format!("127.0.0.1:{}", port)).await?; // Security: localhost only
        info!("Project daemon listening on localhost:{} (air-gapped compliance)", port);

        // Start state persistence task
        self.start_state_persistence().await;

        loop {
            match listener.accept().await {
                Ok((stream, addr)) => {
                    // Security: Validate connection is from authorized localhost only
                    if !addr.ip().is_loopback() {
                        error!("Rejected non-localhost connection from: {}", addr);
                        continue;
                    }
                    
                    info!("New authorized client connected: {}", addr);
                    let daemon = self.clone();
                    tokio::spawn(async move {
                        if let Err(e) = daemon.handle_client(stream).await {
                            error!("Client handler error: {}", e);
                        }
                    });
                }
                Err(e) => {
                    error!("Failed to accept connection: {}", e);
                }
            }
        }
    }

    async fn handle_client(&self, mut stream: TcpStream) -> Result<(), Box<dyn std::error::Error>> {
        let mut buffer = vec![0; 1024];
        let mut message_receiver = self.message_sender.subscribe();

        loop {
            tokio::select! {
                // Handle incoming messages from client
                result = stream.read(&mut buffer) => {
                    match result {
                        Ok(0) => break, // Connection closed
                        Ok(n) => {
                            let data = &buffer[..n];
                            if let Ok(message) = serde_json::from_slice::<Message>(data) {
                                self.process_message(message).await?;
                            }
                        }
                        Err(e) => {
                            error!("Read error: {}", e);
                            break;
                        }
                    }
                }

                // Forward messages to client
                message = message_receiver.recv() => {
                    match message {
                        Ok(msg) => {
                            let serialized = serde_json::to_vec(&msg)?;
                            if let Err(e) = stream.write_all(&serialized).await {
                                error!("Write error: {}", e);
                                break;
                            }
                        }
                        Err(_) => break,
                    }
                }
            }
        }

        Ok(())
    }

    async fn process_message(
        &self,
        mut message: Message,
    ) -> Result<(), Box<dyn std::error::Error>> {
        debug!("Processing message: {:?}", message);

        // Decrypt message if it's encrypted
        if message.is_encrypted {
            let mut crypto = self.crypto.write().await;
            match crypto.decrypt_from_client(&message.content, &message.sender) {
                Ok(decrypted_content) => {
                    message.content = decrypted_content;
                    message.is_encrypted = false;
                }
                Err(e) => {
                    error!("Failed to decrypt message from {}: {}", message.sender, e);
                    return Ok(()); // Skip processing encrypted messages we can't decrypt
                }
            }
        }

        match message.message_type {
            MessageType::LlmRequest => {
                // Forward to desktop LLM service
                self.forward_to_llm_service(message).await?;
            }
            MessageType::StateSync => {
                // Update daemon state
                self.update_state(&message).await?;
            }
            _ => {
                // Broadcast to all clients
                if let Err(e) = self.message_sender.send(message) {
                    error!("Failed to broadcast message: {}", e);
                }
            }
        }

        Ok(())
    }

    async fn forward_to_llm_service(
        &self,
        message: Message,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Find desktop/cluster clients
        let clients = self.clients.read().await;
        for (_, client) in clients.iter() {
            match client.device_type {
                DeviceType::Desktop | DeviceType::Cluster => {
                    // Forward message to LLM service
                    if let Err(e) = self.message_sender.send(message.clone()) {
                        error!("Failed to forward to LLM service: {}", e);
                    }
                    break;
                }
                _ => continue,
            }
        }
        Ok(())
    }

    async fn update_state(&self, message: &Message) -> Result<(), Box<dyn std::error::Error>> {
        let mut state = self.state.write().await;
        if let Ok(value) = serde_json::from_str(&message.content) {
            state.insert(message.sender.clone(), value);
        }
        Ok(())
    }

    async fn start_state_persistence(&self) {
        let state = Arc::clone(&self.state);
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(std::time::Duration::from_secs(30));

            loop {
                interval.tick().await;
                let state_snapshot = state.read().await;

                // Save state to files/build directory
                if let Ok(serialized) = serde_json::to_string_pretty(&*state_snapshot) {
                    if let Err(e) =
                        tokio::fs::write("files/build/daemon_state.json", serialized).await
                    {
                        error!("Failed to save state: {}", e);
                    }
                }
            }
        });
    }
}

impl Clone for ProjectDaemon {
    fn clone(&self) -> Self {
        Self {
            clients: Arc::clone(&self.clients),
            message_sender: self.message_sender.clone(),
            state: Arc::clone(&self.state),
            crypto: Arc::clone(&self.crypto),
        }
    }
}

impl DaemonCryptoManager {
    /// Encrypt a message for a specific client using per-relationship keys
    pub fn encrypt_for_client(
        &mut self,
        content: &str,
        client_id: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if !self.encryption_enabled {
            return Ok(content.to_string());
        }

        // Get or create relationship key for this client
        let (private_key, public_key) =
            if let Some((priv_key, pub_key)) = self.relationship_keys.get(client_id) {
                (priv_key.clone(), pub_key.clone())
            } else {
                // Generate new key pair for this relationship
                let new_keys = self.generate_relationship_keys(client_id)?;
                self.relationship_keys
                    .insert(client_id.to_string(), new_keys.clone());
                new_keys
            };

        // Simplified encryption - in real implementation would use actual encryption
        let encrypted = format!("DAEMON_ENCRYPTED[{}]:{}", client_id, content);
        Ok(encrypted)
    }

    /// Decrypt a message, trying all available keys for the sender
    pub fn decrypt_from_client(
        &mut self,
        encrypted_content: &str,
        client_id: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if !self.encryption_enabled {
            return Ok(encrypted_content.to_string());
        }

        // Try relationship key first
        if let Some((private_key, _)) = self.relationship_keys.get(client_id) {
            if let Ok(decrypted) =
                self.try_decrypt_with_key(encrypted_content, private_key, client_id)
            {
                return Ok(decrypted);
            }
        }

        // Try main daemon key
        if let Ok(decrypted) =
            self.try_decrypt_with_key(encrypted_content, &self.private_key, client_id)
        {
            return Ok(decrypted);
        }

        // If no key works, generate new relationship key for this client
        let new_keys = self.generate_relationship_keys(client_id)?;
        self.relationship_keys
            .insert(client_id.to_string(), new_keys.clone());

        // Try with new key (this may still fail, but establishes the relationship)
        if let Ok(decrypted) = self.try_decrypt_with_key(encrypted_content, &new_keys.0, client_id)
        {
            return Ok(decrypted);
        }

        Err("Failed to decrypt message with any available keys".into())
    }

    /// Generate a new key pair for a specific client relationship
    fn generate_relationship_keys(
        &self,
        client_id: &str,
    ) -> Result<(String, String), Box<dyn std::error::Error>> {
        use rand::Rng;
        use sha2::{Digest, Sha256};

        // Generate a deterministic but unique key based on our device ID and their client ID
        let mut hasher = Sha256::new();
        hasher.update(self.device_id.as_bytes());
        hasher.update(client_id.as_bytes());
        hasher.update(&rand::thread_rng().gen::<[u8; 32]>()); // Add randomness
        let key_seed = hasher.finalize();

        let private_key = format!("DAEMON_REL_PRIV_{}", hex::encode(&key_seed[..16]));
        let public_key = format!("DAEMON_REL_PUB_{}", hex::encode(&key_seed[16..]));

        Ok((private_key, public_key))
    }

    /// Try to decrypt with a specific key
    fn try_decrypt_with_key(
        &self,
        encrypted_content: &str,
        private_key: &str,
        expected_client: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        // Simplified decryption - check if message is in expected format
        if encrypted_content.starts_with(&format!("DAEMON_ENCRYPTED[{}]:", expected_client)) {
            let content = encrypted_content
                .strip_prefix(&format!("DAEMON_ENCRYPTED[{}]:", expected_client))
                .ok_or("Invalid encrypted format")?;
            Ok(content.to_string())
        } else {
            Err("Decryption failed".into())
        }
    }

    /// Get public key for a relationship (creates new relationship if needed)
    pub fn get_relationship_public_key(
        &mut self,
        client_id: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if let Some((_, public_key)) = self.relationship_keys.get(client_id) {
            Ok(public_key.clone())
        } else {
            let new_keys = self.generate_relationship_keys(client_id)?;
            let public_key = new_keys.1.clone();
            self.relationship_keys
                .insert(client_id.to_string(), new_keys);
            Ok(public_key)
        }
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();

    let daemon = ProjectDaemon::new();
    daemon.start(8080).await?;

    Ok(())
}

```
<!-- }}} -->

