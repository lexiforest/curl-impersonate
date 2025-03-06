# Notes for building with Android NDK

## Useful links

- https://android.googlesource.com/platform/ndk/+/master/docs/BuildSystemMaintainers.md
- https://developer.android.com/ndk/guides/other_build_systems
- https://github.com/android/ndk/issues/1690
- [It's better to use NDK r21e for termux](https://github.com/termux/termux-packages/issues/8273)
- https://curl.se/docs/install.html
- https://boringssl.googlesource.com/boringssl/+/HEAD/BUILDING.md
- https://developer.android.com/ndk/guides/abis#arm64-v8a

## Build

Use

- $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android21-clang
- $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android21-clang++
- $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-*

Autoconf Example, for zlib

```sh
# Check out the source.
git clone https://github.com/glennrp/libpng -b v1.6.37
cd libpng

# Only choose one of these, depending on your build machine...
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/darwin-x86_64
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64

# Only choose one of these, depending on your device...
export TARGET=aarch64-linux-android
export TARGET=armv7a-linux-androideabi
export TARGET=i686-linux-android
export TARGET=x86_64-linux-android

# Set this to your minSdkVersion.
export API=21

# Configure and build.
export AR=$TOOLCHAIN/bin/llvm-ar
export CC=$TOOLCHAIN/bin/$TARGET$API-clang
export AS=$CC
export CXX=$TOOLCHAIN/bin/$TARGET$API-clang++
export LD=$TOOLCHAIN/bin/ld
export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
export STRIP=$TOOLCHAIN/bin/llvm-strip

./configure --host $TARGET
make
```

Non-autoconf Example, for zstd

```sh
# Check out the source.
git clone https://gitlab.com/bzip/bzip2.git
cd bzip2

# Only choose one of these, depending on your build machine...
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/darwin-x86_64
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64

# Only choose one of these, depending on your device...
export TARGET=aarch64-linux-android
export TARGET=armv7a-linux-androideabi
export TARGET=i686-linux-android
export TARGET=x86_64-linux-android

# Set this to your minSdkVersion.
export API=21

# Build.
make \
    CC=$TOOLCHAIN/bin/$TARGET$API-clang \
    AR=$TOOLCHAIN/bin/llvm-ar \
    RANLIB=$TOOLCHAIN/bin/llvm-ranlib \
    bzip2
```
