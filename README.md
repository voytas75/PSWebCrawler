# PSWebCrawler

![PowerShell Web Crawler](https://raw.githubusercontent.com/voytas75/PSWebCrawler/master/images/PSWC_github_logo.png "PowerShell Web Crawler")

[![PowerShell version](https://img.shields.io/badge/PowerShell-v5.1-blue)](readme-dev.md) [![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PSWebCrawler)](https://www.powershellgallery.com/packages/PSWebCrawler)

## What it is

PSWebCrawler is a Windows PowerShell module for legacy web crawling, HTML
extraction and saving URL/contact/metadata results. It uses
[HtmlAgilityPack](https://github.com/zzzprojects/html-agility-pack) and PSParseHTML.
Its public command is **`Start-PSWebCrawler`**, with aliases **`PSWC`** and
**`PSWebCrawler`**. The repository also provides an offline `-Doctor` report.

Repository metadata is **0.2.0, prepared but not published**. The new internal
implementation has offline-tested contracts, analysis and orchestration, **not
production fetching**. Gallery installation and repository loading are separate
paths; do not assume the published package includes the repository's Doctor.

## What it is not

- Not a supported Linux or PowerShell 7/Core crawler: the target is Windows
  PowerShell 5.1 Desktop.
- Not an enabled public new Site/Domains API. `Invoke-PSWebCrawler` is private;
  internal Site returns `CapabilityUnavailable`, Domains `UnsupportedMode`.
- Not production transport or HTTPS/TLS qualification. Future fetch integration
  and Domains are deferred; existing legacy commands remain network-capable.
- Image URL extraction is not image downloading; JavaScript execution is not
  part of the intended v1 scope.

## Requirements

Use **Windows PowerShell 5.1 Desktop**. The manifest declares .NET Framework
**4.5** and required module **PSparseHTML**; the newer native qualification uses
**.NET Framework 4.8+** and **PSParseHTML 3.0.6**. That qualification does not prove
support on the older manifest minimum. Pester is for development tests, not a
production requirement. See [developer setup](readme-dev.md).

## Install or load

### Published package

This installs the available published version, **not a promise of 0.2.0**:

```powershell
Install-Module -Name PSWebCrawler -Scope CurrentUser
Import-Module -Name PSWebCrawler -ErrorAction Stop
Get-Module PSWebCrawler | Select-Object Name, Version, Path
```

Review dependency prompts; do not change repository trust or security settings
just to complete installation. Publication of 0.2.0 remains manual.

### Current repository

Clone or download the [source](https://github.com/voytas75/PSWebCrawler), then
use a fresh Windows PowerShell process from its root. Install the tested
required dependency first if it is missing (this is an explicit installation):

```powershell
Install-Module -Name PSParseHTML -RequiredVersion 3.0.6 -Scope CurrentUser
Import-Module .\PSWebCrawler\PSWebCrawler.psd1 -ErrorAction Stop
Get-Module PSWebCrawler | Select-Object Name, Version, Path
```

## Run

Display the legacy options/examples without starting a crawl:

```powershell
Start-PSWebCrawler
# Equivalent: PSWC or PSWebCrawler
Get-Command -Module PSWebCrawler
```

After loading the current repository module, run offline diagnostics:

```powershell
Start-PSWebCrawler -Doctor | ConvertTo-Json -Depth 6
# Equivalent: PSWC -Doctor or PSWebCrawler -Doctor
# Optional repository-only English presentation (not a module command):
$report = Start-PSWebCrawler -Doctor
$report | .\tools\Show-PSWCDoctor.ps1
.\tools\Show-PSWCDoctor.ps1 -Report $report -View Detail -CheckName HapIdentity
```

Doctor needs successful import and returns PASS/WARN/FAIL with hints; it does
not install, repair or qualify networking. WARN may coexist with `Healthy=true`.
Import itself still performs legacy TLS initialization. See [Doctor](docs/DOCTOR.md).

Legacy URL operations can fetch live pages and write files. Use only with
permission to access the target; they are outside the offline acceptance proof.
[Developer/reference notes](readme-dev.md) contain the legacy parameter examples,
output behavior and known limitations.

## More information

- [Developer setup, legacy reference and verification](readme-dev.md)
- [Release notes](PSWebCrawler/docs/ReleaseNotes.md)
- [Upgrade guidance](docs/UPGRADING.md) · [Future roadmap](docs/ROADMAP.md)
- [GitHub Issues](https://github.com/voytas75/PSWebCrawler/issues)

Released under the [MIT License](LICENSE). Author: Wojciech Napierala;
project/vendor: Script Savvy Ninja.
[Support the author on Ko-fi](https://ko-fi.com/A0A6KYBUS).
