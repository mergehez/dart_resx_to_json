// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart' as yaml;
import 'package:xml/xml.dart' as xml;

void main(List<String> arguments) async {
  try {
    convert();
  } on FormatException catch (e) {
    printExit(e.message);
  }
}

class Config {
  static const String keySource = "source";
  static const String keyDestination = "destination";
  static const String keySort = "sort";
  static const String keyReplacements = "replacements";
  static const String keyExtension = "extension";
  static const String keyJsonKeysPath = "json_keys_path";

  static const String defaultJsonKeysPath = "lib/helper/json_keys.dart";

  final String source, destination, ext, jsonKeysPath;
  final bool sort;
  final Map<String, String> replacements;

  Config(this.source, this.destination, this.sort, this.ext, this.replacements, this.jsonKeysPath);
}

void convert() {
  final config = Utils.getConfig();

  final targetDir = Directory(config.destination);
  if (!targetDir.existsSync()) {
    try {
      targetDir.createSync(recursive: true);
    } on Exception catch (e) {
      printExit(" The directory `${config.destination}` was not found and could be created! Error: ${e.toString()}");
    }
  }

  final Map<String, Map<String, String>> fileMap = {};
  if (config.source.endsWith(".resx")) {
    var fileName = ("/" + config.source).replaceAll("\\", "/").split("/").last;
    fileMap[fileName] = Utils.readXML(config.source);
  } else if (!config.source.split(RegExp(r'\\|/')).last.contains(".")) {
    final dir = Directory(config.source);
    final path = dir.absolute.path;
    if (!dir.existsSync()) {
      printExit("The given directory `$path` does not exist!");
    }
    final files = dir.listSync().where((e) => e.path.endsWith(".resx"));
    if (files.isEmpty) {
      printExit("No RESX file found in `$path`");
    }
    for (var file in files) {
      var fileName = ("/" + file.path).replaceAll("\\", "/").split("/").last;
      fileMap[fileName] = Utils.readXML(file.path);
    }
    print("Following RESX files were found in `$path`:\n  - ${fileMap.keys.join("\n  - ")}");
  } else {
    printExit("`${config.source}` is not a valid parameter for `${Config.keySource}`. It must be a folder or the path to a resx file!");
  }

  List<String> allKeys = [];
  for (var mapEntry in fileMap.entries) {
    var keys = mapEntry.value.keys;
    for (var key in keys) {
      if (!allKeys.contains(key)) {
        allKeys.add(key);
      }
    }
  }

  if (config.sort) {
    allKeys.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  for (var mapEntry in fileMap.entries) {
    var m = mapEntry.value;
    for (var key in allKeys) {
      if (!m.containsKey(key)) {
        m[key] = "";
      }
    }
  }
  for (var key in fileMap.keys) {
    final m = fileMap[key]!;
    if (config.sort) {
      final Map<String, String> sortedMap = {};
      for (var key in allKeys) {
        sortedMap[key] = m.containsKey(key) ? m[key]! : "";
      }
      fileMap[key] = sortedMap;
    } else {
      for (var key in allKeys) {
        if (!m.containsKey(key)) {
          m[key] = "";
        }
      }
    }
  }

  try {
    final file = File(config.jsonKeysPath);
    if (file.existsSync() && !file.readAsLinesSync().first.startsWith("// resx_to_json: auto-generated")) {
      printExit(
          '`${config.jsonKeysPath}` was either created by you manually or modified after being created by resx_to_json. Please delete the file and try again!');
    }
    file.createSync(recursive: true);

    var jsonKeysFileContent = Utils.createJsonKeysFileContent(config, allKeys);
    file.writeAsStringSync(jsonKeysFileContent);
  } on FileSystemException catch (e) {
    printExit("The class for json keys couldn't be created. Error: `$e`");
  }

  final List<String> finalFileNames = [];
  for (var mapEntry in fileMap.entries) {
    String name = mapEntry.key;
    final m = mapEntry.value;

    String json;
    try {
      var encoder = const JsonEncoder.withIndent("    ");
      json = encoder.convert(m);
    } on JsonUnsupportedObjectError catch (e) {
      printExit("The operation could not be proccessed. Cause: `${e.cause}`");
    }

    try {
      for (var e in config.replacements.entries) {
        if (!e.value.contains("\$")) {
          name = name.replaceAll(RegExp(e.key), e.value);
        } else {
          name = name.replaceAllMapped(RegExp(e.key), (match) {
            var replacedString = e.value;
            for (var i = 0; i <= match.groupCount; i++) {
              replacedString = replacedString.replaceAll('\$$i', match.group(i)!);
            }
            return replacedString;
          });
        }
      }
      name = name.replaceAll(".resx", ".${config.ext}");
      finalFileNames.add(name);
      final file = File(targetDir.path + "/" + name);
      file.createSync();
      file.writeAsStringSync(json);
    } on FileSystemException catch (e) {
      printExit("The json file `$name` couldn't be created. Error: `$e`");
    }
  }

  print("\nFollowing files have been created in `${targetDir.absolute.path}`:\n  - ${finalFileNames.join("\n  - ")}");
}

Never printExit(String msg) {
  print(msg);
  return exit(1);
}

class Utils {
  static Config getConfig({String configFile = "pubspec.yaml"}) {
    if (!File(configFile).existsSync()) {
      printExit('The config file `$configFile` was not found.');
    }

    final Map yamlMap = yaml.loadYaml(File(configFile).readAsStringSync());

    if (yamlMap['resx_to_json'] is! Map) {
      throw Exception('Your `$configFile` file does not contain a `resx_to_json` section.');
    }

    final config = jsonDecode(jsonEncode(yamlMap['resx_to_json']));

    if (!config.containsKey(Config.keySource)) {
      printExit('Your `resx_to_json` section does not contain `${Config.keySource}`.');
    }

    if (!config.containsKey(Config.keyDestination)) {
      printExit('Your `resx_to_json` section does not contain `${Config.keyDestination}`.');
    }

    if (!config.containsKey(Config.keyJsonKeysPath) &&
        File(Config.defaultJsonKeysPath).existsSync() &&
        !File(Config.defaultJsonKeysPath).readAsLinesSync().first.startsWith("// resx_to_json: auto-generated")) {
      printExit(
          'Your `resx_to_json` section does not contain `${Config.keyJsonKeysPath}` and the default path `${Config.defaultJsonKeysPath}` already exists. Please either define a custom path or rename/delete the existing file.');
    }
    if (config.containsKey(Config.keyJsonKeysPath) && File(config[Config.keyJsonKeysPath].toString()).existsSync()) {
      printExit(
          'The file path defined in `${Config.keyJsonKeysPath}` in the `resx_to_json` section already exists! Please either define another path or rename/delete the existing file.');
    }
    var locKeysPath = config[Config.keyJsonKeysPath]?.toString() ?? Config.defaultJsonKeysPath;

    // File(locKeysPath).createSync(recursive: true);
    // printExit('success: file doesn\'t exist: ${locKeysPath}');

    bool sort = true;
    if (config.containsKey(Config.keySort)) {
      final sortStr = config[Config.keySort].toString();
      if (sortStr != "true" && sortStr != "false") {
        printExit('The value of `${Config.keySort}` in your `resx_to_json` must be either `true` or `false`. `$sortStr` is not valid!');
      }
      sort = sortStr == "true";
    }

    Map<String, String> replacements = {};
    if (config[Config.keyReplacements] is List) {
      for (String pairStr in config[Config.keyReplacements]) {
        final pair = pairStr.split(" => ");
        if (pair.length == 1) {
          printExit(
              "Each item in `${Config.keyDestination}` in your `resx_to_json` must contain ` => ` so that search and replacement can be parsed.");
        }
        replacements[pair[0].trim()] = pair[1].trim();
      }
    }

    final ext = config[Config.keyExtension] ?? "json";

    return Config(config[Config.keySource], config[Config.keyDestination], sort, ext, replacements, locKeysPath);
  }

  static Map<String, String> readXML(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      printExit('The file `${file.absolute.path}` was not found.');
    }

    try {
      final strContent = file.readAsStringSync();
      final doc = xml.XmlDocument.parse(strContent);
      final elements = doc.childElements.toList().first.childElements.where((element) {
        return element.name.local == "data";
      });

      final Map<String, String> map = {};
      for (var e in elements) {
        var name = e.getAttribute("name");
        var value = e.getElement("value")?.innerText;
        if (name == null || value == null) {
          printExit('The document is malformed!');
        }
        map[name] = value;
      }
      return map;
    } catch (_, __) {
      printExit("The file `$filePath` is not a valid .resx document.");
    }
  }

  static String createJsonKeysFileContent(Config config, List<String> allKeys) {
    var className = Utils.convertSnakeCaseToPascalCase(File(config.jsonKeysPath).uri.pathSegments.last);
    final preservedDartKeywords = [
      'abstract',
      'as',
      'assert',
      'async',
      'await',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'covariant',
      'default',
      'deferred',
      'do',
      'dynamic',
      'else',
      'enum',
      'export',
      'extends',
      'extension',
      'external',
      'factory',
      'false',
      'final',
      'finally',
      'for',
      'function',
      'get',
      'hide',
      'if',
      'implements',
      'import',
      'in',
      'interface',
      'is',
      'late',
      'library',
      'mixin',
      'new',
      'null',
      'on',
      'operator',
      'part',
      'required',
      'rethrow',
      'return',
      'set',
      'show',
      'static',
      'super',
      'switch',
      'sync',
      'this',
      'throw',
      'true',
      'try',
      'typedef',
      'var',
      'void',
      'while',
      'with',
      'yield'
    ];

    var strBuilderKeys = StringBuffer();
    strBuilderKeys.writeln('// resx_to_json: auto-generated (Do not modify this line or the package won\'t update this file!)');
    strBuilderKeys.writeln('// ignore_for_file: constant_identifier_names, unused_field');
    strBuilderKeys.writeln('');
    strBuilderKeys.writeln('class $className {');
    strBuilderKeys.writeln('  const $className._();');
    strBuilderKeys.writeln('');

    if (config.sort) {
      allKeys.sort();
    }

    for (var key in allKeys) {
      var propName = key.replaceAll(RegExp(r'[^\w_$]'), '_');
      if (propName.startsWith(RegExp(r'[0-9]')) || preservedDartKeywords.contains(propName)) {
        propName = "_" + propName;
      }
      if (!key.contains("'")) {
        key = "'$key'";
      } else if (!key.contains('"')) {
        key = '"$key"';
      } else {
        printExit('the key `$key` cannot have both single and double quotes in it!');
      }

      strBuilderKeys.writeln('  static const String $propName = "$key";');
    }

    strBuilderKeys.write("}");

    return strBuilderKeys.toString();
  }

  static final RegExp _caseConvertUpperAlphaRegex = RegExp(r'[A-Z]');
  static final caseConvertSymbolSet = {' ', '.', '/', '_', '\\', '-'};
  static String convertSnakeCaseToPascalCase(String text) {
    StringBuffer sb = StringBuffer();
    bool isAllCaps = text.toUpperCase() == text;
    bool nextUppercase = true;

    for (int i = 0; i < text.length; i++) {
      String char = text[i];
      String? nextChar = i + 1 == text.length ? null : text[i + 1];

      if (caseConvertSymbolSet.contains(char)) {
        continue;
      }

      sb.write(nextUppercase ? char.toUpperCase() : char);

      bool isEndOfWord =
          nextChar == null || (_caseConvertUpperAlphaRegex.hasMatch(nextChar) && !isAllCaps) || caseConvertSymbolSet.contains(nextChar);

      nextUppercase = isEndOfWord;
    }

    return sb.toString();
  }
}
