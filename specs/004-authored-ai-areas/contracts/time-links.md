# Contract — Video anchor URLs

```
/chapters/<slug>[/transcript][?t=<seconds>][&end=<seconds>][#p-<pid>]
```

Authority: `workshop/platform/frontend/docs/time-links.md`. The producer is
written against that document; it is not a convention.

## Producer rules

Each prevents a link that **looks fine and is broken**:

1. `end` is emitted **only when `> t`**. The documented consumer ignores a
   malformed span, so producing one yields a link that renders correctly and
   does nothing.
2. `#p-` is emitted **only for a Crockford-shaped ULID**. The grammar reserves
   that prefix.
3. A chapter the server does not serve gets `href: null`, a stated
   `unresolved_reason`, its `transcript_anchor` intact, and an
   `unresolved_video_links` count. **No link is ever invented.**

Millisecond → decimal-second conversion happens **once**, at the producer.

## Consumer obligations

On following an anchor: position the player at `t`; scroll the transcript so the
`#p-` passage is in view **without further scrolling**; visually distinguish that
passage; make the extent of the range discernible when `end` is present.

An unresolvable target tells the learner it is unavailable — never a page
reporting nothing found.

## Source of the times

`start_millis` comes from the **transcript segment sidecar**, joined on passage
id. The passage registry carries **only an end time**, so a start derived from
it alone would be invented.

Verified live: `/chapters/01/transcript?end=602&t=512.4#p-<ulid>`

Measured: **205 spans**, **479 contract-conformant links** across 37 documents —
against **zero** links in the 12 pre-existing documents before this work.
