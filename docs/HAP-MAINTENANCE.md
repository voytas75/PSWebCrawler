# HtmlAgilityPack maintenance (maintainers only)

## Scope and verified baseline

This repository-only guide describes a **separately approved** maintenance
procedure, not an instruction for ordinary users to repair a Doctor warning.
Creation of this guide does not approve downloads, dependency installation,
DLL replacement, runtime/security/CI changes, Git delivery or publication.
Use [Doctor](DOCTOR.md) for ordinary offline diagnostics and
[developer guidance](../readme-dev.md) for the repository workflow.

Baseline inspected at `8aee963250bea921b655aac5d5137958d50b2ce1` (0.2.0):

- `PSWebCrawler/PSWebCrawler.psd1` declares Windows PowerShell 5.1, Desktop,
  .NET Framework 4.5 and `RequiredModules = @('PSparseHTML')`, without a pin.
- Required modules import before the root module. PSParseHTML can therefore
  own the HAP assembly actually used by `HtmlAgilityPack.HtmlDocument`.
- The root `PSWebCrawler.psm1` enumerates `lib/Net45/*.dll` and calls
  `Add-Type -Path`; it explicitly rejects Core. `lib/core` is not an active
  loader branch and does not establish PowerShell 7 support.
- Both bundled DLLs have assembly version 1.11.57.0 and public key token
  `bd319b19eaf3b43a`; their bytes and target frameworks are different.
  Native passive metadata identifies Net45 as `.NETFramework,Version=v4.5`
  (references include mscorlib/System 4.0.0.0) and core as
  `.NETPortable,Version=v4.5,Profile=Profile111` (System.Runtime 4.0.0.0 and
  portable facade references). The folder name is not a framework guarantee.
- Historical native acceptance used PSParseHTML 3.0.6, which selected HAP
  1.13.0.0 from its own installation rather than bundled 1.11.57.0.
  That is a tested environment, not a supported version range or a pin policy.
- Acceptance requires .NET Framework 4.8 or newer (Release >=528040).
  Passing there does **not** qualify the declared 4.5 floor. Do not silently
  raise that floor or claim it works; qualification or a minimum change is a
  separate owner decision.

Re-inventory the revision under review; these observations are not promises
about every future package. Consult the manifest, loader, private Doctor,
[upgrade boundaries](UPGRADING.md) and current local PLAN/STATUS before acting.

## Read-only native baseline commands

Start a **new Windows PowerShell 5.1 Desktop process**, not Linux pwsh or PS7.
Run from the exact repository root selected by the owner. Paths below resolve
that checkout, not whichever module happens to be on `PSModulePath`.
Launch the shell with `powershell.exe -NoProfile -NonInteractive -Command`
when scripting, or use a fresh interactive `powershell.exe -NoProfile` shell.
The blocks below print results; they do not install, download or write files.

```powershell
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or
    $PSVersionTable.PSVersion.Major -ne 5 -or
    $PSVersionTable.PSVersion.Minor -ne 1) { throw 'Use native Windows PowerShell 5.1.' }
$manifest = (Resolve-Path -LiteralPath .\PSWebCrawler\PSWebCrawler.psd1).ProviderPath
$moduleRoot = Split-Path $manifest -Parent
Get-FileHash -LiteralPath $manifest -Algorithm SHA256
Get-FileHash -LiteralPath (Join-Path $moduleRoot 'PackageIntegrity.json') -Algorithm SHA256
foreach ($relative in 'lib\Net45\HtmlAgilityPack.dll','lib\core\HtmlAgilityPack.dll') {
    $path = Join-Path $moduleRoot $relative
    Get-FileHash -LiteralPath $path -Algorithm SHA256
    [Reflection.AssemblyName]::GetAssemblyName($path) | Format-List FullName
}
Get-Module -ListAvailable PSParseHTML | Select-Object Name,Version,Path
Get-Module PSParseHTML | Select-Object Name,Version,Path
$inventory = Get-Content -LiteralPath (Join-Path $moduleRoot 'PackageIntegrity.json') -Raw | ConvertFrom-Json
foreach ($entry in $inventory.Files) {
    $observed = (Get-FileHash -LiteralPath (Join-Path $moduleRoot $entry.Path) -Algorithm SHA256).Hash
    if ($observed -ne $entry.Sha256) { throw ('Original baseline mismatch: ' + $entry.Path) }
}
```

`AssemblyName.GetAssemblyName` reads identity without executing the DLL.
For detailed target-framework/reference metadata, use separate fresh native
reflection-only processes for each variant; same-identity assemblies can
conflict even in reflection-only context. Resolve framework dependencies using
trusted installed framework assemblies, not unverified downloaded DLLs.
Do not confuse passive identity, strong-name token, loadability and authenticity.

