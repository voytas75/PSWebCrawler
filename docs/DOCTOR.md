# Offline Doctor (0.2.0 repository baseline)

[0.2.0 is published on Gallery](https://www.powershellgallery.com/packages/PSWebCrawler/0.2.0).
The checks and evidence here describe the repository baseline, not independent
qualification or byte parity of an installed Gallery package.

```powershell
Import-Module .\PSWebCrawler\PSWebCrawler.psd1 -ErrorAction Stop
$diagnostic = Start-PSWebCrawler -Doctor
$diagnostic | ConvertTo-Json -Depth 6
# PSWC -Doctor and PSWebCrawler -Doctor are equivalent.
```

Doctor is a separate parameter set: no URL is needed or accepted, and legacy
crawl/extraction parameters cannot be combined with it. It returns exactly one
object, without banner, prompts, log/output-directory creation, intentional
DNS/HTTP, dependency installation, security changes, provider calls or repairs.
It neither exits the process nor sets the caller's process exit code.

`SchemaVersion='1.0'`, `Status=PASS|WARN|FAIL`, `Healthy` (no FAIL checks), and
`Checks[]` and `Qualified=false` are returned. Healthy means no FAIL, not release,
fetch, HTTPS or dependency compatibility qualification. Every check has `Name`,
`Status`, `Expected`, `Actual`, `Message`, `Hint`, `Impact`, `RecommendedAction`,
`VerificationCommand`, and `DocumentationUrls[]` (preserved at JSON depth 6).
Advice is a static offline catalog for all ten checks and PASS/WARN/FAIL;
commands and official documentation/package links are never executed or fetched.
Actions require manual review and separate authorization: missing required files or malformed inventory fail presence acceptance. Changed-present bytes are not detected; do not treat PASS as byte integrity, authenticity or compatibility. Dependency-selected HAP plus passing smoke does not establish incompatibility, and the latest downloadable HAP is not necessarily qualified.
prerequisites cannot be diagnosed from inside an unimportable module. FAIL wins
over WARN; WARN is not a clean PASS.
Facts include the manifest versus loaded module version/path, exact public
function and alias targets, the known legacy display version mismatch, native
PowerShell 5.1 Desktop, installed .NET release, available/loaded PSParseHTML,
actual HAP assembly name/version/location, fixed in-memory title/href/entity
parsing, checks package-path presence only. Missing required paths fail; changed-present bytes are not detected. PSParseHTML 3.0.6 is the tested dependency;
other/multiple versions produce WARN, missing available/loaded dependency FAIL.
HAP loaded first by PSParseHTML may differ from the bundled DLL: identity or
location differences are WARN, not invented fatal incompatibility. Smoke behavior
is checked separately. Unknown framework release is WARN; the new qualification
uses .NET 4.8 release >=528040, distinct from the legacy manifest minimum 4.5.

Doctor requires **successful module import**. It cannot diagnose a manifest,
missing dependency/DLL, or private-script failure that prevents import; an
external pre-import doctor is deferred. Existing import-time TLS initialization
remains unchanged. Legacy crawling remains network-capable; only Doctor's path
is offline. The current private Site/Domains unavailable guards remain unchanged.

## Optional repository presentation

`tools/Show-PSWCDoctor.ps1` is a repository utility, not a module export or a
Gallery installation claim. Default `Start-PSWebCrawler -Doctor` still returns
its unchanged structured object. The renderer never imports the product, runs
Doctor, executes advice, contacts documentation links, repairs anything or exits
the caller. Capture a live report separately after successful import:

```powershell
$report = Start-PSWebCrawler -Doctor
.\tools\Show-PSWCDoctor.ps1 -Report $report -View Summary
$report | .\tools\Show-PSWCDoctor.ps1 -View Detail -CheckName HapIdentity
$report | ConvertTo-Json -Depth 6 | Set-Content .\doctor.json -Encoding UTF8
.\tools\Show-PSWCDoctor.ps1 -JsonPath .\doctor.json -View Detail
.\tools\Show-PSWCDoctor.ps1 -JsonPath .\doctor.json -View Machine
.\tools\Show-PSWCDoctor.ps1 -Report $report -View Machine -RequireQualification
```

Choose exactly one input: `-Report` (also accepts pipeline objects) or explicit
`-JsonPath`; there is no default snapshot path. All views label captured data:
freshness and provenance remain caller-owned, so saved snapshots are not live
health evidence. `Summary` shows severity, independent health/qualification gates,
counts, FAIL before WARN and collapsed PASS. The representative ten-check,
eight-PASS/two-WARN report is bounded to seven lines/1100 characters; arbitrary
reports with more findings are not subject to that representative budget.
Control characters and long messages are compacted only in Summary. `Detail`
retains every top-level field and every selected check field, including full
advice and future data properties; omit `-CheckName` for all checks. Unknown
case-sensitive identifiers fail explicitly. `-CheckName` is Detail-only.

`Machine` emits one raw JSON string per report, with `Decision` and the complete
unchanged `Report`. Arrays of zero, one or many values are retained. Consumers
parse JSON, not human text. `Decision.Policy` is `Health` by default; the optional
Machine-only `-RequireQualification` selects `RequireQualification`. Rejection
precedence is `StatusFAIL`, `Unhealthy`, then `QualificationRequired`; otherwise
`AcceptedByHealthPolicy`. The renderer returns this decision without choosing
an operating-system exit code. No human labels contaminate Machine output.

The renderer checks schema 1.0, required fields/types, unique check names and
plain data properties before rendering; malformed JSON/data fail rather than
inventing a decision. Script properties and foreign objects are rejected. This
is bounded presentation validation (supported nesting depth 18), not a general
untrusted-JSON parser, authenticity check or terminal-security guarantee. Advice
and diagnostic strings remain data, never evaluated.

## Maintainer-only HAP changes

A dependency-selected HAP warning is not an instruction to replace a DLL.
For separately approved library maintenance, see
[HtmlAgilityPack maintenance](HAP-MAINTENANCE.md), covering actual assembly
ownership, exact-version/source selection, rollback and fresh native gates.
Ordinary Doctor use remains diagnostic only; no download or repair is authorized.

## Required-file inventory (presence only)

`PSWebCrawler/PackageIntegrity.json` retains its established filename for package-layout compatibility, but schema `2.0` records only required relative `Path` values. The generator excludes the inventory itself. Doctor rejects missing/unreadable/malformed inventory, unknown or legacy schemas, empty lists, unknown entry fields, duplicate or unsafe paths, and reparse points. The eleven established package paths are code-owned and checked for presence; removing them from the inventory does not suppress missing-file checks.

Doctor checks presence only. It does **not** hash files, so changed-present content (including DLL replacements), authenticity, provenance and compatibility are not detected or certified. `Actual.Checked` and `Actual.PresenceChecked` count inventory entries; `Actual.Verification` is `PresenceOnly`. Doctor has no `HashedChecked` field and makes no byte-integrity claim. HAP identity and parser smoke remain separate diagnostics.

The inventory is an editable list, not a trusted authority or signature. Compare the package with a separately trusted source when byte identity matters. Hashes in historical tests, receipts, candidate bindings, archives, and maintainer download-verification procedures are separate evidence, not runtime Doctor checks; historical evidence is outside this change.

Maintainers run the existing explicit packaging command after reviewed package edits:

```powershell
.\tools\Update-PackageIntegrity.ps1
```

It writes the deterministic path inventory; it performs no hashing and does not import the module. Review the path delta and verify the generated file set. Repository-only docs/tests/tools are outside the shipped inventory. This check is not authenticity, signature validation, provenance, or byte-integrity verification.

The root `.gitattributes` pins inventoried text files for checkout EOL only; Doctor
no longer checks their bytes. Do not change global Git settings under this policy.

Focused native Pester cases are in `tests/Doctor.Tests.ps1`; the established
78-case preproduction gate remains unchanged. Doctor tests contain sixteen cases
(D01-D17 with two cases consolidated), not a replacement for baseline or future
transport qualification.
