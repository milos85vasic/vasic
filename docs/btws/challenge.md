# Challenge question

> **Describe the most challenging technical problem you have faced in frontend
> development. How did you solve it?**

---

## The answer

The hardest frontend problem I have worked on was not a rendering bug or a
performance cliff. It was a **state-modelling error that made the interface lie
to the user** — and the reason it was hard is that everything about it looked
correct, including the tests.

### The symptom

We had a learning platform where content is organised into sections. If you
navigated to a section that did not exist — a typo in the URL, a stale bookmark
— the page rendered:

> *"This section exists and holds no documents yet. That is the server's
> determined answer."*

That sentence is confident, specific, and wrong. The server had returned
**404 `section_not_found`**. The UI took a denial and reported it as an
existence claim.

Worse, it rendered **identically** for a section that genuinely existed and was
genuinely empty. Two different truths, one screen. A user could not tell them
apart, and neither could we from a screenshot.

### Why it survived so long

This is the part I find most instructive. Nothing was broken in the way tooling
recognises:

- **No error was thrown.** The request completed. The component rendered.
- **The tests passed** — they asserted the empty state rendered, and it did.
- **No console error, no failed request** in any monitoring we had.
- The copy was *well written*. Somebody had taken care over that sentence, which
  made it read as deliberate rather than accidental.

The defect was one line, in a service:

```ts
// section-api.ts
catchError(err => err.status === 404 ? of(empty()) : throwError(err))
```

Mapping 404 to an empty result is an extremely common idiom. In most contexts it
is even correct — "no rows matched" and "nothing here" are often the same thing
to a user. The failure was that in this domain they emphatically were not.

### The root cause, stated properly

**The view model had two states where the domain has three.**

We modelled `loading | content | empty`. But an absent resource is not an empty
one:

| domain state | what the user should be told |
|---|---|
| **present, populated** | here is the content |
| **present, empty** | this exists; there is nothing in it yet |
| **absent** | there is no such thing |

Collapsing *absent* into *empty* is a lossy cast, and lossy casts do not announce
themselves. Once the information is discarded at the service boundary, no amount
of care in the component can recover it — the component was doing its best with
a model that had already thrown the answer away.

### How I solved it

Not by patching the message. Patching the message would have produced
*"This section may exist"*, which is worse — hedged copy is how a UI apologises
for a model it has not fixed.

1. **Reproduced it first, on the running system**, before touching code. I
   confirmed the server really did return 404 and that the UI really did render
   an existence claim. It matters to establish that the mechanism you are about
   to fix is the mechanism that is actually firing — I have been wrong about that
   often enough to stop assuming.

2. **Added the missing state to the model.** A distinct `absent` state,
   propagated from the service through the view model to the template. The type
   system then found every place that had been silently assuming two states.

3. **Made the states visually and semantically distinct.** A typo now reads
   *"There is no section by that name."* An existing-but-empty section keeps its
   original copy, which was always correct for that case.

4. **Wrote the test that would have caught it** — not a test that the empty
   state renders, but a test that a 404 and an empty-but-present response render
   *differently*. That is the assertion that had been missing. A test asserting
   "the empty state renders" passes in both worlds, which is why it never
   flagged anything.

### What I took from it

**A passing test is evidence about the property it tests, and nothing else.**
Ours asserted that an empty state renders. It did. It said nothing about whether
that state was the *right* one, because nobody had encoded that question.

The general form of the bug — and I now look for it deliberately — is **an error
path collapsed into a success path because the two happen to look alike in the
happy case.** `catch → default value` is the most common shape. Every one of
them is a place where the interface may end up asserting something the server
never said.

And a smaller lesson I did not expect: **well-written copy can hide a bug longer
than bad copy would.** If that message had read `Error: no data`, someone would
have investigated in week one. Because it read as a considered editorial
statement, it survived. Polish is not evidence of correctness.

---

## A second one, if you want a shorter example

On the same product, filter controls shipped and immediately produced **33px of
horizontal overflow at 375px** — but only after you typed a query, because the
filters render on results arriving. Every prior mobile check had passed, because
nobody had scrolled a *populated* page on a phone.

The cause was a browser default almost nobody knows: **`<fieldset>` has
`min-inline-size: min-content`**, not `auto` like every other block element. It
therefore refused to shrink below the widest `<option>` in a `<select>` it
contained — a string the layout could not see and the CSS never mentioned.

The fix is one declaration. Finding it took bisecting the DOM by hand, because
`overflow-x` at the page level tells you *that* something is too wide and never
*what*. What made it tractable was measuring page-level overflow as a number
across every route and mode, rather than eyeballing screenshots — a metric that
is either zero or not, and points you at the route to open.
