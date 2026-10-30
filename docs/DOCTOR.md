# Offline Doctor (prepared 0.2.0)

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
Actions require manual review and separate authorization: integrity drift means
compare with the same trusted package version, never regenerate to hide it;
dependency-selected HAP plus passing smoke does not establish incompatibility,
and the latest downloadable HAP is not necessarily qualified. Missing import
prerequisites cannot be diagnosed from inside an unimportable module. FAIL wins
over WARN; WARN is not a clean PASS.
Facts include the manifest versus loaded module version/path, exact public
function and alias targets, the known legacy display version mismatch, native
PowerShell 5.1 Desktop, installed .NET release, available/loaded PSParseHTML,
actual HAP assembly name/version/location, fixed in-memory title/href/entity
parsing, and package integrity. PSParseHTML 3.0.6 is the tested dependency;
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

## Integrity baseline
`PSWebCrawler/PackageIntegrity.json` commits deterministic relative module-file
paths and SHA256 hashes, including manifest, module/private scripts, DLLs, data,
images and packaged docs. The inventory itself is excluded (no circular digest).
Repository-only docs/tests/tools and local evidence are outside this package
inventory. Missing, unsafe, duplicate, unreadable or empty entries FAIL. SHA256
syntax remains required for every entry. Doctor hashes all inventoried files except
exactly `lib/Net45/HtmlAgilityPack.dll` and `lib/core/HtmlAgilityPack.dll`: these
code-owned paths require file presence only. Inventory mode fields cannot exempt
other DLLs/files. Their recorded hashes remain maintainer byte-binding metadata,
not runtime comparisons. DLL swaps no longer cause hash FAIL; missing DLLs FAIL.
`Actual.Checked` remains the entry count; additive `HashedChecked` and
`PresenceChecked` distinguish actual coverage (currently 9 hashed, 2 presence).
HapIdentity and HtmlSmoke remain separate; smoke checks the loaded assembly, not
both bundled variants. PASS does not certify DLL bytes or replacement compatibility.
This detects non-HAP differences against the shipped baseline, **not authenticity,
signature validation or provenance**: an attacker who changes both files and
inventory defeats it. Compare against a separately trusted package/revision.
Doctor never rewrites the baseline or quarantines files.

The root `.gitattributes` pins only the eight inventoried module text files to
`text eol=lf`. Their committed LF bytes are the hash baseline; DLLs and PNG are
not normalized. Native Git `core.autocrlf=true` otherwise converts those files
to CRLF on checkout and produces a genuine byte-integrity FAIL despite a clean
Git status. Do not change global Git settings or regenerate hashes to hide it.

An existing clean Windows checkout may retain CRLF after pulling attributes.
After authorized delivery, run native PowerShell from `D:\repos\PSWebCrawler`.
These commands stop on local changes; never force checkout over user edits:

```powershell
$ErrorActionPreference = 'Stop'
if (@(git status --porcelain).Count -or $LASTEXITCODE) { throw 'Stop: inspect local changes.' }
git pull --ff-only
if ($LASTEXITCODE) { throw 'Pull failed.' }
if (@(git status --porcelain).Count -or $LASTEXITCODE) { throw 'Stop: inspect local changes.' }
$paths = @(Get-Content .gitattributes | Where-Object { $_ -match '^/PSWebCrawler/.+ text eol=lf$' } | ForEach-Object { ($_ -split ' ')[0].Substring(1) })
if ($paths.Count -ne 8) { throw 'Unexpected attribute scope; review before refreshing.' }
# Re-materialize ONLY the eight clean, tracked text paths through Git attributes.
git checkout-index --force -- $paths
if ($LASTEXITCODE) { throw 'Checkout refresh failed.' }
if (@(git status --porcelain).Count -or $LASTEXITCODE) { throw 'Unexpected checkout changes.' }
git ls-files --eol -- $paths  # each must show i/lf w/lf and text eol=lf
# Use a fresh native process for the actual post-sync health gate.
powershell.exe -NoProfile -NonInteractive -Command 'Import-Module .\PSWebCrawler\PSWebCrawler.psd1 -Force -ErrorAction Stop; Start-PSWebCrawler -Doctor | ConvertTo-Json -Depth 6'
```

Require `PackageIntegrity=PASS` (11 files) and `HtmlSmoke=PASS`; known dependency
HAP/legacy-version WARN remains distinct. A passing scratch candidate is not
proof that the synchronized Windows checkout has been refreshed and verified.

Maintainers only, after intentional reviewed package edits, use native Windows
PowerShell `./tools/Update-PackageIntegrity.ps1`; it is offline and does not import
the module. Review the resulting inventory, then qualify a fresh byte-matched
candidate. Do not run regeneration as an automatic repair of a failing Doctor.

Focused native Pester cases are in `tests/Doctor.Tests.ps1`; the established
78-case preproduction gate remains unchanged. Doctor tests add a separate fourteen
cases (D01-D14), not a replacement for baseline or future transport qualification.
