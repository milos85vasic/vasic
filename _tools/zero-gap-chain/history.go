package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/vasic-digital/continuum/pkg/anchor"
	"github.com/vasic-digital/continuum/pkg/chain"
	"github.com/vasic-digital/continuum/pkg/hash"
)

// History verdicts.
const (
	HistHolds         = "HOLDS"
	HistViolated      = "VIOLATED"
	HistUndetermined  = "UNDETERMINED"
	HistNotApplicable = "NOT_APPLICABLE"
	HistUnwitnessed   = "UNWITNESSED"
)

// HistoryResult is the per-commit forward-only verdict for a tracked anchor.
type HistoryResult struct {
	Verdict string
	Lines   []string
}

// VerifyAnchorHistory is the git-history verifier (data-model.md AnchorRecord,
// research D6). The anchor is a tracked file, and an ordinary commit CAN rewrite
// it without any force-push; `anchor verify` only ever sees the CURRENT file.
// So every committed version is walked, oldest first, and it asserts PER COMMIT:
//
//   - entry_count never drops between consecutive versions (a drop is the
//     tail-truncation signature recorded in history);
//   - an equal entry_count never changes head_digest (a history rewrite);
//   - every version's head_digest equals the upstream digest of the chain
//     record at that position in the CURRENT chain (so a delete+re-chain that
//     was later re-anchored is still caught by the older anchors).
//
// It deliberately does NOT assert "no line was ever rewritten": every
// legitimate anchor write rewrites the file.
// HistoryOptions selects the witness (review T015c). Remote "" means the
// fixed default `origin`; an explicit Remote must be a configured remote of
// the repository, else the verdict is UNDETERMINED (refused, never guessed).
type HistoryOptions struct {
	Remote         string
	RemoteExplicit bool
}

// VerifyAnchorHistory verifies with the default witness remote.
func VerifyAnchorHistory(chainPath, anchorPath string) HistoryResult {
	return VerifyAnchorHistoryWith(chainPath, anchorPath, HistoryOptions{})
}

