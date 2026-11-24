# Keyless job APIs for job_seeker v1: Remotive, RemoteOK, Himalayas

Access date: 2026-11-24 (live probes on 2026-11-23 23:35 UTC from the dev host). Provider facts below come from the providers' own pages and from live responses, not from memory.

Sources:
- Remotive: https://github.com/remotive-com/remote-jobs-api (official README); the `0-legal-notice` field of the live response; https://remotive.com/api-documentation (named by the notice as the ToS)
- RemoteOK: https://remoteok.com/api (the `legal` field in element 0 of the live response)
- Himalayas: https://himalayas.app/api (docs), https://himalayas.app/terms#api (terms, clauses 113(b)-(f))

Samples (truncated descriptions, no personal data; recruiter names and emails are not present in the captured fields): `samples/remotive_sample.json`, `samples/remoteok_sample.json`, `samples/himalayas_sample.json`.

## 1. Remotive

| Item | Value |
|---|---|
| Endpoint | `GET https://remotive.com/api/remote-jobs` (legacy remotive.io is terminated) |
| Auth | None. A private paid API exists ("starting budget is $5k/mo", per the legal notice) |
| Params (all optional) | `category` (name or slug), `company_name` (case-insensitive partial), `search` (title + description, case-insensitive partial), `limit` (int, default all) |
| Pagination | None. The whole filtered set is returned in one response |
| Envelope | `{"00-warning","0-legal-notice","job-count","total-job-count","jobs":[...]}` |

Job fields (verified from a live record): `id` (int), `url`, `title`, `company_name`, `company_logo`, `company_logo_url`, `category`, `tags` (string[]), `job_type` (e.g. `part_time`, `full_time`, `contract`; optional, often blank), `publication_date` (`2026-11-19T14:58:42`, no timezone designator), `candidate_required_location` (free text such as `USA`, `Worldwide`), `salary` (free-text string such as `$14/hour`; optional), `description` (full HTML; the sample carries heavy inline `style` noise).

Rate limits and politeness (README plus legal notice):
- "we advise max. 4 times a day".
- "excessive requests (more than 2x per minute) will be blocked" (README).
- The legal notice says: "there is absolutely no need to request Remotive Job data too frequently ... a couple of times a day".

ToS (verbatim from the `0-legal-notice` field, 2026-11-23):
> "Please do not submit Remotive jobs to third Party websites, including but not limited to: Jooble, Neuvoo, Google Jobs, LinkedIn Jobs. Please link back to the URL found on Remotive AND mention Remotive as a source in order to Remotive to get traffic from your listing. If you don't do that, we'll terminate your API access, sorry! Jobs displayed are delayed by 24 hours, the goal being that jobs are attributed to Remotive on various platforms. Displaying our jobs in order to collect signups/email addresses to show a listing constitutes a breach of our terms of services."

Caching and storage: no explicit clause. The response carries `cache-control: no-store` but is served via Cloudflare (`cf-cache-status: HIT`, `last-modified: 2026-11-23 16:13:17`, age ~7 h). So the data is a periodically regenerated snapshot. The ToS says jobs are "delayed by 24 hours".

Update frequency: the snapshot refreshes a few times a day (provider statement plus the observed `last-modified`).

Reliability (5 requests, `?limit=5`): HTTP 200 x5, 0.29-0.43 s, 273,509 B each. Observation: `limit=5` still returned 15 jobs with identical bytes on every call. This is UNCONFIRMED as intended behaviour. It is consistent with a cached full snapshot that ignores `limit`, so the adapter must not trust `limit` and should truncate client-side.

Data quality:
- Salary is free-text and optional (11 of 15 records had one). It needs a parser that handles `$14/hour`, ranges, and non-USD.
- Location is free text with no structured timezone.
- Tags are lowercase keywords. `category` is a coarse taxonomy.
- Descriptions are dirty HTML and need sanitising.

## 2. RemoteOK

