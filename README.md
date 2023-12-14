# PSWebCrawler

[![status](https://img.shields.io/badge/PROD-v0.0.3-green)](https://github.com/voytas75/PSWebCrawler/blob/master/PSWebCrawler/docs/ReleaseNotes.md) &nbsp; [![PowerShell Gallery Version (including pre-releases)](https://img.shields.io/powershellgallery/v/PSWebCrawler)](https://www.powershellgallery.com/packages/PSWebCrawler) &nbsp; [![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/PSWebCrawler)](https://www.powershellgallery.com/packages/PSWebCrawler)

[![status](https://img.shields.io/badge/DEV-v0.0.4-red)](https://github.com/voytas75/PSWebCrawler/blob/master/PSWebCrawler/docs/ReleaseNotes.md)

PSWebCrawler is a PowerShell script that provides web crawling and URL processing functionality. It allows you to crawl web pages, extract information, and store data for analysis or further processing.

## PSWebCrawler module features

- Web crawling functionality to retrieve HTML content from specified URLs
- Ability to extract and save images from web pages
- Extraction and storage of contact information from web pages
- Retrieval and storage of HTML head data
- Cache folder creation and data folder setup

## Installation and usage

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

## Usage

- `Start-PSWebCrawler` cmdlet allows you to initiate web crawling with various parameters.

    Start module to display possible options:

    ```powershell
    PSWC
    ```

    `PSWC` is alias of `Start-PSWebCrawler`.

- Crawl a web page with a specified depth:

    ```powershell
    PSWC -Url "https://example.com" -Depth 2
    ```

- Crawl and filter by domains:

    ```powershell
    PSWC -Url "https://example.com" -Depth 2 -onlyDomains
    ```

- Display the cache folder:

    ```powershell
    PSWC -ShowCacheFolder
    ```

## Default Log and Data Folder

The PSWebCrawler module uses default folder for storing log files and data. If specific paths are not provided, the module uses `<User's document folder>/PSWebCrawler/` folder.

User can override these default paths by providing custom paths using `outPath` parameters when using the module's functions. For example:

```powershell
PSWC -Url 'https://example.com' -Depth 2 -outPath 'C:\Crawl\LOGandDATA\'    
```

For more details on customizing log and data folder paths, refer to the module's documentation or help files.

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
