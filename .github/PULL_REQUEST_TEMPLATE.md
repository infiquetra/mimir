# Pull Request

## Summary

<!-- Brief description of what this PR accomplishes -->

## Related Issues

<!-- Link to related GitHub issues -->
Closes #
Relates to #

## Type of Change

<!-- Check all that apply -->
- [ ] Capability (new end-to-end functionality)
- [ ] Enhancement (improvement to existing functionality)
- [ ] Defect (bug fix)
- [ ] Exploration (research/POC code)
- [ ] Context Update (documentation only)
- [ ] Infrastructure (CI/CD, config)
- [ ] Refactor (code improvement, no functionality change)
- [ ] Tests (adding or updating tests)

## AI Generation Metrics

<!-- Required for all code changes -->
- **AI Generated Code**: ___% (estimate 0-100)
- **AI Tool Used**: Claude Code / GitHub Copilot / Other: ___
- **Human Refinement Required**: Minimal / Moderate / Significant
- **AI Prompt Saved**: [ ] Yes (link to blueprint) [ ] No [ ] N/A

**AI Generation Notes**:
<!-- Optional: Describe what AI generated well vs. what needed manual work -->

## Context

### Blueprint Links
<!-- Required: Link to all relevant Blueprint repository context -->
- Requirements: <!-- link to infiquetra-blueprint/requirements/... -->
- Specifications: <!-- link to infiquetra-blueprint/specifications/... -->
- Architecture Decisions: <!-- link to infiquetra-blueprint/architecture/decisions/... -->

### Context Completeness
- **Context Score**: ___%  (0-100, based on how complete Blueprint context was)
- **Context Gaps Discovered**: <!-- list any gaps found, create Context Update if needed -->

## Changes Made

### Functional Changes
<!-- Describe what changed from a functionality perspective -->
-
-
-

### Technical Changes
<!-- Describe technical implementation details -->
-
-
-

### Files Changed
<!-- Highlight key files and why -->
- `path/to/file.py` -
- `path/to/other.py` -

## Testing

### Test Coverage
- **Unit Test Coverage**: ___%
- **Integration Tests**: [ ] Added [ ] Updated [ ] Not Applicable
- **Manual Testing**: [ ] Completed [ ] Not Applicable

### Testing Checklist
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Edge cases covered
- [ ] Error handling tested
- [ ] Performance tested (if applicable)
- [ ] Security tested (if applicable)

### Test Results
<!-- Paste relevant test output or link to CI results -->
```
# test output here
```

## Quality Checks

### Code Quality
- [ ] Code follows project conventions
- [ ] No code smells or anti-patterns
- [ ] Error handling is comprehensive
- [ ] Logging is adequate
- [ ] Code is readable and maintainable

### AI-Generated Code Review
<!-- Required if AI Generated Code > 50% -->
- [ ] AI-generated code reviewed for correctness
- [ ] AI-generated code reviewed for security
- [ ] AI-generated code reviewed for performance
- [ ] AI-generated code reviewed for maintainability

### Security
- [ ] No hardcoded secrets or credentials
- [ ] Input validation implemented
- [ ] Authentication/authorization checked
- [ ] Security scan passed (Bandit, etc.)
- [ ] No new security vulnerabilities introduced

### Performance
- [ ] No obvious performance issues
- [ ] Performance benchmarks met (if applicable)
- [ ] Database queries optimized
- [ ] Caching implemented where appropriate

## Deployment

### Deployment Notes
<!-- Any special deployment considerations -->
- [ ] Can be deployed without downtime
- [ ] No database migrations required
- [ ] No configuration changes required
- [ ] No breaking changes to APIs

<!-- If yes to any above, describe: -->

### Rollback Plan
<!-- How to rollback if this causes issues -->

### Monitoring
<!-- What should be monitored after deployment -->
- Metrics to watch:
- Alarms to configure:
- Dashboards to update:

## Breaking Changes

<!-- Check if this PR introduces breaking changes -->
- [ ] This PR contains breaking changes

<!-- If yes, describe the breaking changes and migration path: -->

## Documentation

- [ ] Code comments added/updated
- [ ] API documentation updated (OpenAPI spec)
- [ ] README updated (if applicable)
- [ ] Architecture diagrams updated (if applicable)
- [ ] Context Update created: #___ (link to Context Update issue)

## Pre-Merge Checklist

### Required Reviews
- [ ] Code review completed (1 approval for Enhancements, 2 for Capabilities)
- [ ] Security review completed (if security-sensitive)
- [ ] Tech lead review completed (if architectural change)

### CI/CD
- [ ] All CI checks passing
- [ ] Tests passing in CI
- [ ] Security scans passed

### Process
- [ ] Linked to GitHub issue
- [ ] Issue moved to "Code Review" column
- [ ] All review comments addressed
- [ ] Ready to merge

## Post-Merge Actions

<!-- What needs to happen after merge? -->
- [ ] Deploy to staging and validate
- [ ] Run integration tests
- [ ] Monitor for __ hours before production
- [ ] Move issue to "Integration Testing"

## Additional Notes

<!-- Any other context, concerns, or discussion points -->

---

## Review Guidelines for Reviewers

### Multi-LLM Review Strategy

**For AI-Heavy PRs (>50% AI-generated)**: Use a different LLM to review the code before human review.

**Why?** Different LLMs catch different issues due to different training data and biases.

**How to Review**:
1. Check automated gates passed (tests, linting, security)
2. Use **different LLM** for review (e.g., if Claude wrote it, use another model to review)
3. Apply risk-based review depth (see below)
4. Focus human review on high-risk areas

### Risk-Based Review Depth

| Risk Level | Examples | Review Approach | Reviewers |
|------------|----------|-----------------|-----------|
| **Critical** | Auth, payment, PII | Deep review | 2 humans + AI |
| **High** | Business logic, APIs | Standard review | 1 human + AI |
| **Medium** | Utilities, helpers | AI + spot check | AI + 1 human |
| **Low** | Tests, docs, config | Automated only | AI tools |

### Focus Areas by Risk

**Critical & High Risk**:
1. **Logic Correctness**: Trace execution paths
2. **Security**: OWASP Top 10, input validation
3. **Edge Cases**: Empty inputs, null values, boundaries
4. **Error Handling**: Comprehensive exception handling
5. **Hallucinations**: Verify all imports/APIs exist
6. **Performance**: Algorithm complexity, database queries

**Medium & Low Risk**:
1. **Automated gates**: Did they pass?
2. **AI review results**: Any issues found?
3. **Spot check**: Sample 20% for medium risk
4. **Approve**: If gates pass for low risk

### Approval Criteria
- [ ] All checklist items completed
- [ ] Automated gates passed (tests, linting, security)
- [ ] AI review completed (if applicable)
- [ ] Human review appropriate for risk level
- [ ] No critical issues identified

---

**Reviewer**: Please leave comments using the GitHub review feature.
**Author**: Please resolve all comments before merging.

See the [Kanban Workflow Guide](https://github.com/infiquetra/infiquetra-sdlc/blob/main/docs/process/kanban-workflow.md) for complete process.
