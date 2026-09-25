// zero-gap-chain — the feature-010 evidence adapter's Go shim (T013/T014).
//
// It exists because the constitution's chain library is Go-only: the recorder
// row -> chain record step is upstream `chain.ExecRow.ToRecord`, and the record
// digest is upstream `chain.Digest`. Both are CALLED here, never re-implemented
// (§11.4.251): a second digest would be a byte-identical fork whose drift stays
// invisible until a digest silently stops matching.
//
// The `replace` points at the continuum module INSIDE this repository (the
// constitution submodule's nested gitlink). Nothing escapes the tree, the
// continuum module has no dependencies of its own, and so no go.sum and no
// network are needed: builds run with GOPROXY=off and GOTOOLCHAIN=local.
module vasic.digital/tools/zero-gap-chain

go 1.22

require github.com/vasic-digital/continuum v0.0.0

replace github.com/vasic-digital/continuum => ../../submodules/constitution/submodules/continuum
