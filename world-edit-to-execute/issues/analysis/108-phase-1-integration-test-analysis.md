## Analysis: Issue 108 - Phase 1 Integration Test and Demo

This issue is a good candidate for splitting. It contains four distinct deliverables that can be implemented independently:

1. A test suite
2. A demo script
3. A runner script
4. Documentation/finalization tasks

### Recommended Sub-Issues

---

#### **108a-create-integration-test-suite**
**Name:** create-integration-test-suite  
**Description:** Create the test framework in `src/tests/phase1_test.lua` that exercises all Phase 1 components against the map files in `assets/`. Should test MPQ opening, file extraction, w3i/w3e/wts parsing, and the unified Map data structure. Produces a structured results table with pass/fail status and error details for each map.

**Dependencies:** None (but requires 101-107 to be implemented)

---

#### **108b-create-phase1-demo-script**
**Name:** create-phase1-demo-script  
**Description:** Create the visual demonstration script at `issues/completed/demos/phase1_demo.lua`. Uses box-drawing characters to display formatted output showing map metadata, player configurations, and terrain statistics for each map file. Demonstrates all Phase 1 capabilities in a user-friendly terminal presentation.

**Dependencies:** 108a (uses same underlying modules, benefits from test validation)

---

#### **108c-create-demo-runner-script**
**Name:** create-demo-runner-script  
**Description:** Create the `run-demo.sh` bash script in the project root that provides phase selection (interactive or via argument). Should follow project conventions with hardcoded `DIR`, argument override capability, and `-I` interactive mode flag per global CLAUDE.md requirements.

**Dependencies:** 108b (needs demo script to exist to run it)

---

#### **108d-run-tests-and-document-results**
**Name:** run-tests-and-document-results  
**Description:** Execute the integration test suite against all 15 DAoW maps, document any failures as new issue tickets, update `issues/progress.md` with Phase 1 completion status, and perform phase finalization: move completed issues to `issues/completed/`, create git tag `v0.1.0-phase1`.

**Dependencies:** 108a, 108b, 108c (all artifacts must exist and pass before finalization)

---

### Dependency Graph

```
108a (test suite)
  ↓
108b (demo script)
  ↓
108c (runner script)
  ↓
108d (run & document)
```

### Rationale for Split

- **108a** is the foundational testing work - purely technical, can be validated independently
- **108b** is presentation/demo focused - depends on same modules but different purpose
- **108c** is bash tooling - small and self-contained
- **108d** is the "gate" step - can only happen after everything else works

This split allows parallel work on 108a/108b if needed (they use same modules but produce different outputs), and clearly separates the "make it work" phase from the "document and finalize" phase.
