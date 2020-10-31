#!/usr/bin/env python3

import re
import subprocess

pubspecRawContent = ''
version = ''

# read the current version number
with open('pubspec.yaml', 'r') as pubspec:
    pubspecRawContent = pubspec.read()
    match = re.search(r'version: (\d+\.\d+\.\d+)', pubspecRawContent)
    version = match.group(1)

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
pubspecRawContent = re.sub(r'version: (\d+\.\d+\.\d+)', 'version: %s+%s' %
                           (newVersion), pubspecRawContent)

# write the updated pubspec content to the pubspec.yaml file
with open('pubspec.yaml', 'w') as pubspec:
    pubspec.write(pubspecRawContent)

print('Updated pubspec.yaml! Running "flutter pub get" to update other files.')

subprocess.run(['flutter', 'pub', 'get'])

print('Staging pubspec.yaml ...')

subprocess.run(['git', 'add', 'pubspec.yaml'])

print('Creating version commit and tag ...')

subprocess.run(['git', 'commit', '-m', 'v%s' % (newVersion)])
subprocess.run(['git', 'tag', '%s' % (newVersion)])

print('Pushing version commit and tag ...')

subprocess.run(['git', 'push'])
subprocess.run(['git', 'push', '--tags'])
