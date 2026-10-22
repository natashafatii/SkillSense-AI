// Called by tooling/generate_branding.dart after icon generation.
// Manifest names are configured in pubspec.yaml's app_branding section.
// No HTML or native XML files are read or modified by this tool.
import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

void main() {
  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
  final branding = pubspec['app_branding'] as YamlMap;
  final name = branding['name'] as String;
  final shortName = branding['short_name'] as String;
  if (name.trim().isEmpty || shortName.trim().isEmpty) {
    throw StateError('app_branding names must not be empty.');
  }
  final file = File('web/manifest.json');
  final manifest = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  manifest['name'] = name;
  manifest['short_name'] = shortName;
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('    ').convert(manifest)}\n',
  );
  stdout.writeln('Generated web manifest names from pubspec.yaml: $name');
}
