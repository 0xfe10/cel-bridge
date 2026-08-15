version = File.read(File.expand_path('../VERSION', __dir__)).strip
archive_name = "cel-bridge-ios-xcframework-v#{version}.zip"
release_base = "https://github.com/0xfe10/cel-bridge/releases/download/v#{version}"

Pod::Spec.new do |s|
  s.name = 'cel_bridge'
  s.version = version
  s.summary = 'Cross-platform CEL runtime for Dart and Flutter.'
  s.description = 'Flutter iOS fallback bridge for the cel-bridge C ABI.'
  s.homepage = 'https://github.com/0xfe10/cel-bridge'
  s.license = { :file => '../LICENSE' }
  s.author = { '0xfe10' => '0xfe10@proton.me' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*.{h,m}'
  s.public_header_files = 'Classes/CelBridgePlugin.h'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.frameworks = 'Foundation'
  s.static_framework = true

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' =>
      '$(inherited) -force_load "$(PODS_CONFIGURATION_BUILD_DIR)/cel_bridge/libcel_bridge.a"',
  }

  s.script_phase = {
    :name => 'Prepare cel-bridge iOS static runtime',
    :execution_position => :before_compile,
    :script => <<-SCRIPT
set -euo pipefail
build_root="${PODS_CONFIGURATION_BUILD_DIR:-${TARGET_BUILD_DIR:-}}"
test -n "$build_root"
root="$build_root/cel_bridge"
mkdir -p "$root"
framework="$root/libcel_bridge.xcframework"
local="${CEL_BRIDGE_IOS_XCFRAMEWORK_PATH:-}"
if [ -n "$local" ]; then
  test -d "$local"
  /usr/bin/ditto "$local" "$framework"
else
  archive="$root/#{archive_name}"
  if [ ! -d "$framework" ]; then
    url="${CEL_BRIDGE_IOS_XCFRAMEWORK_URL:-#{release_base}/#{archive_name}}"
    /usr/bin/curl --fail --location --retry 3 "$url" -o "$archive"
    checksum_url="${CEL_BRIDGE_IOS_XCFRAMEWORK_CHECKSUM_URL:-#{release_base}/checksums.txt}"
    expected="${CEL_BRIDGE_IOS_XCFRAMEWORK_SHA256:-}"
    if [ -z "$expected" ]; then
      expected="$(/usr/bin/curl --fail --location --retry 3 "$checksum_url" | /usr/bin/awk -v name="#{archive_name}" '$2 == name { print $1 }')"
    fi
    test -n "$expected"
    printf '%s  %s\\n' "$expected" "$archive" | /usr/bin/shasum -a 256 -c -
    /usr/bin/ditto -x -k "$archive" "$root"
  fi
fi
if [ "${PLATFORM_NAME:-}" = 'iphonesimulator' ]; then
  library="$(/usr/bin/find "$framework" -path '*/ios-arm64_x86_64-simulator/libcel_bridge.a' -print -quit)"
else
  library="$(/usr/bin/find "$framework" -path '*/ios-arm64/libcel_bridge.a' -print -quit)"
fi
test -n "$library"
/bin/cp "$library" "$root/libcel_bridge.a"
SCRIPT
  }
end
