# PSWebCrawler developer and legacy reference

For installation and the safe operator entry points, start with [README](README.md).
This guide covers development, retained legacy options and verification limits.

## Documentation owners

- [Release notes](PSWebCrawler/docs/ReleaseNotes.md): canonical version history;
  0.2.0 is prepared, not a Gallery publication announcement.
- [Doctor](docs/DOCTOR.md): diagnostic schema, checks and package-integrity rules.
- [Upgrading](docs/UPGRADING.md): compatibility, prerequisites and rollback limits.
- [Roadmap](docs/ROADMAP.md): deferred C2/B2 fetch, HTTPS/TLS and S7 Domains work.
- [Windows preproduction](docs/WINDOWS-PREPRODUCTION.md): runner and evidence contract.
- [Tests](tests/README.md): characterization and internal contract coverage.
- [AGENTS.md](AGENTS.md): repository execution rules; read available local
  PLAN.md, BOUNDS.md and STATUS.md before changing this checkout.

Those documents remain authoritative; this guide is not a second changelog or
release/transport acceptance record.

## Repository map

| Path | Responsibility |
| --- | --- |
| `PSWebCrawler/PSWebCrawler.psd1` | Version, Desktop prerequisites, dependency and exports |
| `PSWebCrawler/PSWebCrawler.psm1` | Public Start command, retained legacy routines and internal contracts |
| `PSWebCrawler/Private/` | Image extraction, timing and offline Doctor helpers |
| `PSWebCrawler/lib/Net45/` | Bundled Desktop HTML parser assembly |
| `PSWebCrawler/Data/useragents.txt` | Legacy User-Agent data |
| `PSWebCrawler/PackageIntegrity.json` | Shipped relative-file SHA256 inventory |
| `.gitattributes` | Exact inventoried text paths pinned to LF |
| `tests/` | Fixtures, focused gates and fresh-process runners |
| `tools/Update-PackageIntegrity.ps1` | Explicit maintainer-only baseline generation |
| `tools/Show-PSWCDoctor.ps1` | Repository-only English renderer; private helpers in `tools/Doctor.Presentation.ps1` |

A Core-related library directory does not establish PowerShell Core support.

## Development setup

Use a local Windows checkout and **Windows PowerShell 5.1 Desktop**. WSL may
launch native `powershell.exe` as transport; Linux pwsh is not the acceptance
runtime. Repository helpers/parsing/tests use native Windows PowerShell, not
Python. Read the execution rules before invoking product imports or tests.

The manifest declares .NET Framework 4.5 and `PSparseHTML` without a version pin.
The native full runner instead requires .NET Framework 4.8+, PSParseHTML 3.0.6
(with no other available version), and Pester 3.4.0. Pester is a test prerequisite
only. The acceptance host does not prove portability to every declared minimum
or dependency version. Do not install dependencies, alter security settings or
change repository trust implicitly.

From the repository root, after required dependencies are present:

```powershell
# Fresh Windows PowerShell process; import has legacy process-local TLS setup.
Import-Module .\PSWebCrawler\PSWebCrawler.psd1 -ErrorAction Stop
Get-Module PSWebCrawler | Select-Object Name, Version, Path
Get-Command -Module PSWebCrawler
Start-PSWebCrawler
Start-PSWebCrawler -Doctor | ConvertTo-Json -Depth 6
```

Expect manifest version 0.2.0 and only `Start-PSWebCrawler` as a public function,
plus aliases `PSWC` and `PSWebCrawler`. The legacy banner still displays 0.1.0;
Doctor reports that module-owned mismatch. It is not fixed by runtime installation.
Import no longer checks Gallery, clears the console, prints welcome text or
creates output directories. It is not completely side-effect-free: TLS
initialization remains. The menu-only path does not create output or logs.