After the original bytes and prerequisites are understood, run this second
block in that fresh baseline process (with `$manifest` from above):

```powershell
Import-Module -Name $manifest -ErrorAction Stop
Get-Module PSWebCrawler,PSParseHTML | Select-Object Name,Version,Path
$assembly = [HtmlAgilityPack.HtmlDocument].Assembly
$assembly | Format-List FullName,Location
if ($assembly.Location) { Get-FileHash -LiteralPath $assembly.Location -Algorithm SHA256 }
[AppDomain]::CurrentDomain.GetAssemblies() |
    Where-Object { $_.GetName().Name -eq 'HtmlAgilityPack' } |
    Select-Object FullName,Location
Start-PSWebCrawler -Doctor | ConvertTo-Json -Depth 6
```

Import retains the existing process-local TLS 1.2 initialization; these commands
make no persistent security change and perform no intentional network request.
Doctor itself is offline/read-only, but requires a successful import. If import
fails, stop and preserve its errors; an in-module Doctor cannot diagnose that
boundary. Do not make unapproved environment repairs to get past it.

## Decide which component needs maintenance

1. Record the problem and acceptance criterion: reproduced parsing defect,
   reviewed upstream fix, security advisory or explicit reproducibility need.
   A version difference alone does not justify replacement.
2. Identify the **loaded owner** from assembly location, loaded dependency
   module paths and hashes. Replacing the bundled DLL may not change the parser
   used by PSParseHTML. A PSParseHTML upgrade and any reproducible dependency
   pin are separate dependency decisions requiring their own approval/tests.
   Never overwrite DLLs inside an installed third-party PSParseHTML module.
3. Select an **exact** HAP version and source, not “latest automatically”.
   Review upstream changelog/release notes, API behavior, target-framework assets,
   runtime floor, assembly identity and dependency ownership/conflict risks.
   NuGet version, file version and assembly version need not be identical.
4. Obtain owner approval naming exact version, legitimate package/binary source,
   download permission, intended DLL paths, any metadata/docs edits and gates.
   Runtime changes, dependency changes and publication are not implied.

Canonical sources for manual review (links are guidance, not download approval):

