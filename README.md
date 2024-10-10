# rr-dl

_Royal Road Novel Downloader_

## Usage

```
rr-dl 1.1.0
-----------------------------------------------
Usage: rr-dl [options] [ARGS]

Description: A cli program for downloading novels from royalroad.com

Options:
  -a, --all                 Select all chapters
  -t, --title               Add chapter title to start of file
  -I, --indexing <int>      Index chapters starting from value
  -i, --index               Prefix title with chapter index
  -d, --directory <string>  Set download location
  -e, --extension <string>  Change file extension from md
  -h, --help                display this help and exit
  --version                 output version information and exit
```

## About
This is a downloader focused on downloading novels in the Markdown format. This makes it simple to read in apps like [Obsidian](https://obsidian.md). This allows for the original formatting of the text to be preserved because it is essentially just a renamed `html` file. The default file extension is `md` but can be changed to `html` if you want to use a browser to display the chapters (although not recommended).

## Examples
Search for novel
```
rr-dl
```

Search for novels titled "test"
```
rr-dl test
```

Search for novels titled "test" and select all chapters for download
```
rr-dl -a test
```

Search for novels titled "test" and prefix chapter titles with index + 10
```
rr-dl -I 10 test
```
