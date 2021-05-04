#!/bin/bash -e

realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

#cpanm XML::Parser

if git clone https://github.com/GStreamer/cerbero.git
then
  pushd cerbero
  patch -p1 < ../cerbero.patch
  popd
fi

BREW_DEPS="expat perl autoconf libtool gtk-doc jpeg python3"
brew install ${BREW_DEPS} || true
brew unlink ${BREW_DEPS}
brew link --overwrite ${BREW_DEPS}

pushd cerbero

# Copy all spice recipes in automatically or git clone a repo with them.
rsync -a ../recipes/ ./recipes/

# Workaround for missing lib-pthread.la dependency.
for arch in x86_64 arm64
do
    mkdir -p build/dist/ios_universal/${arch}/lib/
    ln -sf libz.la build/dist/ios_universal/${arch}/lib/lib-pthread.la
done

# Use newer clang, python3 from /use/local/bin, and buildtools from cerbero directory
export PATH=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin:/usr/local/bin:./build/build-tools/bin/${PATH}

# Needed for Mac Catalyst builds
# TODO: If freetype build fails, export SDKROOT and run make again. Then, rerun build and skip freetype recipe.
export SDKROOT="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

./cerbero-uninstalled -c config/cross-ios-universal.cbc bootstrap

# TODO: Fix building of libjpeg-turbo

./cerbero-uninstalled -c config/cross-ios-universal.cbc build spiceglue

popd

ln -s $(realpath cerbero/build/dist/ios_universal/) ../bVNC.xcodeproj/ || true

cp cerbero/build/sources/ios_universal/x86_64/spiceglue-2.2/src/*.h cerbero/build/dist/ios_universal/include/

# Make a super duper static lib out of all the other libs
pushd ../bVNC.xcodeproj/ios_universal/lib
/Library/Developer/CommandLineTools/usr/bin/libtool -static -o spicelib.a lib*.a
popd