- [HAP official source and releases](https://github.com/zzzprojects/html-agility-pack)
- [HAP NuGet package and framework assets](https://www.nuget.org/packages/HtmlAgilityPack)
- [Tested PSParseHTML package](https://www.powershellgallery.com/packages/PSParseHTML/3.0.6)

Read the exact candidate package's framework/dependency information; this guide
makes no claim about the current newest NuGet version or its framework policy.

## Approved acquisition, staging and rollback preparation

The remaining steps are **future procedural gates**, not executed maintenance.

1. Before any edit, preserve all original module bytes, inventory, revision,
   loaded identity/location and successful baseline receipts. Prove each original
   inventory entry against original bytes; never regenerate to hide drift.
2. Use a new owner-controlled scratch root for each attempt, outside the checkout
   and historical evidence. Retain original archive bytes, exact source URL,
   package identifier/version, retrieval context and original archive SHA256.
   Verify legitimacy against the trusted source and applicable signature/source
   policy. SHA256 establishes byte binding, **not authenticity** by itself;
   a public key token is not provenance verification either.
3. Extract the approved trusted package into scratch, inspect paths/assets,
   licenses, target framework, assembly references, identity and hashes before
   loading code. Reject unsafe paths/links or source uncertainty. A source build
   needs an approved source revision and reproducible toolchain/build provenance;
   it is not automatically equivalent to a published NuGet binary.
4. Select the Desktop-compatible asset deliberately. Do **not** blindly copy
   both package variants into `lib/Net45` and `lib/core`. Updating the retained
   core asset needs an explicit rationale/approval; it does not enable Core.
   Keep unapproved assets unchanged and review the exact intended DLL hash delta.
5. Preserve a restorable previous package, not just its old version number.
   Stop consuming processes before byte replacement and retain rollback evidence.
   Restore previous bytes/inventory/dependency selection as approved, then start
   a new process and repeat identity/smoke/integrity gates. `Remove-Module` and
   `Import-Module -Force` do **not** unload a .NET DLL from the AppDomain.
   Rollback cannot restore an already-loaded library inside that process.

## Candidate behavior and release gates

Use independent **fresh native processes** to separate these two questions:

- **Forced bundled candidate:** before any dependency import, load only the
  approved candidate Desktop DLL from scratch and exercise fixed in-memory HTML
  title/href/entity parsing and relevant parser fixtures/functions. Assert
  actual `[HtmlAgilityPack.HtmlDocument].Assembly` identity, location and file
  SHA256 equal the candidate. This is function/library evidence, not a complete
  product import. Stop if HAP was already loaded or the wrong asset is selected.
- **Real dependency integration:** import the exact candidate manifest normally,
  record available/loaded PSParseHTML, all loaded HAP assemblies, actual
  HtmlDocument owner, hashes and Doctor JSON at depth 6. Prove whether the new
  bundled bytes are actually used or a dependency-selected assembly wins.
  Passing smoke against the old/dependency DLL does not qualify the new bundled
  version. Capture assembly conflicts and load-order differences explicitly.

Discover the current tests and runner prerequisites before execution. At the
inspected revision, separate focused inventories are UrlEntry 15, Doctor 11 and
Doctor presentation 11; the existing runner has 78 outcomes (32/14/16/7/5/4).
These are revision-bound observations, **not permanent frozen counts**.
The existing runner requires already-installed PSParseHTML 3.0.6 (no alternate
available version), Pester 3.4.0 and .NET 4.8+. Do not edit those guards or install
anything silently to qualify a different dependency policy.

Approved full maintenance uses the existing native runner, with a new existing
owner-selected scratch parent, plus focused tests in separate fresh processes:

```powershell
# FUTURE APPROVED GATE: writes new receipts outside the repository.
powershell.exe -NoProfile -NonInteractive -File .\tests\Run-WindowsPreproduction.ps1 -OutputParent 'D:\scratch'
```

Focused files are `tests/UrlEntry.Tests.ps1`, `tests/Doctor.Tests.ps1` and
`tests/Doctor.Presentation.Tests.ps1`. Use installed Pester 3.4.0 and its
`Invoke-Pester -Script ... -PassThru` contract; presentation requires explicit
`SnapshotPath` via a Pester script hashtable's `Parameters`. Supply a preserved,
labeled representative Doctor snapshot; do not invent a fixture or omit that
parameter. Inspect current case definitions and preserve raw counts/results.
See [native runner contract](WINDOWS-PREPRODUCTION.md).

Require measured zero Failed/Pending/Skipped, clean exit/stderr, no timeout,
observed child exit/readers completion and current/candidate source hash parity.
Offline fixtures and passing smoke do not prove full compatibility, security,
real crawling, HTTPS/TLS correctness or the unqualified .NET 4.5 floor.

## Integrity, packaging and post-delivery proof

After the **final included edit**, and only for an approved actual package update:

```powershell
# FUTURE APPROVED WRITE: legitimate packaging, never Doctor repair.
.\tools\Update-PackageIntegrity.ps1
```

The existing parameterless tool inventories module-root files except the inventory
itself, offline without product import. Review old/new entries: only approved DLL
paths should change for a binary-only slice; metadata, module or packaged-doc hash
deltas require explicit inclusion/approval. Added/removed entries need review.
This repository-only guide/backlinks do not change shipped module bytes, so do
**not** regenerate `PackageIntegrity.json` for this documentation slice.

Materialize a fresh candidate from final bytes, bind every included file's size
and SHA256, create/extract a fresh ZIP and compare extracted bytes with source.
Retain ZIP SHA256, candidate binding, raw native receipts and test inventory in a
unique scratch root; never overwrite sealed historical evidence. A ZIP roundtrip
is not Gallery publication or a NuGet publication artifact.

Commit/push, Windows synchronization and publication each require separate owner
approval. After authorized delivery/sync, verify the exact Windows checkout/package
revision and package SHA256, fresh actual loaded identity/location/hash, Doctor
integrity and in-memory smoke. Scratch candidate success is not deployed-host
success, and Git sync does not replace functions/DLLs in an open PowerShell process.

## Verdict and STOP conditions

- **FAIL / STOP:** original baseline mismatch; unverified source; unsafe package;
  incompatible requirements/target; import/load failure; wrong asserted candidate
  identity/location/hash; parser regression; integrity failure; failed/incomplete
  required gate; or no proven restorable rollback. Preserve receipts and ask the
  owner for the smallest required decision; never suppress FAIL or repair hashes.
- **WARN / review:** dependency-owned HAP differs but actual smoke passes, known
  legacy display mismatch or unqualified runtime coverage. Record impact and
  acceptance limitation separately; no automatic downgrade/upgrade. FAIL takes
  precedence over WARN. `Healthy=true` is not `Qualified=true` or release approval.
- Maintenance is complete only when approved scope, final bytes, fresh native
  gates, rollback readiness and separately authorized post-delivery proof agree.
  Record verified results versus unexecuted future steps in existing PLAN/STATUS;
  do not create a competing product SSOT or rewrite historical evidence.
