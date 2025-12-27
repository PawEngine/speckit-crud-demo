<!--
Sync Impact Report
- Version change: unversioned → 1.0.0
- Modified principles:
	- Code Quality Discipline (NON-NEGOTIABLE)
	- Testing Standards (TDD + Coverage Gates)
	- User Experience Consistency
	- Performance Requirements & Budgets
- Added sections:
	- AWS Tech Stack & Constraints
	- Development Process
	- Documentation Standards
	- Quality Gates & Compliance
- Removed sections:
	- Principle 5 placeholder (out of scope)
- Templates requiring updates:
	- ✅ .specify/templates/tasks-template.md (tests mandatory; add Phase 0 AWS CLI)
	- ✅ .specify/templates/plan-template.md (explicit Constitution Check)
	- ⚠ README.md / docs (Quickstart recommended)
- Deferred TODOs:
	- TODO(RATIFICATION_DATE): original adoption date unknown; confirm and set
-->

# Speckit CRUD Demo Constitution

## Core Principles

### Code Quality Discipline (NON-NEGOTIABLE)
MUST enforce a consistent, automated quality baseline:
- Linting and formatting MUST run pre-commit and in CI.
- Static analysis MUST be enabled and errors treated as blockers.
- Code reviews REQUIRED: at least one reviewer for all PRs.
- Maintainability: files SHOULD remain under 300 lines; cyclomatic
	complexity MUST be justified in PR description if >10.
- Dependency hygiene: pin versions; remove unused packages; no
	vendored code without rationale.
- Source comments: include Japanese comments explaining intent and usage.

Rationale: High-quality code improves reliability, onboarding speed, and
feature velocity while reducing regressions.

### Testing Standards (TDD + Coverage Gates)
MUST adopt tests-first discipline with measurable coverage:
- Write tests BEFORE implementation; ensure they FAIL initially.
- Test suites MUST include unit, integration, and contract tests where
	applicable.
- Coverage gates: unit ≥ 80%, integration ≥ 70% per changed packages.
- Tests MUST be deterministic and fast; flaky tests block merges.
- CI MUST fail on coverage or test failures; performance tests included
	when changes touch critical paths.

Rationale: TDD and strong coverage create safe change velocity and
document behavior.

### User Experience Consistency
MUST deliver predictable, accessible, and coherent user journeys:
- Use a shared component library and design tokens; avoid one-off UI.
- Accessibility: meet WCAG 2.1 AA for interactive flows.
- Copy standards: concise, actionable, consistent terminology.
- Error handling: clear recovery actions; avoid ambiguous messages.
- Internationalization-ready: no hard-coded strings that block i18n.

Rationale: Consistency reduces user friction and support costs.

### Performance Requirements & Budgets
MUST meet defined performance budgets and verify continuously:
- Latency: p95 < 200ms for CRUD operations on typical payloads.
- Throughput: sustain 100 req/s baseline without degradation.
- Resource: steady-state memory footprint < 150MB for service process.
- CI MUST include profiling or benchmarks on critical paths.
- Any performance regression >5% MUST be investigated before merge.

Rationale: Predictable performance preserves UX quality under load.

<!-- Principle 5 intentionally removed per requested scope -->

## AWS Tech Stack & Constraints
MUST use the following platform and constraints:
- Cloud Provider: AWS (Amazon Web Services).
- Infrastructure: AWS CLI commands ONLY (no Terraform, CloudFormation,
	AWS CDK, or AWS Console UI).
- Architecture: Serverless.
	- Compute: AWS Lambda (Python 3.10+ or Node.js 20+).
	- Database: Amazon DynamoDB.
	- API: Amazon API Gateway (REST API or HTTP API).
- Authentication: not implemented for now (public access).

## Development Process
MUST follow process steps before implementation:
- CLI-first: present AWS CLI resource creation steps BEFORE writing code.
- Commands MUST be copy-paste runnable (shell script style) and include
	Japanese `#` comments describing intent.
- Idempotency and cleanup: provide delete commands for created resources
	(e.g., delete-function, delete-table) as part of docs.
- Scripts: deliver runnable `sh` shell scripts for provisioning and ops.
- Code readability: include Japanese comments for clarity; implement
	proper error handling (e.g., DynamoDB connection errors).

## Documentation Standards
MUST provide beginner-friendly specifications and step-by-step guides:
- Write clear Quickstart and deployment steps.
- Include prerequisites and environment setup (AWS CLI configuration).
- Document rollback and cleanup commands for resources.

## Quality Gates & Compliance
The following gates MUST pass in CI for every PR:
- Quality: lint + format + static analysis pass.
- Tests: unit/integration/contract suites pass; coverage gates met.
- Accessibility (for UI changes): automated checks show no AA violations.
- Performance: benchmarks on critical paths show no >5% regressions.
- Security: dependency scanning shows no HIGH/CRITICAL issues.

## Development Workflow
Workflow MUST reflect the principles above:
- Branching: feature branches `feature/<name>`; small, focused PRs.
- TDD: write failing tests, implement, refactor; document rationale in PR.
- Reviews: at least one approval; reviewers check gates evidence.
- Releases: semantic versioning (MAJOR.MINOR.PATCH); changelog required.
- Documentation: update specs/quickstart when behavior changes.

## Governance
This constitution supersedes other practices where conflicting:
- Amendments: propose via PR with rationale, migration plan, and impact.
- Reviews MUST verify compliance with Quality Gates & principles.
- Breaking changes: require MAJOR version bump with deprecation policy.
- Infrastructure constraint: any IaC deviations (Terraform/CFN/CDK/Console)
	are prohibited and MUST be rejected in review.
- Versioning of this document: semantic; MAJOR for incompatible rule
	changes; MINOR for additions; PATCH for clarifications.

**Version**: 1.0.0 | **Ratified**: TODO(RATIFICATION_DATE) | **Last Amended**: 2025-12-27
<!-- Example: Version: 2.1.1 | Ratified: 2025-06-13 | Last Amended: 2025-07-16 -->
