#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_qr_scan.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_qr_scan'
  s.version          = '0.2.0'
  s.summary          = 'A lightweight Flutter QR-code scan plugin for Android and iOS.'
  s.description      = <<-DESC
  A lightweight Flutter QR-code scan plugin for Android and iOS.
                       DESC
  s.homepage         = 'http://example.com'
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
