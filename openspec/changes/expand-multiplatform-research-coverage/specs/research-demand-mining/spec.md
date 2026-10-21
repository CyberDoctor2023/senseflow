# Research Demand Mining Spec Delta

## ADDED Requirements

### Requirement: Project-local round-tracked research run

The workflow SHALL create a project-local PM research run that tracks collection scope, round status, and output locations for each requested platform.

#### Scenario: Operator initializes a multi-platform research expansion run
- **WHEN** a user requests an expanded PM research pass
- **THEN** the workflow SHALL create or update a run under the project `out/` directory
- **AND** the run SHALL contain a round tracker and collection plan
- **AND** the run SHALL preserve platform-specific raw outputs instead of collapsing them into one opaque export

### Requirement: Requested coverage targets must be reported transparently

The workflow SHALL report the achieved coverage for each requested source and explicitly distinguish completed coverage from blocked or partial coverage.

#### Scenario: Reddit expansion is requested toward 2000 raw items
- **WHEN** the operator extends Reddit collection for the active run
- **THEN** the workflow SHALL record the achieved Reddit raw count
- **AND** it SHALL state whether the 2000-item target was reached
- **AND** it SHALL preserve failure notes or stop conditions when the target is not reached

### Requirement: Competitor issue evidence must remain separately attributable

The workflow SHALL collect competitor GitHub issue evidence in a way that keeps it distinguishable from target-product evidence.

#### Scenario: PasteNow and Deck issue research is requested
- **WHEN** competitor GitHub issue collection is run
- **THEN** the workflow SHALL output traceable repo-scoped data for each competitor
- **AND** coverage summaries SHALL identify which findings come from competitor issue trackers
- **AND** downstream analysis SHALL be able to keep competitor signals separate from target-product user pain