For optional human Summary/Detail and JSON machine policy, see
[Doctor presentation](docs/DOCTOR.md#optional-repository-presentation). The utility
and its private helpers are outside the shipped module and package inventory.
Run its separate historical-fixture tests in a fresh native process, providing
your explicit saved Doctor JSON (not a claim of live health):

```powershell
Import-Module Pester -RequiredVersion 3.4.0
Invoke-Pester -Script @{ Path = '.\tests\Doctor.Presentation.Tests.ps1'; Parameters = @{ SnapshotPath = '.\doctor.json' } }
```

The representative snapshot suite expects ten checks (eight PASS/two WARN);
actual live Doctor, focused Doctor tests and the existing preproduction runner
are separate gates. No dependency installation or Windows checkout sync is
performed by the renderer.

## Retained legacy command reference

**The following URL examples can make live network requests and write files.**
They document current parameter bindings, not a freshly verified crawling result,
HTTPS/TLS safety, or approval to contact the example host. Run only with target
permission and a separately approved network scope. Invalid legacy URL input can
prompt interactively; these paths are not a headless automation contract.

### Crawl and URL processing

```powershell
PSWC -Url 'https://example.com' -Depth 2
PSWC -Url 'https://example.com' -Depth 2 -onlyDomains
PSWC -Url 'https://example.com' -Depth 2 -outputFolder 'C:\Crawl\LOGandDATA\'
PSWC -Url 'https://example.com' -Depth 2 -resolve
```

`Depth` defaults to 2 in the legacy WebCrawl parameter set. `-resolve` requests
DNS address resolution; `-outputFolder` belongs to WebCrawl, not every extraction
option. Legacy `-onlyDomains` affects domain extraction/traversal; do not equate
it with the deferred new `-Mode Domains` contract. Baseline tests characterize
legacy recursion and extraction gaps rather than guaranteeing v1 traversal.

### ShowCacheFolder

```powershell
PSWC -ShowCacheFolder
```

Opens the default log/data folder in Windows Explorer. This is not an offline
health check or an import/setup workaround and may initialize legacy output.

### ShowAllElements

```powershell
PSWC -ShowAllElements -Type All -Url 'https://example.com'
```

The accepted `-Type` values are `Href`, `noHref`, `onlyDomains`, and `All`.
The operation extracts link/non-link/domain data through the legacy implementation;
`All` is the default. See the implementation and characterization tests for exact
filtering/output semantics rather than treating this as a new structured API.

### GetImageUrls

```powershell
PSWC -GetImageUrls -Url 'https://example.com'
```

The successful response path extracts image URLs and writes `Images.txt` in the
session folder. It does **not** download image bytes. Relative image URL gaps
are explicitly characterized in the baseline tests.

### GetHTMLMetadata

```powershell
PSWC -GetHTMLMetadata -Url 'https://example.com'
```

The successful response path extracts HTML metadata, emits JSON and writes
`Header.json` in the session folder (not the older README's `metadata.txt`).

### GetContactInformation

```powershell
PSWC -GetContactInformation -Url 'https://example.com'
```

The successful response path extracts contact information, emits JSON and writes
`Contact.json` in the session folder. These are heuristic extraction results,
not guaranteed detection of every email, address or phone number.

### GetHeadersAndValues

```powershell
PSWC -GetHeadersAndValues -Url 'https://example.com'
```

Processes HTML `<head>` content, not a general HTTP response-header API. The
legacy implementation writes `HTMLhead.json`; `-outputFolder` is not available
in this parameter set. Do not substitute new internal schema assumptions for
these retained files.

### Default log and data folder

Legacy output defaults to the user's Documents folder under `PSWebCrawler`.
Operations initialize output lazily, with timestamped session folders and
`Settings.log`; import and menu-only invocation do not create them. The
WebCrawl `-outputFolder` override selects its session/output location, but do
not assume it relocates every module-level log or extraction output. Exact
explicit-path/output compatibility is not established by matching signatures.
Review saved contacts, URLs and logs for sensitive data before sharing.

## Internal implementation: not an operator API

`Invoke-PSWebCrawler` is private and is exercised in module scope by tests.
It is not exported, not a supported command replacement, and not callable as a
new public Site/Domains workflow. Its current Site capability is unavailable
(`CapabilityUnavailable`); Domains returns `UnsupportedMode`.

Offline fixtures cover Site contracts, URI/extraction analysis and bounded
orchestration. Internal result shape is `Run`, `Pages[]`, `Links[]`, `Errors[]`,
with `Run.SchemaVersion='1.0'`. Internal depth starts at zero and Site traversal
uses BFS with start-host boundaries. These contracts differ from legacy depth
and output semantics; neither fixtures nor the presence of implementation enables
production fetching. Follow [upgrade guidance](docs/UPGRADING.md), never automatic
command-name substitution. Future transport/robots/redirect/queue policy and
Domains implementation need separately approved scope and fresh qualification.

## Verification workflows

From a Windows repository root, choose an existing output parent outside the
checkout and all previous evidence directories:

```powershell
# Syntax/inventory/ordered-contract preparation only: no product import or Pester.
powershell.exe -NoProfile -NonInteractive -File .\tests\Run-WindowsPreproduction.ps1 -OutputParent "$env:USERPROFILE\Documents" -StaticOnly
# Full native gate: real product/dependency imports, offline fixture seams.
powershell.exe -NoProfile -NonInteractive -File .\tests\Run-WindowsPreproduction.ps1 -OutputParent "$env:USERPROFILE\Documents"
```

The established full gate is **78 outcomes**: S2 32, S3 14, S4 16, baseline 7,
dependency/import 5 and import-runtime 4. Historical native acceptance passed
78/78 with no failed/pending/skipped cases; this docs-only change does not claim
a new execution. Full tests do not intentionally exercise legacy networking and
are not a sandbox or production transport/TLS qualification.

Focused Doctor checks run separately in a fresh native process:

```powershell
Import-Module Pester -RequiredVersion 3.4.0
Invoke-Pester -Script .\tests\Doctor.Tests.ps1 -PassThru
```

The qualified Doctor baseline has **eight cases**, separate from the 78-outcome
runner. The current local worktree also contains three pending remediation cases
(D09–D11); they have **not** passed native RED/GREEN qualification and are not an
11-case success claim. Discover the actual case inventory for the revision under
test; preserve pending edits and require measured results rather than copying a
historical count. Structured remediation advice is not yet implemented/qualified.

Retain raw `Start-PSWebCrawler -Doctor | ConvertTo-Json -Depth 6` output alongside
focused results. Known legacy-version and dependency-selected HAP warnings can
produce `Status=WARN`, `Healthy=true`, while package integrity and fixed in-memory
HTML smoke pass. Identity differences alone are not proof of incompatibility or
instructions to replace the dependency-owned parser. Doctor needs successful
import and cannot diagnose dependencies that block import. It performs no repair,
installation or intentional DNS/HTTP and does not establish networking health.

Every runner invocation creates new evidence; inspect the receipt, counts,
stdout/stderr, exit/timeout/readers and prepared-source hashes. Never overwrite
historical receipts or imply new passing tests repair a broken historical chain.
See the [runner contract](docs/WINDOWS-PREPRODUCTION.md) for exact requirements.

## Package integrity and release maintenance

The shipped inventory measures exact bytes against its relative-file SHA256
baseline, **not authenticity, signature validation or provenance**. Repository
README/developer docs/tests/tools are outside that package inventory; this split
does not require regenerating it. The inventory cannot defend against replacement
of both package files and the baseline.

Eight inventoried text paths are pinned to `text eol=lf` by `.gitattributes`;
DLLs/PNG remain byte-exact. A clean Git status alone does not prove package bytes.
For existing Windows CRLF checkout problems, follow the guarded clean-checkout
procedure and byte verification in [Doctor](docs/DOCTOR.md); never force over
local edits, change global Git settings, normalize hashes or regenerate a failing
baseline merely to make diagnostics pass.

Only after legitimate, intentional, reviewed package edits, maintainers run:

```powershell
# Native Windows PowerShell; offline, no product import.
.\tools\Update-PackageIntegrity.ps1
```

Review the inventory diff and qualify a fresh byte-matched candidate afterward.
Doctor never automatically regenerates hashes, installs dependencies or repairs
files. Publication remains manual and owner-controlled; no tag, release or
Gallery package is implied by version metadata or these commands. Follow the
canonical [release notes](PSWebCrawler/docs/ReleaseNotes.md) and
[upgrade guidance](docs/UPGRADING.md), including unresolved compatibility and
rollback limits.

## Contributing, versioning and credits

Report issues, suggest bounded improvements or submit pull requests through
[GitHub Issues](https://github.com/voytas75/PSWebCrawler/issues) and the
[source repository](https://github.com/voytas75/PSWebCrawler). Read repository
scope/verification rules first; preserve unrelated local changes. New features,
dependencies, runtime/security changes and Git delivery need explicit approval.

Versioning follows [SemVer](https://semver.org/); history belongs in the existing
release notes, not a duplicate changelog here. PSWebCrawler is released under the
[MIT License](LICENSE). Author: Wojciech Napierala; project/vendor: Script Savvy
Ninja. HTML parsing builds on
[HtmlAgilityPack](https://github.com/zzzprojects/html-agility-pack).

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/A0A6KYBUS)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/79c2ea8438ec45c68d03858459bcf816)](https://app.codacy.com/gh/voytas75/PSWebCrawler/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
