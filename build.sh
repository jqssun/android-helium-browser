#!/bin/bash

source common.sh
set_keys
export VERSION=$(cat VERSION)
export CHROMIUM_SOURCE=https://github.com/chromium/chromium.git
# https://chromium.googlesource.com/chromium/src.git
export DEBIAN_FRONTEND=noninteractive
sudo apt update
sudo apt install -y sudo lsb-release file nano git curl python3

# https://github.com/uazo/cromite/blob/master/tools/images/chr-source/prepare-build.sh
git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH="$PWD/depot_tools:$PATH"
mkdir -p chromium/src/out/Default; cd chromium
gclient root; cd src
git init
git remote add origin $CHROMIUM_SOURCE
git fetch --depth 2 $CHROMIUM_SOURCE +refs/tags/$VERSION:chromium_$VERSION
git checkout $VERSION
export COMMIT=$(git show-ref -s $VERSION | head -n1)

cat > ../.gclient <<EOF
solutions = [
  {
    "name": "src",
    "url": "$CHROMIUM_SOURCE@$COMMIT",
    "deps_file": "DEPS",
    "managed": False,
    "custom_vars": {
      "checkout_android_prebuilts_build_tools": True,
      "checkout_telemetry_dependencies": False,
      "codesearch": "Debug",
    },
  },
]
target_os = ["android"]
EOF
git submodule foreach git config -f ./.git/config submodule.$name.ignore all
git config --add remote.origin.fetch '+refs/tags/*:refs/tags/*'
gclient sync -D --no-history --nohooks
gclient runhooks
rm -rf third_party/angle/third_party/VK-GL-CTS/
./build/install-build-deps.sh --no-prompt

# add helium
sudo apt install -y python3-pillow
export _main_repo=$(realpath ../../helium)
export _src_dir=$(realpath .)
git clone --depth 1 https://github.com/imputnet/helium.git $_main_repo
python3 "${_main_repo}/utils/name_substitution.py" --sub -t "${_src_dir}"
python3 "${_main_repo}/utils/helium_version.py" --tree "${_main_repo}" --chromium-tree "${_src_dir}"
python3 "${_main_repo}/utils/generate_resources.py" "${_main_repo}/resources/generate_resources.txt" "${_main_repo}/resources"
python3 "${_main_repo}/utils/replace_resources.py" "${_main_repo}/resources/helium_resources.txt" "${_main_repo}/resources" "${_src_dir}"

cat > out/Default/args.gn <<EOF
chrome_public_manifest_package = "io.github.jqssun.helium"
is_desktop_android = true
target_os = "android"
target_cpu = "arm64"
ffmpeg_branding="Chrome"
google_api_key="x"
google_default_client_id="x"
google_default_client_secret="x"

blink_symbol_level=1
build_contextual_search=false
build_with_tflite_lib=true
chrome_pgo_phase=0
dcheck_always_on=false
disable_fieldtrial_testing_config=true
enable_hangout_services_extension=false
enable_iterator_debugging=false
enable_mdns=false
enable_remoting=false
enable_reporting=false
enable_vr=false
exclude_unwind_tables=false
icu_use_data_file=true
is_component_build=false
is_official_build=true
is_debug=false
rtc_build_examples=false
symbol_level=1
use_debug_fission=true
use_errorprone_java_compiler=false
use_official_google_api_keys=false
use_rtti=false
enable_arcore=false
enable_openxr=false
enable_cardboard=false
proprietary_codecs=true
enable_av1_decoder=true
enable_dav1d_decoder=true
include_both_v8_snapshots = false
include_both_v8_snapshots_android_secondary_abi = false
generate_linker_map = true
EOF
gn gen out/Default # gn args out/Default
autoninja -C out/Default chrome_public_apk

export PATH=$PWD/third_party/jdk/current/bin/:$PATH
export ANDROID_HOME=$PWD/third_party/android_sdk/public
mkdir -p out/Default/apks/release
sign_apk $(find out/Default/apks -name 'Chrome*.apk') out/Default/apks/release/ChromePublic.apk