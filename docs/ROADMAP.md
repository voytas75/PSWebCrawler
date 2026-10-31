# Future roadmap

## Current release boundary

The only public function is `Start-PSWebCrawler`, with aliases `PSWC` and
`PSWebCrawler`; `Invoke-PSWebCrawler` remains private, not an operator API.
The published 0.2.0 release boundary is contracts/analysis only for that internal implementation,
with no enabled production fetching. Site contracts, URI/extraction analysis and
bounded orchestration have a 78/78 manual Windows baseline using counted private
policy/transport fixtures. Site remains `CapabilityUnavailable`; Domains remains
`UnsupportedMode`. Legacy network-capable commands are retained, not disabled.
Deferred items below are not blockers for this release and are not implementation
approval. See [upgrade scope](UPGRADING.md) and [acceptance](WINDOWS-PREPRODUCTION.md).

## Deferred enabled-fetch line: C2/B2

- Inventory the exact current repository versus retained candidate code, private
  files, BytePipe source, policy helpers, fixtures and receipt dependencies before
  proposing any promotion. Approve the smallest explicit production/test slice;
  do not silently copy machine-bound scratch artifacts into the release.
- Freshly qualify the promoted transport, robots, redirects, queue and target
  policy together, with observable fail-closed behavior and actual connected-peer
  guarantees. Counted offline orchestration tests do not prove these properties.
- Historical B2 results remain historical; the broken transitive evidence chain
  is not restored by the current 78/78 run. Preserve originals and produce fresh,
  revision-bound qualification rather than reconstructing historical receipts.
- Qualify HTTPS/TLS and approved curl/runtime prerequisites before future fetching
  is enabled or advertised. Historical HTTP/offline passes are not HTTPS success.
  No weaker fallback, automatic install or host-security change is authorized.

## Deferred separate mode: S7 Domains

Obtain separate user approval for Domains implementation and contracts: node is
host (not registrable domain), depth counts host transitions, start depth is zero,
at most one page per host, and all inter-host edges are retained. Resolve host
reservations, redirects/collisions, admission and error ownership explicitly;
qualify the shared transport/policy integration and mode-specific cases freshly.
Existing legacy `-onlyDomains` is not qualification of new `-Mode Domains`.

## Publication boundary

[0.2.0 is published on PowerShell Gallery](https://www.powershellgallery.com/packages/PSWebCrawler/0.2.0)
and is closed. Subsequent changes belong to Unreleased; the next release version
is undecided. Repository/candidate acceptance does not establish installed
Gallery qualification or byte parity. Future publication remains manual and
owned by the user; this roadmap does not authorize implementation, publication,
a tag or a GitHub Release. Do not advertise deferred modes or transport.
