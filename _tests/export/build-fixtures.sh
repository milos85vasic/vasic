#!/usr/bin/env bash
# Build golden PDF fixtures via a small pandoc -> weasyprint build.
#  golden-good.pdf : clean, faithful, embeds a raster figure, complete table.
#  golden-bad.pdf  : deliberately seeded with raw ```mermaid gantt``` source
#                    leaking as body text + a TRUNCATED table + no figure.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
FIX="$HERE/fixtures"
mkdir -p "$FIX"

# 1) raster image for the good PDF (so pdfimages finds an embedded image)
node "$HERE/make-image.js" "$FIX/figure.png"

# 2) GOOD markdown — clean prose, complete table, embedded figure, NO markup leak
cat > "$FIX/good.md" <<'EOF'
% Release Readiness Report
% Platform Team
% 2026-08-05

# Overview

This report summarises the readiness of the platform for the upcoming
release. All planned workstreams have completed and quality checks passed.
The throughput figure below is rendered as an embedded raster image.

![Quarterly throughput](figure.png)

# Milestone status

The table below is complete and lists every milestone with its final state.

| Milestone      | Owner   | Units | Status   |
|----------------|---------|-------|----------|
| Foundation     | Ana     | 42    | Done     |
| Integration    | Bora    | 88    | Done     |
| Hardening      | Chen    | 121   | Done     |
| Release Q4     | Dilan   | 128   | Shipped  |

# Conclusion

Every milestone reached its final state and the release is approved.
The last milestone, Release Q4, is marked Shipped, confirming the table
was exported in full without truncation.
EOF

# 3) BAD markdown — raw mermaid gantt source leaking as body text + truncated table
cat > "$FIX/bad.md" <<'EOF'
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
EOF

# 4) render both via pandoc -> weasyprint
build() {
  local md="$1" pdf="$2"
  pandoc "$md" --from markdown --to pdf --pdf-engine=weasyprint \
    --resource-path="$FIX" -o "$pdf"
  echo "built $pdf"
}
build "$FIX/good.md" "$FIX/golden-good.pdf"
build "$FIX/bad.md"  "$FIX/golden-bad.pdf"

echo "OK fixtures ready in $FIX"