// VerifyAnchorHistoryWith is VerifyAnchorHistory with an explicit witness.
func VerifyAnchorHistoryWith(chainPath, anchorPath string, opt HistoryOptions) HistoryResult {
	res := HistoryResult{}
	say := func(f string, a ...any) { res.Lines = append(res.Lines, fmt.Sprintf(f, a...)) }
	undet := func(f string, a ...any) HistoryResult {
		say(f, a...)
		res.Verdict = HistUndetermined
		return res
	}
	if _, err := exec.LookPath("git"); err != nil {
		return undet("git is not available, so the anchor's history cannot be read")
	}
	abs, err := filepath.Abs(anchorPath)
	if err != nil {
		return undet("resolving the anchor path: %v", err)
	}
	dir, base := filepath.Dir(abs), filepath.Base(abs)
	if _, err := os.Stat(dir); err != nil {
		return undet("anchor directory unreachable: %v", err)
	}
	if out, err := git(dir, "rev-parse", "--is-inside-work-tree"); err != nil || strings.TrimSpace(out) != "true" {
		res.Verdict = HistNotApplicable
		say("the anchor is not inside a git work tree, so it has no committed history to check")
		return res
	}
	top, err := git(dir, "rev-parse", "--show-toplevel")
	if err != nil {
		return undet("git rev-parse --show-toplevel: %v", err)
	}
	top = strings.TrimSpace(top)
	full, err := git(dir, "ls-files", "--full-name", "--error-unmatch", "--", base)
	if err != nil {
		res.Verdict = HistNotApplicable
		say("the anchor is not tracked by git, so it has no committed history to check")
		return res
	}
	full = strings.TrimSpace(full)
	// A repository with no commit at all makes `git log` exit 128; that is
	// "never committed", not "could not read" (found by the staged-anchor test).
	if _, err := git(top, "rev-parse", "--verify", "--quiet", "HEAD"); err != nil {
		res.Verdict = HistNotApplicable
		say("the anchor %s is tracked but the repository has no commit yet", full)
		return res
	}
	// --full-history: default history simplification drops a side-branch
	// commit whose merge is TREESAME to the main parent, which would hide an
	// anchor lowered on that branch (review finding 10).
	logOut, err := git(top, "rev-list", "--full-history", "--topo-order", "--reverse", "HEAD", "--", full)
	if err != nil {
		return undet("git rev-list of %s: %v", full, err)
	}
	commits := strings.Fields(logOut)
	if len(commits) == 0 {
		res.Verdict = HistNotApplicable
		say("the anchor %s is tracked but has never been committed", full)
		return res
	}

	cb, err := os.ReadFile(chainPath)
	if err != nil {
		return undet("chain unreadable, so historical anchors cannot be compared with it: %v", err)
	}
	recs, err := chain.Decode(cb)
	if err != nil {
		return undet("chain is not walkable: %v", err)
	}

	violated := false
	bad := func(f string, a ...any) { violated = true; say("VIOLATED "+f, a...) }
	type version struct {
		present bool
		raw     []byte
		a       anchor.Anchor
		perr    error
	}
	cache := map[string]*version{}
	at := func(c string) (*version, error) {
		if v, ok := cache[c]; ok {
			return v, nil
		}
		v := &version{}
		if _, err := git(top, "cat-file", "-e", c+":"+full); err == nil {
			body, err := git(top, "show", c+":"+full)
			if err != nil {
				return nil, err
			}
			v.present, v.raw = true, []byte(body)
			v.a, v.perr = parseAnchor(v.raw)
		}
		cache[c] = v
		return v, nil
	}
	forward := func(label string, from, to anchor.Anchor, fromLabel string) {
		if to.EntryCount < from.EntryCount {
			bad("%s: entry_count dropped from %d (%s) to %d", label, from.EntryCount, fromLabel, to.EntryCount)
		} else if to.EntryCount == from.EntryCount && to.HeadDigest != from.HeadDigest {
			bad("%s: entry_count %d re-anchored to a DIFFERENT head than %s (%s -> %s): history rewrite", label, to.EntryCount, fromLabel, hash.Short(from.HeadDigest, 12), hash.Short(to.HeadDigest, 12))
		}
	}
	matches := func(label string, a anchor.Anchor) {
		if a.EntryCount > len(recs) {
			bad("%s: anchored %d entries but the current chain holds only %d (records were removed)", label, a.EntryCount, len(recs))
			return
		}
		d, err := chain.Digest(recs[a.EntryCount-1])
		if err != nil {
			bad("%s: chain record %d cannot be digested: %v", label, a.EntryCount, err)
			return
		}
		if d != a.HeadDigest {
			bad("%s: head_digest %s is not the digest of chain record %d (%s) — the chain before that point was rewritten", label, hash.Short(a.HeadDigest, 12), a.EntryCount, hash.Short(d, 12))
			return
		}
		say("ok %s: entry_count=%d head=%s matches the current chain", label, a.EntryCount, hash.Short(a.HeadDigest, 12))
	}
	// Every commit that touched the anchor is compared with EACH of its
	// parents (forward-only per DAG edge), never with a neighbour in a
	// flattened order, which would be meaningless across branches.
	for _, c := range commits {
		label := "commit " + c[:12]
		v, err := at(c)
		if err != nil {
			return undet("reading the anchor at %s: %v", label, err)
		}
		po, err := git(top, "rev-parse", c+"^@")
		if err != nil {
			return undet("parents of %s: %v", label, err)
		}
		for _, p := range strings.Fields(po) {
			pv, err := at(p)
			if err != nil {
				return undet("reading the anchor at parent %s: %v", p[:12], err)
			}
			if !pv.present || pv.perr != nil {
				continue
			}
			if !v.present {
				bad("%s DELETED the anchor file its parent %s held — a later anchor could restart the count from nothing", label, p[:12])
				continue
			}
			if v.perr == nil {
				forward(label, pv.a, v.a, "parent "+p[:12])
			}
		}
		if v.present && v.perr != nil {
			bad("%s holds an anchor file that is not an anchor record: %v", label, v.perr)
		} else if v.present {
			matches(label, v.a)
		}
	}
	head, err := at("HEAD")
	if err != nil {
		return undet("reading the anchor at HEAD: %v", err)
	}
	if wt, err := os.ReadFile(abs); err == nil && !(head.present && bytes.Equal(wt, head.raw)) {
		a, perr := parseAnchor(wt)
		switch {
		case perr != nil:
			bad("the working-tree anchor is not an anchor record: %v", perr)
		default:
			if head.present && head.perr == nil {
				forward("working tree", head.a, a, "HEAD")
			}
			matches("working tree", a)
		}
	}
	// Witness (review T015b I3, T015c). Every check above compares the
	// repository with ITSELF, so an amended/rebased/reset commit that lowers
	// the anchor leaves no edge to see. A copy held ELSEWHERE is fetched now
	// — never read from a local ref: a remote-tracking ref (`update-ref`) and
	// the upstream setting (`branch -u`) are both forgeable locally. The
	// remote is fixed (`origin`, or an explicit, configured name), the branch
	// is HEAD's, and the fetch lands in a private ref namespace. The fetched
	// tip must be an ancestor of HEAD, and its anchor must still hold against
	// the current chain and never be above the current anchor.
	unwitnessed := false
	unwit := func(f string, a ...any) { unwitnessed = true; say("UNWITNESSED "+f, a...) }
	remote := opt.Remote
	if remote == "" {
		remote = "origin"
	}
	remotes, err := git(top, "remote")
	if err != nil {
		return undet("git remote: %v", err)
	}
	configured := false
	for _, r := range strings.Fields(remotes) {
		configured = configured || r == remote
	}
	branch, berr := git(top, "symbolic-ref", "--quiet", "--short", "HEAD")
	branch = strings.TrimSpace(branch)
	switch {
	case !configured && opt.RemoteExplicit:
		return undet("the explicit witness remote %q is not a configured remote of this repository (refused)", remote)
	case !configured:
		unwit("no remote named %q: the committed anchor history is witnessed by no copy held elsewhere (an amended commit would be invisible)", remote)
	case berr != nil || branch == "":
		unwit("HEAD is detached, so there is no branch whose remote copy could witness it")
	default:
		url, _ := git(top, "remote", "get-url", remote)
		say("witness remote %q (%s) branch %q, fetched now — local remote-tracking refs are not trusted", remote, redactURL(strings.TrimSpace(url)), branch)
		ref := "refs/zero-gap/witness/" + remote + "/" + branch
		if _, err := gitFetch(top, remote, "+refs/heads/"+branch+":"+ref); err != nil {
			unwit("the witness remote %q could not be fetched (unreachable, no such branch, or authentication failed): %v", remote, err)
			break
		}
		up, err := git(top, "rev-parse", "--verify", "--quiet", ref)
		if err != nil {
			unwit("the fetched witness ref %s cannot be resolved", ref)
			break
		}
		up = strings.TrimSpace(up)
		ul := "witness " + remote + "/" + branch + " " + up[:12]
		if _, err := git(top, "merge-base", "--is-ancestor", up, "HEAD"); err != nil {
			unwit("%s is NOT an ancestor of HEAD: pushed history was rewritten (amend, rebase, reset) or the remote diverged", ul)
		}
		rv, err := at(up)
		if err != nil {
			return undet("reading the anchor at %s: %v", ul, err)
		}
		if rv.present && rv.perr == nil {
			matches(ul, rv.a)
			cur, curLabel := head, "HEAD"
			if wt, err := os.ReadFile(abs); err == nil {
				if a, perr := parseAnchor(wt); perr == nil {
					cur = &version{present: true, raw: wt, a: a}
					curLabel = "working tree"
				}
			}
			if cur.present && cur.perr == nil {
				forward(curLabel, rv.a, cur.a, ul)
			}
		} else if rv.present {
			bad("%s holds an anchor file that is not an anchor record: %v", ul, rv.perr)
		}
	}
	switch {
	case violated:
		res.Verdict = HistViolated
	case unwitnessed:
		res.Verdict = HistUnwitnessed
	default:
		res.Verdict = HistHolds
	}
	return res
}

