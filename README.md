# PSWebCrawler

[![status](https://img.shields.io/badge/PROD-v0.0.1-green)](https://github.com/voytas75/PSWebCrawler/blob/master/PSWebCrawler/docs/ReleaseNotes.md) &nbsp; [![PowerShell Gallery Version (including pre-releases)](https://img.shields.io/powershellgallery/v/PSWebCrawler)](https://www.powershellgallery.com/packages/PSWebCrawler) &nbsp; [![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/PSWebCrawler)](https://www.powershellgallery.com/packages/PSWebCrawler)

[![status](https://img.shields.io/badge/DEV-v0.0.2-red)](https://github.com/voytas75/PSWebCrawler/blob/master/PSWebCrawler/docs/ReleaseNotes.md)

# PSWebCrawler

PSWebCrawler is a PowerShell script that provides web crawling and URL processing functionality. It allows you to crawl web pages, extract information, and store data for analysis or further processing.

## Features

- Web crawling with customizable depth.
- Handling of external and internal links.
- Option to crawl only specific domains.
- Timeout settings for URL accessibility testing.
- Cache folder management for storing crawled data.

## Usage

- `Start-PSWebCrawler` cmdlet allows you to initiate web crawling with various parameters.
- `Get-PSWCHttpResponse` retrieves HTTP responses for a given URL.
- `Get-PSWCDocumentElements` extracts HTML elements from web page content.
- `Set-PSWCCleanWebsiteURL` cleans and formats website URLs.
- `Get-PSWCSchemeAndDomain` extracts the scheme and domain from a URL.
- `New-PSWCCacheFolder` creates a cache folder for storing crawled data.
- `Open-PSWCExplorerCache` opens the cache folder in Windows Explorer.

## Usage Examples

- Crawl a web page with a specified depth: `PSWC -Url "https://example.com" -Depth 2`
- Crawl and filter by domains: `PSWC -Url "https://example.com" -Depth 2 -onlyDomains`
- Display the cache folder: `PSWC -ShowCacheFolder`

## Installation

1. Clone or download the script.
2. Import required .NET libraries and configure TLS settings.
3. Set aliases for easier usage.
4. Enjoy web crawling with PSWebCrawler!


## Installation and Usage

The module is available on [PowerShell Gallery](https://www.powershellgallery.com/packages/PSWebCrawler).

```powershell
Install-Module -Name PSWebCrawler
```

Import module:

```powershell
Import-Module -Module PSWebCrawler
```

To get all commands in installed module including cmdlets, functions and aliases:

```powershell
Get-Command -Module PSWebCrawler
```

Start module:


## Versioning

We use [SemVer](http://semver.org/) for versioning.

## Contributing

We welcome contributions from the community! Feel free to submit pull requests, report issues, or suggest new features to make the framework even more powerful and user-friendly.

**Clone the Repository:** Clone the PSWebCrawler repository to your local machine.

### License

The PSWebCrawler is released under the [MIT License](https://github.com/voytas75/PSWebCrawler/blob/master/LICENSE).

**Contact:**
If you have any questions or need assistance, please feel free to reach out to us via [GitHub Issues](https://github.com/voytas75/PSWebCrawler/issues).

Join us on the journey to make PowerShell scripting a truly awesome experience!