| Item | Value |
|---|---|
| Endpoint | `GET https://remoteok.com/api` |
| Auth | None. Send a descriptive `User-Agent`. The default curl UA is a known cause of blocks (UNCONFIRMED; we used a custom UA) |
| Params | None documented. Tag filtering by URL (`/api?tag=golang`) is UNVERIFIED and was not tested |
| Pagination | None. About 100 latest jobs per call (101 array elements) |
| Envelope | JSON array. Element 0 is metadata `{"last_updated": <epoch>, "legal": "..."}`. Elements 1..n are jobs |

Job fields (verified from live records): `slug`, `id` (string), `epoch` (int), `date` (ISO 8601 with offset), `company`, `company_logo`, `logo`, `position` (the title), `tags` (string[]), `description` (HTML), `location` (free text, e.g. `US Only`), `apply_url`, `url`, `original` (bool), `salary_min`, `salary_max` (ints, 0 when absent).

Rate limits: the API says nothing. Treat it as 1 to 2 requests per hour at most (our policy, not the provider's). Payload is about 948 KB per call, so be frugal.

ToS (verbatim from the `legal` field, 2026-11-23):
> "API Terms of Service: Please link back (with follow, and without nofollow!) to the URL on Remote OK and mention Remote OK as a source, so we get traffic back from your site. If you do not we'll have to suspend API access.
>
> Please don't use the Remote OK logo without written permission as it's a registered trademark, please DO use our name Remote OK though."

Caching and storage: no clause. `cf-cache-status: DYNAMIC`, so responses are generated live.

Update frequency: the metadata carries `last_updated` (epoch). Freshness is near real-time, since jobs from the same day appear.

Reliability (5 requests): HTTP 200 x5, 0.96-1.28 s, 948,114 B each.

Data quality:
- Salary is structured but rarely filled (2 of 100 had non-zero values).
- Location is free text.
- Tags are good for skill matching.
- The `original` flag marks jobs posted directly on the site.
- `apply_url` equals `url` in the sample, so the apply link points back to RemoteOK.
- The raw description contains mojibake (UTF-8 mis-decoded, e.g. `â\u0080\u0099`). Normalise the text.

## 3. Himalayas

| Item | Value |
|---|---|
| Browse | `GET https://himalayas.app/jobs/api` with `limit` (max 20) and `cursor` (the preferred way; `offset` is deprecated) |
| Search | `GET https://himalayas.app/jobs/api/search` with `q`, `country`, `worldwide`, `exclude_worldwide`, `seniority`, `employment_type`, `company`, `timezone`, `sort`, `page` |
| Single job | `GET /jobs/api/companies/:company/jobs/:slug`: 200 open, 410 closed, 404 none |
| Auth | None required. A free key (`Authorization: Bearer ...`) raises limits to 60 requests per minute and 10,000 per day. Anonymous limits are lower and not published |
| Pagination | Cursor. Pass back `nextCursor` as `?cursor=`. Search paginates by `page` until a page returns no jobs. Pages can be short, so do not stop early. Dedupe on `guid`. `totalCount` is only an estimate |
| Envelope | `{"comments","updatedAt","offset","limit","totalCount","nextCursor","jobs":[...]}` |

Job fields (verified from live records): `title`, `excerpt`, `description` (HTML), `companyName`, `companySlug`, `companyLogo`, `employmentType` (e.g. `Temporary`, `Full Time`), `minSalary`, `maxSalary` (numbers), `salaryPeriod` (`hourly`, `yearly`, ...), `currency` (ISO), `seniority` (string[]), `locationRestrictions` (string[]), `timezoneRestrictions` (UTC offsets as numbers), `categories` (string[]), `parentCategories` (string[]), `guid` (the canonical URL), `pubDate` (epoch seconds, last updated), `expiryDate` (epoch seconds), `applicationLink` (the guid plus `?utm_source=api`).

Rate limits and caching (docs): "Responses are cached for an hour or more, so polling more often gains nothing." Going over the limit returns 429, with `Retry-After` when a key is used. Observed headers: `cache-control: public, max-age=0, s-maxage=7200, stale-while-revalidate=86400`, `cf-cache-status: HIT`, `last-modified` current. There are no CORS headers, so call it from the backend only.

ToS (paraphrased from the docs and terms page; the fetch tool caps quoting):
- Docs: "Use the `applicationLink` unchanged for every Apply button. Show a visible link to the job on Himalayas or to himalayas.app as the source. Display jobs only on sites and apps you operate. Do not pass them on to other job boards, aggregators, Google Jobs or LinkedIn Jobs (including feeds and JobPosting structured data). Remove jobs once they expire."
- Terms clause 113(b), quoted: "Clearly identify Himalayas as the source of the jobs, with a visible link to the Himalayas job or to himalayas.app."
- Clause 113(c), quoted: "Show the jobs only on sites and apps you operate."
- Clause 113(d), quoted: "Cache job data where you can, stay within your request limits, and remove jobs once they expire."
- Clause 113(f), quoted: "We set and may change request limits, and we may suspend keys or accounts that break these terms."

Update frequency: hourly or slower, because of CDN caching of 1 to 2 hours. The `updatedAt` field gives the feed timestamp.

Reliability (5 requests, `?limit=5`): HTTP 200 x5, 0.16-0.48 s, 31,514 B each. The cursor request and `/search?q=golang` also returned 200.

Data quality: the best structure of the three. It has structured salary with period and currency (5 of 5 sampled had one), explicit location and timezone restrictions, and seniority. Its feed is huge (`totalCount` about 120k, an estimate) and includes non-tech roles (the sample is a hotline operator), so the matcher must filter by category and keyword. `guid` is a stable URL.

## 4. Cross-provider comparison

| | Remotive | RemoteOK | Himalayas |
|---|---|---|---|
| Records per call | all (snapshot) | ~100 | 20 per page |
| Salary | free text | min/max ints, rare | min/max/period/currency |
| Location | free text | free text | list plus timezones |
| Tags | tags + category | tags | categories + parentCategories |
| Posted date | no TZ | ISO + epoch | epoch |
| Stable ID | int `id` | string `id` + `slug` | `guid` URL |
| Recommended poll interval | 6 h (limit: 4 per day) | 60 min | 2 h (CDN-cached 1-2 h) |

## 5. Legal and ToS risks (flagged honestly)

1. **Attribution is a hard condition for all three.** Every displayed job needs a visible, followed link back to the provider's own URL (RemoteOK states "follow, and without nofollow") and a named source. Each provider threatens to terminate or suspend API access. The UI and any export must carry provider name and link. Himalayas also says to use `applicationLink` unchanged, which includes its `utm_source=api`.
2. **No re-publication to third parties.** Remotive forbids submitting its jobs to third-party sites (naming Jooble, Neuvoo, Google Jobs and LinkedIn Jobs). Himalayas forbids passing jobs to other boards or aggregators, and JobPosting structured data. job_seeker must therefore be a private or personal tool. If it ever becomes a public aggregator or exposes JobPosting markup, the legal analysis changes and Himalayas and Remotive would likely be violated. This is a legal-interpretation risk and not a legal opinion.
3. **Remotive's 24-hour delay and anti-signup clause.** Remotive jobs are "delayed by 24 hours", and "displaying our jobs in order to collect signups/email addresses" is a breach. A personal matcher does not do that, but a public multi-user product feature would need review.
4. **Remotive rate limit.** The README says max 4 per day and more than 2 per minute is blocked. Do not poll more than 4 times per day, even though the advice is "advise" wording.
5. **Himalayas expiry rule.** Delete or hide jobs after `expiryDate` and check the single-job endpoint (410 means closed). Himalayas says it may change anonymous limits at any time (clause 113(f)). A free key is advisable. Registering for a key is an action for the operator, and none was created here.
6. **RemoteOK logo trademark.** Do not display the RemoteOK logo without written permission. Using the name is fine. Company logos are third-party material and are better hotlinked than stored.
7. **No explicit storage clause for Remotive or RemoteOK.** Storing normalised copies for the user's own matching is the practical need, but this is UNCONFIRMED as permitted. Treat the store as a cache that is refreshed and pruned, and keep the provider URL on every row.
8. **Job description content** is third-party copyrighted text and may contain recruiter contact details. Store it for local matching only, strip HTML, and do not republish it.
9. All three terms can change without notice. Re-read the `legal` and `0-legal-notice` fields in each response at runtime and log a diff when they change.

## 6. Canonical schema (Go sketch)

```go
package model

import "time"

type Provider string

const (
	ProviderRemotive  Provider = "remotive"
	ProviderRemoteOK  Provider = "remoteok"
	ProviderHimalayas Provider = "himalayas"
)

// Provenance records where a posting came from and which terms apply.
type Provenance struct {
	Provider    Provider  `json:"provider"`
	ProviderID  string    `json:"provider_id"`  // remotive id / remoteok id / himalayas guid
	SourceURL   string    `json:"source_url"`   // link-back target, used unchanged for attribution
	ApplyURL    string    `json:"apply_url"`    // himalayas applicationLink must be unchanged
	Attribution string    `json:"attribution"`  // e.g. "via Remotive"
	FetchedAt   time.Time `json:"fetched_at"`
	RawHash     string    `json:"raw_hash"` // sha256 of the raw record, for change detection
}

type SalaryPeriod string

const (
	PeriodUnknown SalaryPeriod = ""
	PeriodHourly  SalaryPeriod = "hourly"
	PeriodMonthly SalaryPeriod = "monthly"
	PeriodYearly  SalaryPeriod = "yearly"
)

type Salary struct {
	Min      *float64     `json:"min,omitempty"`
	Max      *float64     `json:"max,omitempty"`
	Currency string       `json:"currency,omitempty"` // ISO 4217
	Period   SalaryPeriod `json:"period,omitempty"`
	Raw      string       `json:"raw,omitempty"` // original text, e.g. "$14/hour"
}

type Location struct {
	Raw          string   `json:"raw"`                     // provider text, e.g. "US Only"
	Worldwide    bool     `json:"worldwide"`
	Countries    []string `json:"countries,omitempty"`     // ISO 3166 where parseable
	TimezonesUTC []int    `json:"timezones_utc,omitempty"` // himalayas offsets
}

type Posting struct {
	ID          string     `json:"id"`        // = DedupKey (primary canonical hash)
	Title       string     `json:"title"`
	Company     string     `json:"company"`
	CompanyLogo string     `json:"company_logo,omitempty"`
	Description string     `json:"description"` // sanitised text
	DescHTML    string     `json:"-"`           // raw HTML, optional, not displayed
	Category    string     `json:"category,omitempty"`
	Tags        []string   `json:"tags"` // lowercased
	Seniority   []string   `json:"seniority,omitempty"`
	EmployType  string     `json:"employment_type,omitempty"`
	Location    Location   `json:"location"`
	Salary      Salary     `json:"salary"`
	PostedAt    time.Time  `json:"posted_at"`
	ExpiresAt   *time.Time `json:"expires_at,omitempty"` // himalayas expiryDate; prune after it
	FirstSeen   time.Time  `json:"first_seen"`
	LastSeen    time.Time  `json:"last_seen"`
	Closed      bool       `json:"closed"`

	DedupKey   string       `json:"dedup_key"`   // canonical URL hash
	FuzzyKey   string       `json:"fuzzy_key"`   // title+company+location signature
	Provenance []Provenance `json:"provenance"`  // one entry per provider that listed it
}
```

### Dedup strategy

1. **Primary key** `DedupKey = sha256(canonicalURL)`. Canonicalise the apply or source URL by lowercasing the host, dropping fragments and `utm_*`, `ref` and trailing slashes, and resolving the provider's own job URL. Note that RemoteOK returns `remoteOK.com` with mixed case, and Himalayas appends `?utm_source=api` to `applicationLink`. The stored `ApplyURL` stays unchanged for display, and only the key is canonicalised.
2. **Intra-provider identity** is `(provider, ProviderID)`, which drives upserts. If the same provider id returns, update `LastSeen`.
3. **Cross-provider fuzzy key**: `FuzzyKey = sha1(norm(company) | norm(title) | locationBucket)`. `norm` lowercases, strips punctuation, legal suffixes (inc, ltd, llc, gmbh) and seniority or filler words, and collapses spaces. `locationBucket` is `worldwide`, a country code, or a coarse region.
4. Match when the fuzzy key is equal, or when company is equal and title token-set similarity (Jaccard or trigram) is at least 0.85 and `|PostedAt` difference| is at most 14 days. On a match, merge into one `Posting` and append to `Provenance`. Do not delete the other provider's attribution, because each source needs its link-back.
5. Keep a manual-merge log, so false merges can be undone. Prefer a false negative (a duplicate shown) over a false merge, which would hide a real job.

## 7. Polling schedule

| Provider | Interval | Rationale |
|---|---|---|
| Remotive | every 6 h (4 per day at 00/06/12/18 UTC, jittered) | documented max 4 per day; stay well below 2 per minute |
| RemoteOK | every 60 min, jittered +-10 min | undocumented limit, 950 KB payload; be conservative |
| Himalayas | every 2 h with cursor paging (stop at the first known `guid`, cap 10 pages); an optional free key | CDN-cached 1-2 h; 60 requests per minute limit with a key; honour 429 and `Retry-After` |

Common rules: one in-flight request per provider; exponential backoff on 429/5xx (base 1 min, cap 6 h); a daily request budget counter per provider; conditional fetch with `If-None-Match` and `If-Modified-Since` where the provider sends validators (UNCONFIRMED, not tested); a descriptive `User-Agent` (`job-seeker/0.x (+contact)`); expire Himalayas jobs at `expiryDate` and mark postings Closed after 7 days unseen for the other providers.

## 8. Adapter interface (Go)

```go
package provider

import (
	"context"
	"time"

	"example.com/job_seeker/model"
)

// Terms describes the legal constraints an adapter must surface to the UI.
type Terms struct {
	AttributionText string        // e.g. "Source: Remotive"
	LinkBackRequired bool         // follow link to SourceURL must be shown
	NoRedistribute   bool         // must not be passed on to third parties
	MinInterval      time.Duration // lowest permitted poll interval
	DailyBudget      int           // max requests per day, 0 = unknown
	LiveLegalText    string        // last legal notice seen in the feed (runtime-captured)
}

// Cursor is an opaque, provider-specific paging position.
type Cursor string

type Page struct {
	Postings []model.Posting
	Next     Cursor // empty when done
	Raw      int    // number of raw records read, for metrics
}

type Query struct {
	Keywords []string
	Category string
	Limit    int
}

type Adapter interface {
	Name() model.Provider
	Terms() Terms
	// Fetch returns one page. Adapters must be pure HTTP + mapping, with no storage.
	Fetch(ctx context.Context, q Query, cur Cursor) (Page, error)
	// Stillopen is optional; return (true, ErrUnsupported) when not available.
	StillOpen(ctx context.Context, p model.Posting) (bool, error)
}

// Registry lets the scheduler add providers without code changes elsewhere.
type Registry interface {
	Register(a Adapter, schedule time.Duration)
	All() []Adapter
}
```

Error contract: return typed errors `ErrRateLimited{RetryAfter}`, `ErrBlocked`, `ErrSchema` (unexpected shape; fail loud, never partial-success), and `ErrUnsupported`. Each adapter ships a golden test fixture under `samples/`, and a contract test that the live legal text still contains the attribution requirement string, so ToS drift is caught.

## 9. Open items (UNCONFIRMED)

- Anonymous Himalayas rate limit value (not published). Recommend obtaining a free key.
- RemoteOK server-side tag filter and any hidden throttle.
- Whether storing normalised copies for private matching is within each ToS (no explicit clause for Remotive and RemoteOK). If the product goes public, ask each provider in writing.
- Remotive `limit` being ignored (observed, cause unconfirmed).
