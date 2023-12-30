# PSWebCrawler

![PowerShell Web Crawler](https://raw.githubusercontent.com/voytas75/PSWebCrawler/master/images/PSWC_github_logo.png "PowerShell Web Crawler")

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/A0A6KYBUS)

[![status](https://img.shields.io/badge/PROD-v0.0.5-green)](https://github.com/voytas75/PSWebCrawler/blob/master/PSWebCrawler/docs/ReleaseNotes.md) &nbsp; [![status](https://img.shields.io/badge/DEV-v0.1.0-red)](https://github.com/voytas75/PSWebCrawler/blob/master/PSWebCrawler/docs/ReleaseNotes.md) &nbsp; ![PowerShell version](https://img.shields.io/badge/PowerShell-v5.1-blue) &nbsp; [![PowerShell Gallery Version (including pre-releases)](https://img.shields.io/powershellgallery/v/PSWebCrawler)](https://www.powershellgallery.com/packages/PSWebCrawler) &nbsp; [![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/PSWebCrawler)](https://www.powershellgallery.com/packages/PSWebCrawler)

## Overview

PSWebCrawler is a PowerShell script that provides web crawling and URL processing functionality. It allows you to crawl web pages, extract information, and store data for analysis or further processing.
Module depends on the [HtmlAgilityPack (HAP)](https://github.com/zzzprojects/html-agility-pack) library, a .NET library that provides an agile and easy way to manipulate HTML documents.

## PSWebCrawler module features

- Web crawling functionality to retrieve HTML content from specified URLs
- Ability to extract and save images from web pages
- Extraction and storage of contact information from web pages
- Retrieval and storage of HTML head data
- Cache folder creation and data folder setup

## Installation

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

### Crawl

- `PSWC` (alias of `Start-PSWebCrawler`). When the `PSWC` command is run alone, it displays a menu with various options and examples for using the PSWebCrawler module. This menu provides examples of how to use the PSWC command with different parameters to initiate web crawling with various configurations, such as crawling web pages with specified depths, displaying cache folders, and extracting specific elements from web pages.

    Start module to display possible options and examples:

    ```powershell
    PSWC
    ```

    or

    ```powershell
    Start-PSWebCrawler
    ```

- When the `PSWC` command is used with the `url` and `depth` parameters, it initiates web crawling starting from the specified URL and crawling to the specified depth. This allows the user to extract various elements from the web pages, such as href elements, non-href elements, domains, and internal links, up to the specified depth. The command also logs and stores the extracted data in the default log folder (user' document folder), providing a record of the crawling process and the extracted elements for further analysis or reference:

    ```powershell
    PSWC -Url "https://example.com" -Depth 2
    ```

- The `onlyDomains` parameter, when set to true, instructs the web crawler to only crawl to the domains found in the href elements of the web page being crawled. This means that the crawler will restrict its exploration to the domains referenced by the links on the page, rather than following links to external domains:

    ```powershell
    PSWC -Url "https://example.com" -Depth 2 -onlyDomains
    ```

- The `outputFolder` parameter is used to specify the path where the log and data folders will be created when the `Url` and `Depth` parameters are used. When initiating a web crawl with the Url and `Depth` parameters, the `outputFolder` parameter allows you to define the location where the log and data folders will be stored for the crawl. This can be useful for organizing and managing the output of the web crawling operation. If the `outputFolder` parameter is not provided the log and data folders will be stored in the default location. The default location is the user's document folder under the 'PSWebCrawler' directory:

    ```powershell
    PSWC -Url "https://example.com" -Depth 2 -outputFolder "C:\temp\logs\"
    ```

    More about log and data folder: [Default Log and Data Folder](#default-log-and-data-folder)

- The `resolve` parameter is used when initiating a web crawl with the `Url` and `Depth` parameters. When `resolve` switch is on, the web crawler will resolve the domain name of current processed URL to IP address:

    ```powershell
    PSWC -Url "https://example.com" -Depth 2 -resolve
    ```

### ShowCacheFolder

- The `ShowCacheFolder` option is used to open the default log and data folder (user's document folder under the 'PSWebCrawler' directory) in Windows File Explorer:

    ```powershell
    PSWC -ShowCacheFolder
    ```

    More about log and data folder: [Default Log and Data Folder](#default-log-and-data-folder)

### ShowAllElements

- The `PSWC` command with the `ShowAllElements` and `Type` options extracts all elements from the specified `URL`, including Href elements, non-Href elements, domains, and internal links. The `Type` parameter in the command specifies which type of elements to extract. It can be set to one of the following values:

  - **Href**: extracts only elements with an href attribute.
  - **noHref**: extracts only elements without an href attribute.
  - **onlyDomains**: extracts only the domains from the href attributes.
  - **All**: extracts all elements from the specified `URL`.

  To use this option, you can run the following command:

  ```powershell
  PSWC -ShowAllElements -Type All -Url 'https://www.example.com'
  ```

    This example extracts all elements from the URL "https://www.example.com"

### GetImageUrls

- The `GetImageUrls` option in `PSWC` retrieves the URLs of all images in an HTML document. The retrieved URLs are saved in a text file named *Images.txt* in the session folder. To use this option, run the command:

  ```powershell
  PSWC -GetImageUrls -url "https://example.com"
  ```

  The saved file path will be displayed in the console output.

### GetHTMLMetadata

- The `GetHTMLMetadata` option in the `PSWC` module retrieves metadata from the specified HTML content and displays it. The metadata includes the title, description, keywords, author, copyright, robots, viewport, and generator. Retrieved data are saved in a text file named *metadata.txt* in the session folder. To use this option, run the command:

  ```powershell
  PSWC -GetHTMLMetadata -url "https://example.com"
  ```

  The saved file path will be displayed in the console output.

### GetContactInformation

- The `GetContactInformation` option in the PSWebCrawler PowerShell module extracts contact information (emails, addresses, phone numbers) from an HTML document. Once the function is executed, it will return the extracted contact information in JSON format. Additionally, the option saves the extracted contact information to a file named *Contact.json* in the session folder. The session folder is created automatically and its path is logged in the "Settings.log" file. To call the option, use the following command:

  ```powershell
  PSWC -GetContactInformation -url "https://example.com"
  ```

  The saved file path will be displayed in the console output.

### GetHeadersAndValues

- The `GetHeadersAndValues` option in the PSWebCrawler PowerShell module extracts headers and their corresponding values from the `<head>` section of an HTML document. To use this option, you need to provide the URL of the website you want to crawl using the `url` parameter. The extracted headers and values are returned as a hashtable. You can save the output to a file by specifying the output folder using the `outputFolder` parameter. Without `outputFolder` data are saved the extracted contact information to a file named *HTMLhead.json* in default place, the session folder.  To call the option, use the following command:

  ```powershell
  PSWC -GetHeadersAndValues -url "https://example.com"
  ```

## Default Log and Data Folder

The PSWebCrawler module uses default folder for storing log files and data. If specific paths are not provided, the module uses `<User's document folder>/PSWebCrawler/` folder.

User can override these default paths by providing custom paths using `outputFolder` parameters when using the module's functions. For example:

```powershell
PSWC -Url 'https://example.com' -Depth 2 -outputFolder 'C:\Crawl\LOGandDATA\'    
```

*INFO*: In the PSWebCrawler PowerShell module, the default location for the log and data folder is the user's document folder. If the log and data folder does not exist, it will be created automatically when the module is imported.

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
