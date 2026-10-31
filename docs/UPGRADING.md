# Upgrading PSWebCrawler to 0.2.0

## Release status
[0.2.0 is published on PowerShell Gallery](https://www.powershellgallery.com/packages/PSWebCrawler/0.2.0). The earlier 0.0.5 Gallery inspection is historical; 0.2.0 is now the published baseline. The version-specific installation commands below apply now. Repository/candidate tests do not establish byte parity or independent qualification of an installed Gallery package. Further changes belong to Unreleased; the next release version is undecided.
Current owner-approved release scope supersedes the earlier both-modes requirement: contracts/analysis only, without enabled production fetching in the new API. The only public function is `Start-PSWebCrawler`, with aliases `PSWC` and `PSWebCrawler`. `Invoke-PSWebCrawler` is private implementation for offline-testable Site contracts, analysis and orchestration; internal Site invocation fails closed with `CapabilityUnavailable`, and Domains with `UnsupportedMode`. Legacy `Start-PSWebCrawler` / `PSWC` / `PSWebCrawler` remain network-capable; this scope does not disable them. C2/B2 transport integration, HTTPS/TLS and S7 Domains are deferred to the [future roadmap](ROADMAP.md), not blockers for this release. The [manual Windows preproduction](WINDOWS-PREPRODUCTION.md) baseline passed 78/78; it does not qualify deferred features.

## Future enabled-fetch transport prerequisite (not a current release gate)
New API runtime contract: Windows PowerShell 5.1 Desktop with .NET Framework 4.8 or newer. This is the approved project requirement, not the minimum prerequisite of WMF 5.1. Scratch offline and local HTTP transport tests passed on the current .NET Framework 4.8 host; they do not establish production API or HTTPS acceptance. The previous 4.5.2 minimum-runtime target is superseded, not retrospectively passed. This decision does not change the legacy module manifest or imply PowerShell 7 support.
Future enabled fetching is designed to use Windows PowerShell 5.1 with an explicit curl.exe adapter. Proposed minimum curl version: 8.20.0; final prerequisite follows transport acceptance. Existing host has 8.21.0, not a guarantee for other users. Legacy commands do not acquire this new prerequisite by design. Users opting into future enabled fetching must check curl availability/version; if absent or unsupported, new API must fail clearly without installation or weaker fallback. No data conversion required by this environment prerequisite. Adapter not implemented/qualified yet.

## Migration policy
No mandatory data conversion is planned. Keep historical TXT/JSON/logs unchanged; do not delete, overwrite or automatically convert them. Inspection of the 0.0.5 and development main module found no ConvertFrom-Json/Import-Clixml persisted-state ingestion. This is limited evidence, not a complete package/runtime migration audit.
Legacy commands Start-PSWebCrawler, PSWC and PSWebCrawler remain the compatibility target. Compared main-function parameter definitions and Gallery manifest exports/aliases match. Full behavior/output compatibility against published 0.0.5 still requires release tests; matching signatures do not establish compatibility.

## Known behavior changes
Import no longer checks PSGallery, clears the console or creates the output directory. Unsupported Core import raises an error instead of exiting the calling process. Legacy operations initialize output lazily before logging; menu-only invocation does not create output or log.
If a script assumes the output directory exists immediately after Import-Module, update that script to create/validate its explicitly selected directory before its own writes. Do not use ShowCacheFolder as a setup workaround: it invokes Explorer. Exact output initialization/explicit-path compatibility remains a release gate.
Import no longer prints welcome text, but still modifies TLS in the current development implementation; do not describe it as completely side-effect-free.

## Offline diagnostics
After successful import, run `Start-PSWebCrawler -Doctor | ConvertTo-Json -Depth 6`.
See [Doctor](DOCTOR.md): this reports loaded version/path and dependency/package
facts without repair. It cannot run if import fails and is not a provenance proof.
The new separate Doctor parameter does not change legacy operation signatures.

## Before upgrading
1. Record installed and loaded versions:
```powershell
Get-Module -ListAvailable PSWebCrawler | Select-Object Name, Version, Path
Get-Module PSWebCrawler | Select-Object Name, Version, Path
```
2. Retain previous module version and back up scripts/historical outputs. Do not uninstall the previous version as part of upgrade.
3. Verify Windows PowerShell 5.1 Desktop and dependency availability. Development acceptance used PSParseHTML 3.0.6; production dependency policy remains unpinned; review it before any future dependency change.
4. Identify consumers of import-time directory creation, console text and legacy file formats. Run compatibility fixtures before switching automation.

## Install/load published 0.2.0
Use a fresh Windows PowerShell process; installation does not replace an already loaded module. Confirm package version and release notes first.
```powershell
Find-Module -Name PSWebCrawler -RequiredVersion 0.2.0 -Repository PSGallery
Install-Module -Name PSWebCrawler -RequiredVersion 0.2.0 -Repository PSGallery -Scope CurrentUser
Import-Module PSWebCrawler -RequiredVersion 0.2.0 -ErrorAction Stop
Get-Module PSWebCrawler | Select-Object Name, Version, Path
Get-Command -Module PSWebCrawler
```
Do not change repository trust/security policy merely to complete installation. Resolve any installation conflict explicitly; do not default to Force/AllowClobber.

## Internal contracts now; public new API and fetching later
Private `Invoke-PSWebCrawler` requires explicit -Mode Site|Domains in module-scope tests. It is not exported or supported for operator invocation, and is not a replacement for legacy commands: Depth and output semantics differ.
- Start depth=0; Depth 0 analyzes start only; traversal is BFS.
- Offline-tested Site orchestration is bounded to the start host; future Domains targets at most one discovered page per host. Neither is enabled production fetching now.
- One structured result: Run, Pages[], Links[], Errors[]; Run.SchemaVersion='1.0'; explicit partial/failure outcomes.
- New JSON is not interchangeable with historical files; adapt downstream consumers intentionally.
Keep legacy scripts on legacy commands until new workflow acceptance passes. Never perform automatic command-name substitution.

## Rollback
Start a fresh process and load a retained previous version explicitly:
```powershell
Import-Module PSWebCrawler -RequiredVersion 0.0.5 -ErrorAction Stop
Get-Module PSWebCrawler | Select-Object Name, Version, Path
```
Use the actual previous version if different. Rollback has not been exercised against a published 0.2.0. Historical data is not rewritten; retain consumer scripts compatible with the selected version.

## Migration wizard decision
No wizard now: no confirmed required data transformation. If compatibility tests identify a necessary action, document it here and consider an opt-in diagnostic wizard: detect -> preview required actions -> explicit confirmation -> reversible apply -> readback. No automatic script rewriting or speculative conversion.

## Release gates
Current contracts/analysis acceptance is the verified 78/78 manual Windows baseline, with its documented limits. C2/B2, HTTPS/TLS and S7 acceptance are deferred, not publication blockers for this scope. Published 0.0.5 full behavior/output compatibility, dependency portability and upgrade/rollback are not established by that baseline; do not advertise seamless migration. 0.2.0 has been published by the user. That publication does not extend the repository/candidate verification boundary to an installed Gallery package. Review final package contents and retain accurate prerequisites and limitations before any future manual publication.
