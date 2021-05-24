#!/usr/bin/env python3

import re
import subprocess

pubspecRawContent = ''
podspecRawContent = ''
version = ''

# read the current version number
with open('pubspec.yaml', 'r') as pubspec:
    pubspecRawContent = pubspec.read()
    match = re.search(r'version: (\d+\.\d+\.\d+)', pubspecRawContent)
    version = match.group(1)

# read the current podspec content
with open('ios/flutter_native_barcode_scanner.podspec', 'r') as podspec:
    podspecRawContent = podspec.read()

# Ask for a new version number
newVersion = input('New version number: [%s] ' % (version))

# validate the input
if newVersion:
    match = re.search(r'^\d+\.\d+\.\d+$', newVersion)
    if not match:
        print('ERROR: Invalid version number given: %s' % (newVersion))
        exit(1)
# default to current version
else:
    print('ERROR: A new version version number has to be given: %s' % (newVersion))
    exit(1)

# place the new version combination to the pubspecRawContent string
pubspecRawContent = re.sub(r'version: (\d+\.\d+\.\d+)', 'version: %s' %
                           (newVersion), pubspecRawContent)

podspecRawContent = re.sub(r'\'(\d+\.\d+\.\d+)\'', '\'%s\'' %
                           (newVersion), podspecRawContent)

# write the updated pubspec content to the pubspec.yaml file
with open('pubspec.yaml', 'w') as pubspec:
    pubspec.write(pubspecRawContent)

# write the updated podspec content to the iOS podspec file
with open('ios/flutter_native_barcode_scanner.podspec', 'w') as podspec:
    podspec.write(podspecRawContent)

print('Updated pubspec.yaml and ios/flutter_native_barcode_scanner.podspec! Running "flutter pub get" to update other files.')

# update lockfiles
subprocess.run(['flutter', 'pub', 'get'])

# update example iOS Podfile.lock
subprocess.run(['pod', 'install'], cwd = 'example/ios')

print('Staging pubspec.yaml, pubspec.lock, ios/flutter_native_barcode_scanner.podspec, example/pubspec.lock, example/ios/Podfile.lock and CHANGELOG.md ...')

subprocess.run(['git', 'add', 'pubspec.yaml'])
subprocess.run(['git', 'add', 'pubspec.lock'])
subprocess.run(['git', 'add', 'ios/flutter_native_barcode_scanner.podspec'])
subprocess.run(['git', 'add', 'example/pubspec.lock'])
subprocess.run(['git', 'add', 'example/ios/Podfile.lock'])
subprocess.run(['git', 'add', 'CHANGELOG.md'])

print('Creating version commit and tag ...')

subprocess.run(['git', 'commit', '-m', 'v%s' % (newVersion)])
subprocess.run(['git', 'tag', '%s' % (newVersion)])

print('Pushing version commit and tag ...')

subprocess.run(['git', 'push'])
subprocess.run(['git', 'push', '--tags'])
