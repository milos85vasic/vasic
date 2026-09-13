# T012 Review Record — Grammar and Derivations

**Spec**: 003-chapter-hierarchy
**Task**: T012 [REVIEW] Review the grammar and the derivations before anything consumes them
**Date**: 2026-09-09
**Result**: PASS

## Grammar Reviewed

`ChapterIDGrammar = ^[0-9]{2,}(\.[0-9]{2,})*$` at `pkg/curriculum/chapterid.go:58`.

- Matches the spec definition in `specs/003-chapter-hierarchy/data-model.md` §1
- Two zero-padded numeric components separated by dots
- Minimum two digits per component
- Any number of additional dot-separated components

## Derivations Reviewed

All derivations in `pkg/curriculum/chapterid.go` are pure string operations on the id alone:

| Function | Derives | From |
|----------|---------|------|
| `ParentID` | Parent chapter id | `id` string |
| `Depth` | Nesting depth | `id` string |
| `AncestorIDs` | All ancestor ids | `id` string |
| `OrdinalPath` | Zero-padded numeric path | `id` string |

None of these functions reads from a database, file, or external source. They operate solely on the id string.

## Test Coverage

- `TestGCH1_Grammar` — table-driven, accepts/rejects correctly
- `TestOrdering_ByteLexicographicIsTheWholeRule` — ordering rule verified
- `TestOrdering_UnpaddedWouldSortWrong` — documents why unpadded ids break
- `TestDerivations_FallOutOfTheID` — all four derivations including root case
- `TestChildIDsAndOrphaned` — child identification and orphan detection
- `TestSafeSlug_IsNotTheChapterGrammar` — boundary between SafeSlug and ChapterID
- `TestGCH5_ChapterDirResolvesDottedId` — ChapterDir with dotted id
- `TestGCH5_SourceFilenameShapeRejectsChapterId` — HasSourceFilenameShape does not match

## Conclusion

The grammar is correct, consistent with the spec, and fully tested. The derivations are pure and unstored by construction. No further review needed.
