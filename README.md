# rr-dl

_Royal Road Novel Downloader_

## Usage

```
Usage: rr-dl [options] [ARGS]

Description: A cli program for downloading novels from royalroad.com

Options:
  -a, --all                 Select all chapters
  -t, --title               Add chapter title to start of file
  -I, --indexing <int>      Index chapters starting from value
  -i, --index               Prefix title with chapter index
  -d, --directory <string>  Set download location
  -h, --help                display this help and exit
  --version                 output version information and exit
```

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
