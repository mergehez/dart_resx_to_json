RESX to JSON converter.  [![Pub Package](https://img.shields.io/pub/v/resx_to_json.svg)](https://pub.dev/packages/resx_to_json)

While migration from Xamarin Forms to Flutter, you'd probably want to convert your localization files to json. This package is the perfect tool for it.

> Note: For different extensions (like .arb) change the `extension` option in your `pubspec.yaml` file. See [Usage](#usage)

## Installation
You don't have to add any dependency to your project. Just activate `resx_to_json` globally:

```shell
pub global activate resx_to_json
```

## Usage

1. Add a new section `resx_to_json` to your `pubspec.yaml` file.

An example with all options: 
```yaml
resx_to_json:
  # The directory containing resx files. The path can be relative or absolute.
  source: C:\Users\Mazlum\source\repos\_MergeSoft\AsoGotin\AsoGotin\Properties
  
  # The directory where the generated json files will be saved in. The path can be relative or absolute.
  destination: assets/localization/

  # Indicates whether the keys in json files should be sorted alphabetically. (Optional, default: true)
  sort: true

  # The extension for the generated json files. For example `arb`. (Optional, default: 'json')
  extension: json

  # Regex patterns for renaming resx files. (Optional)
  # Notice that the search is case-sensitive
  # <regex_pattern> => <replacement> 
  replacements: 
    - Resources\.resx => en.json
    - Resources\.([a-z]+)\.resx => $1.json # $1 is the 1. match group. e.g. Resources.de.resx is renamed to de.json
```


2. Run this command inside your flutter project root.
```shell
pub global run resx_to_json
```