func parseAnchor(b []byte) (anchor.Anchor, error) {
	var a anchor.Anchor
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&a); err != nil {
		return a, err
	}
	if dec.More() {
		return a, errors.New("more than one JSON value")
	}
	return a, anchor.Validate(a)
}

// redactURL drops any userinfo from a remote URL (`https://user:token@host/…`
// and the token-only `https://TOKEN@host/…`) and blanks the value of every
// query parameter whose name is secret-shaped (`?access_token=`, `?token=`,
// `?key=`, `?private_token=` …) before the URL is printed (§11.4.10).
func redactURL(u string) string {
	if i := strings.Index(u, "://"); i >= 0 {
		rest := u[i+3:]
		if at := strings.LastIndex(strings.SplitN(rest, "/", 2)[0], "@"); at >= 0 {
			u = u[:i+3] + "<redacted>@" + rest[at+1:]
		}
	}
	q := strings.IndexByte(u, '?')
	if q < 0 {
		return u
	}
	query, frag := u[q+1:], ""
	if h := strings.IndexByte(query, '#'); h >= 0 {
		query, frag = query[:h], query[h:]
	}
	params := strings.Split(query, "&")
	for i, p := range params {
		if eq := strings.IndexByte(p, '='); eq >= 0 && secretName(p[:eq]) {
			params[i] = p[:eq] + "=<redacted>"
		}
	}
	return u[:q+1] + strings.Join(params, "&") + frag
}

