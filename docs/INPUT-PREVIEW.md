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

Local execution returns one object with SourcePath (the actual file path, not an
invented HTTP page URL), BaseUrl, Type and Hrefs/NonHrefs/Domains/InternalLinks
arrays. Type selects saved files; arrays retain all extracted categories.
It also uses existing timestamped session folders, Settings.log and module
logging. Thus offline local execution is **not write-free**. Without explicit
outputFolder it retains legacy output-folder discovery/creation. File content
can change between validation and parsing; later I/O errors remain terminating.

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
