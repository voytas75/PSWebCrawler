# Test base

## Runtime and execution
Windows PowerShell 5.1 Desktop; existing Pester 3.4.0. No Python, Linux pwsh, installs or public HTTP. Baseline tests do not import the product; the current contract/full preproduction gates do.
Run in a fresh process: powershell.exe -NoProfile -File .\tests\Run-Baseline.ps1.
If source is accessed over WSL UNC, .NET may reject DLL loading. Copy only PSWebCrawler/ and tests/ into a new local Windows scratch directory and run there. Do not enable loadFromRemoteSources, change persistent execution policy or overwrite D:\repos\PSWebCrawler. Verify copied file hashes against sources before interpreting results.

## Baseline coverage
Seven tests characterize the current implementation: Desktop runtime, parsing, absolute images, root/parent relative images, unresolved plain relative images, external-only recursion, and start-host inclusion in domain extraction.
The last three intentionally document gaps. Green baseline is NOT v1 acceptance. Change them into regression expectations when separately approved implementation addresses the corresponding contract. Tests load selected functions through AST and use a local fake HTTP function; generated files use Pester TestDrive. No PSparseHTML dependency is required because full import and conversion paths are not exercised.

## Future v1 acceptance matrix — not implemented or counted as tests
- Site: same-host links visited; foreign hosts/subdomains and redirects outside scope recorded, not fetched.
- Domains: one page per host; first discovered URL and all host edges preserved.
- Depth 0/1/2, BFS, deduplication/cycles, query preservation, fragment removal, base href.
- Isolated state across runs; machine-readable Run/Pages/Links/Errors and JSON parity.
- Page/host/time/size limits return partial result with cause.
- robots.txt missing/error/disallow; host request spacing; private/local target denial including redirects.
- Invalid inputs fail without prompts; import makes no network calls and does not terminate the process.
- Native full invocation on Windows 5.1 with explicitly approved dependency setup.

## Current Site/internal contract gate
Run-SiteContract.ps1 runs 32 S2, 14 S3 and 16 S4 active cases with real imports in native Windows PowerShell 5.1. `Invoke-PSWebCrawler` remains private and is exercised through `InModuleScope` or explicit module invocation in fresh children. The manifest and fresh-import checks require only `Start-PSWebCrawler` publicly exported, with aliases `PSWC` and `PSWebCrawler`, and no public `Invoke-PSWebCrawler` command. Safe invalid-argument and unavailable-capability assertions are retained.

For the full 78-outcome gate, including baseline 7, dependency/import 5 and import-runtime 4, use [manual Windows preproduction](../docs/WINDOWS-PREPRODUCTION.md). No failed, pending, skipped or reduced-count result is accepted. These offline fixtures do not qualify production fetching, TLS or Domains; legacy crawling remains network-capable and is not intentionally exercised.

## Limits and next slice
The baseline alone cannot qualify Site or Domains v1, actual HTTP, cancellation, robots, network controls, output schema or full import. The current full gate qualifies internal offline contracts and real imports only, not enabled production transport. No CI changes are included.