// Environment variables that redirect git's configuration (and through it
// hooks, URL rewrites, helpers) from OUTSIDE the repository; the witness fetch
// drops them so a caller's environment cannot steer it (review T015d F3).
var gitConfigEnvPrefixes = []string{
	"GIT_CONFIG_COUNT=", "GIT_CONFIG_KEY_", "GIT_CONFIG_VALUE_", "GIT_CONFIG_GLOBAL=",
	"GIT_CONFIG_SYSTEM=", "GIT_CONFIG_PARAMETERS=",
}

func fetchEnv() []string {
	var env []string
	for _, e := range os.Environ() {
		drop := false
		for _, p := range gitConfigEnvPrefixes {
			if strings.HasPrefix(e, p) {
				drop = true
				break
			}
		}
		if !drop {
			env = append(env, e)
		}
	}
	return append(env,
		"GIT_TERMINAL_PROMPT=0", "GIT_ASKPASS=/bin/false", "SSH_ASKPASS=/bin/false",
		// Transports: `file` (this repository's proofs and any local mirror),
		// `https` and `ssh` only. `ext` (an arbitrary program), `fd`, `git`
		// and cleartext `http` are refused whatever protocol.*.allow says —
		// the environment variable takes precedence over that config.
		"GIT_ALLOW_PROTOCOL=file:https:ssh")
}

// gitFetch fetches one refspec with prompts disabled, hooks pinned off, the
// transport set restricted, the config-redirecting environment dropped and a
// bounded time, so an unreachable, credential-requiring or forbidden remote
// fails (UNWITNESSED), never hangs and never executes anything on this host.
// RESIDUAL: the repository's own and the user's global config still apply
// (`url.<x>.insteadOf`, `core.sshCommand`, `credential.helper`), as do
// GIT_SSH_COMMAND / GIT_PROXY_COMMAND / GIT_EXEC_PATH / PATH and the REMOTE
// repository's upload-pack configuration.
func gitFetch(dir, remote, refspec string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "git", "-C", dir, "-c", "core.hooksPath=/dev/null",
		"fetch", "--quiet", "--no-tags", "--no-write-fetch-head", remote, refspec)
	cmd.Env = fetchEnv()
	var out, errb bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &errb
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("%v: %s", err, redactURL(strings.TrimSpace(errb.String())))
	}
	return out.String(), nil
}

func git(dir string, args ...string) (string, error) {
	cmd := exec.Command("git", append([]string{"-C", dir}, args...)...)
	var out, errb bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &errb
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("%v: %s", err, strings.TrimSpace(errb.String()))
	}
	return out.String(), nil
}
