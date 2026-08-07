VIEWBOX: 0 0 960 680
TITLE: `<text class="h" x="32" y="44">HelixCluster — seven-layer stack</text>`

ANNOTATIONS (x, y, class, text):
- 40, 88, lbl, "14 control-plane"
- 40, 106, lbl, "microservices"
- 40, 548, lbl, "heterogeneous"
- 40, 566, lbl, "nodes T1–T8"
- 210, 632, note, "Node tiers T1 (datacenter GPU) → T8 (handheld), unified under one control plane"

BOXES (x, y, w, h, class, title, sub):
- 210, 78, 560, 54, box, "L7 · Federation & Observability", ""
- 210, 140, 560, 54, box, "L6 · Security & Attestation (SPIFFE, PQ-E2EE)", ""
- 210, 202, 560, 54, box, "L5 · Sessions & Interactive Terminal", ""
- 210, 264, 560, 54, box, "L4 · AI Inference Routing", ""
- 210, 326, 560, 54, accent, "L3 · Omega Scheduler (two-level)", ""
- 210, 388, 560, 54, box, "L2 · Consensus & Membership (Raft + SWIM)", ""
- 210, 450, 560, 54, box, "L1 · Node Runtime & Transport (gRPC, WireGuard)", ""
- 210, 512, 560, 54, box, "L0 · Hardware Substrate (GPU → edge SBC)", ""

CONNECTORS: none
