# Upgrading PSWebCrawler to 0.2.0

## Release status
Target release: 0.2.0; not published or ready for installation yet. PSGallery inspection found latest published 0.0.5; repository baseline manifest is 0.1.0, not present in the inspected Gallery version list. The publisher performs release publication. Commands below targeting 0.2.0 apply only after publication.
Release scope approved: 0.2.0 must ship both Site and Domains. Both require implementation and acceptance before publication; do not publish a Site-only build as this planned release. Do not advertise an unimplemented mode. Invoke-PSWebCrawler exists as offline-testable Site orchestration in the development implementation; real transport remains unavailable and Domains is unsupported. See [manual Windows preproduction](WINDOWS-PREPRODUCTION.md) for the repository test package and its limits.

## New API transport prerequisite (selected design; qualification pending)
New API runtime contract: Windows PowerShell 5.1 Desktop with .NET Framework 4.8 or newer. This is the approved project requirement, not the minimum prerequisite of WMF 5.1. Scratch offline and local HTTP transport tests passed on the current .NET Framework 4.8 host; they do not establish production API or HTTPS acceptance. The previous 4.5.2 minimum-runtime target is superseded, not retrospectively passed. This decision does not change the legacy module manifest or imply PowerShell 7 support.
New API uses Windows PowerShell 5.1 with an explicit curl.exe adapter. Proposed minimum curl version: 8.20.0; final prerequisite follows transport acceptance. Existing host has 8.21.0, not a guarantee for other users. Legacy commands do not acquire this new prerequisite by design. Users opting into Invoke-PSWebCrawler must check curl availability/version; if absent or unsupported, new API must fail clearly without installation or weaker fallback. No data conversion required by this environment prerequisite. Adapter not implemented/qualified yet.

## Migration policy
No mandatory data conversion is planned. Keep historical TXT/JSON/logs unchanged; do not delete, overwrite or automatically convert them. Inspection of the 0.0.5 and development main module found no ConvertFrom-Json/Import-Clixml persisted-state ingestion. This is limited evidence, not a complete package/runtime migration audit.
Legacy commands Start-PSWebCrawler, PSWC and PSWebCrawler remain the compatibility target. Compared main-function parameter definitions and Gallery manifest exports/aliases match. Full behavior/output compatibility against published 0.0.5 still requires release tests; matching signatures do not establish compatibility.

## Known behavior changes
Import no longer checks PSGallery, clears the console or creates the output directory. Unsupported Core import raises an error instead of exiting the calling process. Legacy operations initialize output lazily before logging; menu-only invocation does not create output or log.
If a script assumes the output directory exists immediately after Import-Module, update that script to create/validate its explicitly selected directory before its own writes. Do not use ShowCacheFolder as a setup workaround: it invokes Explorer. Exact output initialization/explicit-path compatibility remains a release gate.
Import no longer prints welcome text, but still modifies TLS in the current development implementation; do not describe it as completely side-effect-free.

## Before upgrading
1. Record installed and loaded versions:
```powershell
Get-Module -ListAvailable PSWebCrawler | Select-Object Name, Version, Path
Get-Module PSWebCrawler | Select-Object Name, Version, Path
```
2. Retain previous module version and back up scripts/historical outputs. Do not uninstall the previous version as part of upgrade.
3. Verify Windows PowerShell 5.1 Desktop and dependency availability. Development acceptance used PSParseHTML 3.0.6; production dependency policy remains unpinned and must be reviewed before release.
4. Identify consumers of import-time directory creation, console text and legacy file formats. Run compatibility fixtures before switching automation.

## Install/load after publication
Use a fresh Windows PowerShell process; installation does not replace an already loaded module. Confirm package version and release notes first.
```powershell
Find-Module -Name PSWebCrawler -RequiredVersion 0.2.0 -Repository PSGallery
Install-Module -Name PSWebCrawler -RequiredVersion 0.2.0 -Repository PSGallery -Scope CurrentUser
Import-Module PSWebCrawler -RequiredVersion 0.2.0 -ErrorAction Stop
Get-Module PSWebCrawler | Select-Object Name, Version, Path
Get-Command -Module PSWebCrawler
```
Do not change repository trust/security policy merely to complete installation. Resolve any installation conflict explicitly; do not default to Force/AllowClobber.

## Opting into new API (target, not yet available)
New Invoke-PSWebCrawler requires explicit -Mode Site|Domains. It is not a rename-only replacement for legacy commands: Depth and output semantics differ.
- Start depth=0; Depth 0 analyzes start only; traversal is BFS.
- Site visits the start host only; Domains visits at most one discovered page per host.
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
Published 0.0.5 compatibility fixtures; real legacy output/filesystem paths; dependency policy; clean new API channels; actual target-mode acceptance; old/new examples; upgrade/rollback in fresh processes; explicit release-content decision. Current tests of repository baseline do not prove all these gates.
