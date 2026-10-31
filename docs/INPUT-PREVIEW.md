# Local HTML links and execution previews (repository candidate)

These flags belong to the prepared, unpublished 0.2.0 repository module. They
are not a claim about the current Gallery package. Load the exact manifest in
a fresh Windows PowerShell 5.1 Desktop process.

## Local input

```powershell
Import-Module .\PSWebCrawler\PSWebCrawler.psd1 -Force -ErrorAction Stop
PSWC -HtmlPath 'C:\fixtures\saved page.html' -outputFolder 'C:\PSWC-results'
PSWC -HtmlPath 'C:\fixtures\saved page.html' -BaseUrl 'https://example.test/dir/page' -Type noHref
```

`HtmlPath` is one explicit readable filesystem file, resolved literally (spaces,
Unicode and wildcard characters in filenames are not expanded). The file's
contents are parsed as UTF-8 HTML (with BOM detection) regardless of extension. No page request, DNS
lookup or recursive crawl occurs. `Url` and `HtmlPath` are mutually exclusive;
local input does not support image/contact/metadata/header operations, Doctor,
Depth, Resolve, ShowAllElements or the legacy `onlyDomains` switch.

Local analysis reuses the legacy HAP anchor parser and categories. `Type` accepts
`All` (default), `Href`, `noHref`, `onlyDomains`:

- Href: unique sorted absolute HTTP(S) href values, written to `UrlsUnique.txt`.
- noHref: other href values, written to `noHrefUnique.txt`; resolved relative
  references, if an explicit base is given, to `InternalLinksUnique.txt`.
- onlyDomains: scheme/host of absolute HTTP(S) hrefs to `DomainsUnique.txt`;
  this is extraction, not DNS resolution or the future Domains API.
- All: all four category files when anchors exist. No anchors means no category
  files, retaining legacy behavior.

Legacy `mailto:` stripping is retained. Relative values remain verbatim in
NonHrefs. Only explicit `BaseUrl` resolves relative paths, query and fragments
into InternalLinks; HTML `base` tags are ignored. BaseUrl must be absolute
HTTP(S), is syntactically validated and normalized by System.Uri, never fetched.
This is not a URL-normalization refactor or a hostile-HTML security audit.

Single-page extraction skips malformed HTTP links before adding them to result
arrays or files. Each skipped link emits `Skipped malformed HTTP link.` on the
warning stream, without exposing the href or changing LinkAnalysis schema 1.0.
URI conversion failures are isolated per anchor; file and parser errors still
terminate. Existing URL-input relative-link coverage and domain/port behavior
are unchanged. HTTP request exceptions (including connection failures and
timeouts) terminate without automatic retry. A malformed User-Agent format
retains the legacy header-only fallback: one request without that header.
HTTP 404/500 remain status responses and do not produce a successful analysis.

Local execution returns the single-page output contract below, with SourcePath
retained as the actual local file path. Type selects saved files; arrays retain
all extracted categories.
It also uses existing timestamped session folders, Settings.log and module
logging. Thus offline local execution is **not write-free**. Without explicit
outputFolder it retains legacy output-folder discovery/creation. File content
can change between validation and parsing; later I/O errors remain terminating.

## Single-page output contract

`ShowAllElements`, URL-only entry and local HTML return exactly one
`PSWebCrawler.LinkAnalysis` on successful analysis, including empty HTML.
This fixes ordinary assignment returning the logo rather than link data.
SchemaVersion is `1.0`; this does not change Doctor or preview schemas.

```powershell
$links = PSWC -HtmlPath 'C:\fixtures\saved page.html' -Type All
$links.Hrefs
$links.Counts
$links.OutputFiles
$links | ConvertTo-Json -Depth 6
# Menu example [3]: remote analysis makes a request and retains file writes.
$result = PSWC -ShowAllElements -Type All -Url 'https://example.org/'
$result.Hrefs
$result.Counts
$result.OutputFiles
```

