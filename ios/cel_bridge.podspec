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
      '$(inherited) -L"$(PODS_CONFIGURATION_BUILD_DIR)/cel_bridge" -lcel_bridge',
  }

  s.script_phase = {
    :name => 'Prepare cel-bridge iOS static runtime',
    :execution_position => :before_compile,
    :script => <<-SCRIPT
set -euo pipefail
download() {
  local url="$1"
  shift
  case "$url" in
    https://*)
      /usr/bin/curl --fail --location --retry 3 \
        --proto '=https' --proto-redir '=https' "$url" "$@"
      ;;
    http://127.0.0.1/*|http://127.0.0.1:*|http://localhost/*|http://localhost:*)
      /usr/bin/curl --fail --location --retry 3 \
        --proto '=http' --proto-redir '=http' "$url" "$@"
      ;;
    *)
      echo "cel_bridge: URL must use HTTPS (or localhost HTTP for tests): $url" >&2
      return 1
      ;;
  esac
}
build_root="${PODS_CONFIGURATION_BUILD_DIR:-${TARGET_BUILD_DIR:-}}"
test -n "$build_root"
root="$build_root/cel_bridge"
mkdir -p "$root"
framework="$root/libcel_bridge.xcframework"
version="#{version}"
marker="$root/.cel_bridge-$version.sha256"
tmp_root="$root/.cel_bridge-download.$$"
cleanup() {
  /bin/rm -rf "$tmp_root"
}
trap cleanup EXIT
if [ "${PLATFORM_NAME:-}" = 'iphonesimulator' ]; then
  library_subpath='ios-arm64_x86_64-simulator'
else
  library_subpath='ios-arm64'
fi
local="${CEL_BRIDGE_IOS_XCFRAMEWORK_PATH:-}"
if [ -n "$local" ]; then
  test -d "$local"
  /bin/rm -rf "$framework"
  /usr/bin/ditto "$local" "$framework"
else
  url="${CEL_BRIDGE_IOS_XCFRAMEWORK_URL:-#{release_base}/#{archive_name}}"
  checksum_url="${CEL_BRIDGE_IOS_XCFRAMEWORK_CHECKSUM_URL:-#{release_base}/checksums.txt}"
  expected="${CEL_BRIDGE_IOS_XCFRAMEWORK_SHA256:-}"
  if [ -z "$expected" ]; then
    expected="$(download "$checksum_url" | /usr/bin/awk -v name="#{archive_name}" '$2 == name { print $1 }')"
  fi
  test -n "$expected"
  cached=false
  if [ -d "$framework" ] && [ -f "$marker" ] &&
      [ "$(/bin/cat "$marker")" = "$expected" ] &&
      [ -n "$(/usr/bin/find "$framework" -path "*/$library_subpath/libcel_bridge.a" -print -quit)" ]; then
    cached=true
  fi
  if [ "$cached" != true ]; then
    /bin/rm -rf "$tmp_root"
    mkdir -p "$tmp_root"
    archive="$tmp_root/#{archive_name}"
    download "$url" -o "$archive"
    printf '%s  %s\\n' "$expected" "$archive" | /usr/bin/shasum -a 256 -c -
    /usr/bin/ditto -x -k "$archive" "$tmp_root"
    temp_framework="$tmp_root/libcel_bridge.xcframework"
    test -d "$temp_framework"
    test -n "$(/usr/bin/find "$temp_framework" -path "*/$library_subpath/libcel_bridge.a" -print -quit)"
    /bin/rm -rf "$framework"
    /bin/mv "$temp_framework" "$framework"
    printf '%s\\n' "$expected" > "$marker"
  fi
fi
library="$(/usr/bin/find "$framework" -path "*/$library_subpath/libcel_bridge.a" -print -quit)"
test -n "$library"
/bin/cp "$library" "$root/libcel_bridge.a"
SCRIPT
  }
end
