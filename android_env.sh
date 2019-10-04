#!/bin/bash

MIN_API=16
CROSS_PREFIX=i686-linux-android

export NDK_PATH=/home/wzjing/android-ndk-r19c
export TOOLCHAIN=$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64
export SYSROOT=$TOOLCHAIN/sysroot
export PREFIX=/home/wzjing/ffmpeg-android/build/x86
export PATH=$PATH:$TOOLCHAIN/bin

export CC=${CROSS_PREFIX}${MIN_API}-clang
export CXX=${CROSS_PREFIX}${MIN_API}-clang++
export AR=$CROSS_PREFIX-ar
export AS=${CROSS_PREFIX}${MIN_API}-clang
export LD=$CROSS_PREFIX-ld
export STRIP=$CROSS_PREFIX-strip
export PATH=$PATH:$TOOLCHAIN/bin

cat <<EOF
  Toolchain info:

  CC:    $CC (`$CC --version | grep -E "\bclang\sversion\s[0-9.]+" -o`)
  CXX:   $CXX (`$CXX --version | grep -E "\bclang++\sversion\s[0-9.]+" -o`)
  AS     $AS  (`$AS --version | grep -E "\bclang\sversion\s[0-9.]+" -o`)
  AR:    $AR (`$AR --version | head -1`)
  LD:    $LD (`$LD --version | head -1`)
  STRIP: $STRIP (`$STRIP --version | head -1`)

EOF

