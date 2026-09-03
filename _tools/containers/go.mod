// Consumer module for the canonical Containers Submodule.
//
// §11.4.76(2) prescribes exactly this shape: the submodule enters the project
// as a gitlink, and Go code consumes it during development through a `replace`
// onto that gitlink's path. This tree places its submodules under
// `submodules/`, so the replace target is `../../submodules/containers` rather
// than the `./containers` the constitution's own examples use — both layouts
// are supported, and this one matches the repository's convention.
//
// Production builds resolve the same module through the commit SHA pinned in
// the umbrella's helix-deps.yaml (`deps[].name == containers`), which cascade
// check C9 keeps equal to the live gitlink.
module vasic.digital/tools/containers

go 1.26

require digital.vasic.containers v0.0.0

replace digital.vasic.containers => ../../submodules/containers
