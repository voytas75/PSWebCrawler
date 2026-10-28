# PSWebCrawler: execution rules

## Authority
- PLAN.md: product contract; BOUNDS.md: execution limits; STATUS.md: evidence/checkpoint. Read available files before changes.
- These three files are local-only via .git/info/exclude; AGENTS.md is versionable. Missing local documents do not authorize development: obtain scope/bounds from the user, never reconstruct requirements by inference.
- Check Git status, branch, HEAD; preserve existing changes. Proposals/open decisions are not implementation approval.

## Decision gate
Before the first API/schema/architecture/security/sequencing recommendation, critically check assumptions, contract conflicts, compatibility, failure/edge cases, cost and verifiability. State the main risk, simplest viable alternative and observable reversal trigger; distinguish evidence from proposals. Revise before requesting approval. Repeat only when new evidence changes an accepted decision.

## Execution
- Source/Git owner: /home/voytas/projects/PSWebCrawler. Windows checkout D:\repos\PSWebCrawler: native acceptance copy; no automatic synchronization.
- Helpers, parsing, calculations, diagnostics and tests: Windows-host PowerShell only. No Python or Linux pwsh. WSL may invoke powershell.exe -NoProfile; process tests use -NonInteractive and bounded timeouts.
- No incidental features/refactors, broad formatting, speculative layers or directory restructuring.
- New dependencies, API/runtime changes, CI, security settings, commits, push/publication require explicit scope-specific approval.
- Inspect import side effects before execution. Use offline fixtures/counted fakes by default; public crawling requires approval.

## Map
- PSWebCrawler/PSWebCrawler.psd1: dependencies, compatibility, exports.
- PSWebCrawler/PSWebCrawler.psm1: Start-PSWebCrawler, Start-PSWCCrawl, HTTP, extraction, logging, initialization.
- PSWebCrawler/Private/Get-PSWCImageUrls.ps1: image URLs; Private/watch.ps1: timing.
- PSWebCrawler/lib/Net45: Desktop assembly; lib/core presence does not imply Core support.
- PSWebCrawler/Data/useragents.txt: User-Agent list.
- README.md, PSWebCrawler/docs/ReleaseNotes.md: user claims; verify against code/tests.
- tests/: regression/characterization and pending contract gates; temp/: experiments, not test coverage.

## Slice approval cycle
After every task: execute its agreed verification, update PLAN.md slice status and STATUS.md evidence/next action, report outcome and unresolved limits, then request explicit approval for the next step. Do not start the next slice automatically; completion of a task or approval of the overall plan does not grant next-step permission.

## Verification/closeout
Agree acceptance/tools before code changes; do not install automatically. Distinguish parser, static analysis, isolated tests, real-process/import tests and native Windows PowerShell 5.1 acceptance. Mocked HTTP is not network-security qualification; style warnings are not reproduced defects.
Update STATUS.md with scope, executed results, limits and next approved action. Report files, diff/numstat, Git state; distinguish implemented/tested/native-verified/committed/published. Do not claim completion from partial acceptance.
