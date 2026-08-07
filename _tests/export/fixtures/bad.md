% Release Readiness Report
% Platform Team
% 2026-08-05

# Overview

This report was exported incorrectly: the diagram source was never rendered
and leaked into the document body as raw text.

```mermaid
gantt
    title Release schedule
    dateFormat  YYYY-MM-DD
    section Foundation
    Design      :done,    des1, 2026-06-01, 2026-06-10
    Build       :active,  bld1, 2026-06-11, 2026-06-25
    section Hardening
    QA          :crit,    qa1,  2026-06-26, 2026-07-05
```

# Milestone status

The table below was truncated during export and is missing its final rows.

| Milestone      | Owner   | Units | Status   |
|----------------|---------|-------|----------|
| Foundation     | Ana     | 42    | Done     |
| Integration    | Bora    | 88    | Done     |
