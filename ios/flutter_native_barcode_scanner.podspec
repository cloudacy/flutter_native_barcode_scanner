#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_native_barcode_scanner.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_native_barcode_scanner'
  s.version          = '0.4.3'
  s.summary          = 'A barcode scanner for Flutter, using platform native APIs.'
  s.description      = <<-DESC
A barcode scanner for Flutter, using platform native APIs.
                       DESC
  s.homepage         = 'https://cloudacy.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'cloudacy OG' => 'office@cloudacy.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '10.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