Fields: `SchemaVersion`, `Operation` (`ShowAllElements` or `LocalHtmlLinks`),
`InputKind` (`Url` or `LocalHtml`), `SourceUrl` (supplied remote URL), `HtmlPath`
(resolved local path), `SourcePath` (compatibility alias of HtmlPath), `BaseUrl`
(explicit local resolution base), `Type`, `Hrefs`, `NonHrefs`, `InternalLinks`,
`Domains`, `Counts`, `OutputFiles`, `SessionFolder`. Inactive provenance is null.
The four category fields are unique sorted `string[]`, including empty arrays.
Counts contains matching integer Hrefs/NonHrefs/InternalLinks/Domains counts.
All computed categories remain available regardless of Type; Type selects files
using the mapping above. OutputFiles has only existing paths written by the
selected branch, keyed Hrefs/NonHrefs/InternalLinks/Domains plus SettingsLog
when present. Empty anchors preserve no category files and zero counts.
No analysis object is returned for failed HTTP; legacy messages are preserved.
There is no new structured contract for other legacy extraction/crawl modes.

Banner and status messages use the information/host stream, not success output.
Ordinary assignment and `ConvertTo-Json` therefore consume data. Explicit stream
merging (`6>&1` or `*>&1`) also captures presentation and is not a data-only
contract. Existing onlyDomains switch semantics and relative resolution remain
unchanged; BaseUrl never authorizes a request.

## DryRun and Preview are aliases for one behavior

```powershell
PSWC -Url 'https://example.test/page' -DryRun | ConvertTo-Json -Depth 6
PSWC -HtmlPath 'C:\fixtures\saved page.html' -Preview | ConvertTo-Json -Depth 6
PSWC -Url 'https://example.test' -Depth 2 -Resolve -outputFolder 'C:\PSWC-results' -Preview
PSWC -DryRun
```

Preview returns exactly one `PSWebCrawler.Plan` object with SchemaVersion 1.0,
Operation, InputKind, Input, EffectiveOptions, NetworkRequired,
PlannedOutputLocation, Effects and Limitations. NetworkRequired describes the
**planned execution**, not a request made by preview. Supported operations are
legacy URL extraction/crawl, cache-folder operation and local links. No input
plans HelpMenu with no effects. Doctor rejects both spellings; its schema is
unchanged. No pipeline input contract is added. EffectiveOptions retains exactly
Type, Depth, Resolve, OnlyDomains and BaseUrl; inactive fields are JSON null.
Type applies only to ShowAllElements/local links; Depth and Resolve only to
WebCrawl; OnlyDomains only to WebCrawl/ShowAllElements; BaseUrl only to local
links with an explicit supplied base. Active effective defaults are preserved.
SchemaVersion remains 1.0 for this unpublished feature contract; this does not
change the Doctor schema. A URL-only plan has Depth=null: no hidden recursive
crawl is implied.

Preview validates supplied URL/base syntax and local file metadata/readability
without prompting, parsing HTML, HTTP/DNS, banner, timing, random User-Agent,
output-folder initialization, logs/files or Explorer. Invalid inputs terminate
with English errors (binding errors may be PowerShell-owned). Existing module
import/dependency loading and process TLS initialization are unchanged and
outside this invocation guarantee. Counted forbidden-seam tests are not OS
network/filesystem isolation.

The plan does not predict results, connectivity or permissions at execution.
Default output is either the already-known module path or an explicit unresolved
legacy UserDoc discovery/creation description; timestamped session names are
not invented. Effects describe possible legacy writes, not completed effects.
URL-only still means one-page All extraction; explicit Depth still selects crawl.
Shared URL+onlyDomains binding ambiguity remains outside this bounded change.

## Native offline tests (repository tools only)

```powershell
Invoke-Pester .\tests\LocalHtml.Tests.ps1
Invoke-Pester .\tests\DryRun.Tests.ps1
```

Local tests use temporary fixtures and counted HTTP/DNS/crawl fakes. Preview
forbids transport, parser, output/logging, prompt and Explorer seams. The existing
URL-entry, Doctor, presentation and Windows preproduction suites remain separate
regression gates. Tests and this guide are repository-only, not extra exports or
installed-module files.
