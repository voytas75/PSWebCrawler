# PowerShell Web Crawler (PSWebCrawler) - release notes

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/) and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.2.0] - prepared, not published

### Current scope and acceptance

- Completed outputFolder support for every existing producing operation and
  ShowCacheFolder. The selected root now owns module logs and session/result
  files from initialization onward, without external module-variable setup or
  default Documents writes. Relative filesystem paths are resolved and invalid
  roots rejected before effects; changing roots between calls is supported.
  Doctor excludes outputFolder; previews and the help menu remain write-free.
  Recursive child page/cache artifacts use the selected root, including literal
  bracket paths for response-header writes. Native offline real-file fixtures
  cover Depth=2 and empty categories; legacy crawl accuracy and production HTTP
  remain outside this path-routing qualification.

- Single-page link extraction now skips malformed HTTP hrefs with a generic
  warning, preserving valid links and the existing result schema and files.
- HTTP connection/timeout exceptions are no longer automatically retried or
  treated as User-Agent errors. Header-format fallback occurs before the single
  request, without the malformed header; HTTP error statuses remain unchanged.

- Fixed single-page link extraction assignment: the banner uses host information,
  and ShowAllElements, URL-only and local HTML return one LinkAnalysis object
  with categories, counts, provenance and existing saved paths. Type selects
  files while the result retains all categories; other legacy modes are unchanged.

- Added `Start-PSWebCrawler -Doctor`: separate offline diagnostic parameter set,
  required-file presence inventory; paths only, no runtime byte comparison.
  Checks package paths only; changed-present file content is deliberately outside its contract.

- Public export is `Start-PSWebCrawler` only, with aliases `PSWC` and `PSWebCrawler`. `Invoke-PSWebCrawler` is retained as private implementation, not a supported public API; internal contract tests remain.

- Contracts/analysis only for the private new-API implementation: Site schema, URI/extraction analysis and bounded orchestration are qualified with counted private policy/transport fixtures, not enabled production fetching. Site fails closed with `CapabilityUnavailable`; Domains with `UnsupportedMode`.
- Manual Windows PowerShell 5.1 Desktop acceptance passed all 78 existing outcomes: S2 32, S3 14, S4 16, baseline 7, dependency/import 5 and import-runtime 4; zero failed, pending or skipped. Real imports ran without enforced network isolation; this is not production transport or TLS qualification.
- Legacy network-capable commands remain unchanged by this documentation scope decision. C2/B2 fetch integration, HTTPS/TLS and S7 Domains move to the [future roadmap](https://github.com/voytas75/PSWebCrawler/blob/master/docs/ROADMAP.md), not gates for this contracts/analysis release.
- Package metadata is prepared for 0.2.0; publication is manual and owned by the user. This is not a publication announcement.

## [0.1.0] - 2024.01.30

### Added

- n/a

### Changed

- n/a

## [0.0.5] - 2023.12.30

### Added

- Moved some functions to new `Private`, `Public` folders for better organization and management

### Changed

- [Html Agility Pack (HAP)](https://github.com/zzzprojects/html-agility-pack) new version (1.11.57)

## [0.0.4] - 2023.12.19

### Added

- [#31](https://github.com/voytas75/PSWebCrawler/issues/31)
- [#15](https://github.com/voytas75/PSWebCrawler/issues/15)
- [#17](https://github.com/voytas75/PSWebCrawler/issues/17)
- [#18](https://github.com/voytas75/PSWebCrawler/issues/18)
- [#19](https://github.com/voytas75/PSWebCrawler/issues/19)
- [#20](https://github.com/voytas75/PSWebCrawler/issues/20)
- [#21](https://github.com/voytas75/PSWebCrawler/issues/21)
- [#44](https://github.com/voytas75/PSWebCrawler/issues/44)

### Changed

- [#30](https://github.com/voytas75/PSWebCrawler/issues/30)
- [#16](https://github.com/voytas75/PSWebCrawler/issues/16)

## [0.0.3] - 2023.12.12

### Added

- n/a

### Changed

- `FunctionsToExport`

## [0.0.2] - 2023.12.12

### Added

- log function `Write-Log`
- new function `Get-PSWCAllElements`
- HTML metadata function `Get-PSWCHTMLMetadata`
- image Urls function `Get-PSWCImageUrls`
- contact function `Get-PSWCContactInformation`
- header function `Get-PSWCHeadersAndValues`
- resolve function `Get-PSWCGetHostAddresses`
- `lib` folder
- `PSparceHTML` dependency ([#2](https://github.com/voytas75/PSWebCrawler/issues/2))
- time measure
- data, session folders

### Changed

- function `Start-PSWCCrawl`
- [#1](https://github.com/voytas75/PSWebCrawler/issues/1)
- [#5](https://github.com/voytas75/PSWebCrawler/issues/5)
- real-time console interface
- [#7](https://github.com/voytas75/PSWebCrawler/issues/7)
- [#14](https://github.com/voytas75/PSWebCrawler/issues/14)
- [#13](https://github.com/voytas75/PSWebCrawler/issues/13)
- [#12](https://github.com/voytas75/PSWebCrawler/issues/12)
- [#11](https://github.com/voytas75/PSWebCrawler/issues/11)
- [#10](https://github.com/voytas75/PSWebCrawler/issues/10)
- [#9](https://github.com/voytas75/PSWebCrawler/issues/9)
- [#8](https://github.com/voytas75/PSWebCrawler/issues/8)

## [0.0.1] - 2023.10.12

### Added

- Initializing project

### Changed

- n/a
