#/bin/bash

# info
VERSION=0.1
AUTHOR=wzjing
DESCRIPTION="this script can build ffmpeg lib for android"

# command line argment

ARGS=`getopt -o vh --long version,help,arch:,api:,enable-libx264,enable-libfdk-aac,all-yes -n 'testh.sh' -- "$@"`

if [[ $? != 0 ]]; then
    echo "invalid command, use -h/--help to see how to use."
    exit 1;
fi

# Congifure deault values
MIN_API=16
MAX_TH=$(cat /proc/cpuinfo | grep "processor" | wc -l)
NDK_ROOT=/Users/wzjing/Library/Android/sdk/ndk/19.2.5345600
TOOLCHAIN=$NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64
CPU_ARCH=""
ENABLE_X264=false
ENABLE_FDK_AAC=false
FF_FLAGS=""
EXTRA_CFLAGS="-fPIC -fPIE"
EXTRA_LDFLAGS=""
ALL_YES=false
FFMPEG_SOURCE=`pwd`/ffmpeg
X264_SOURCE=`pwd`/x264
FDK_AAC_SOURCE=`pwd`/fdk-aac
DEBUG=true

debug() {
    if $DEBUG
    then
        echo -e $*
    fi
}

log() {
    echo -e $*
}

warn() {
    echo -e "\033[33m$*\033[0m"
}

error() {
    echo -e "\033[31m$*\033[0m"
}

die() {
    error $*
    exit 1
}

make_choice() {
    warn "$1 Y/N[Y]"
    if $ALL_YES
    then
        choice=Y
    else
        read choice
    fi
    if [[ $choice =~ ^[yY] || -z $choice ]]
    then
        return 0
    elif [[ $choice =~ ^[nN] ]]
    then
        return 1
    else
        choice=""
        warn -n "invalid choice '$choice' use Y or N: "
        make_choice
    fi
}

eval set -- "${ARGS}"

while true
do
    case "$1" in
        -v|--version)
            cat <<EOF
Version:      $VERSION
Author:       $AUTHOR
Release date: 2019/5/1
EOF
            exit 0
        ;;
        -h|--help)
        cat <<EOF
This is script to compile ffmpeg for android

Usage: $0 --arch <arch> --api <min-version>

Options:
    --arch <arch>           cpu arch [armv7a, arm64, x86, x86_64]
    --api <min-version>     min api support, the lowest version is 16
                                if use 64-bit arch like arm64 and x86_64
                                api must greater or equal than 21
    --enable-libx264        enable libx264 for H264 codec
    --enable-libfdk-aac     enable libfdk-aac for aac codec

Example:
    $0 --arch arm64 --api 21 --enable-libx264

EOF
            exit 0
        ;;
        --arch)
            debug arch
            ARCH=$2
            case "$2" in
                armv7a)
                    CPU_ARCH="arm"
                    EXTRA_CFLAGS+=" -march=armv7-a -Wl,--fix-cortex-a8"
                    CROSS_PREFIX="arm-linux-androideabi"
                ;;
                arm64)
                    CPU_ARCH="aarch64"
                    CROSS_PREFIX="aarch64-linux-android"
                    EXTRA_CFLAGS+=" -march=armv8-a -mfpu=neon"
                ;;
                x86)
                    CPU_ARCH="i686"
                    CROSS_PREFIX="i686-linux-android"
                    FF_FLAGS+=" --x86asmexe=yasm"
                ;;
                x86-64)
                    CPU_ARCH="x86_64"
                    CROSS_PREFIX="x86_64-linux-android"
                    FF_FLAGS+=" --x86asmexe=yasm"
                ;;
                *)
                    die "Invalid arch: $2, supported arch are: armv7a arm64 x86 x86_64"
                ;;
            esac
            arch=$2
            shift 2
        ;;
        --api)
            debug api
            MIN_API=$2
            if [[ $2 -lt 16 ]]; then
                die "min api must >=16"
            fi
            shift 2
        ;;
        --enable-libx264)
            debug x264
            ENABLE_X264=true
            FF_FLAGS+=" --enable-libx264"
            shift 1
        ;;
        --enable-libfdk-aac)
            debug aac
            FF_FLAGS+="$ --enable-libfdk-aac"
            ENABLE_FDK_AAC=true
            shift 1
        ;;
        --all-yes)
            debug all-yes
            ALL_YES=true
            shift 1
        ;;
        --)
            debug --
            shift
            break
        ;;
        *)
            debug *
            echo $1
            die "use -h or --help to see how to use this script"
        ;;
    esac
done

if [[ $ARCH =~ 64$ && $MIN_API -lt 21 ]]
then
    die "using 64-bit arch $ARCH need api >= 21"
fi

BUILD_DIR=`pwd`/build/$ARCH
CONFIGURE_LOG=$BUILD_DIR/configure.log
CONFIGURE_EXEC_LOG=$BUILD_DIR/configure_exec.log

test -e $FFMPEG_SOURCE/configure && FFMPEG_SOURCE_EXIST=true || FFMPEG_SOURCE_EXIST=false
test -e $X264_SOURCE/configure && X264_SOURCE_EXIST=true || X264_SOURCE_EXIST=false
test -e $FDK_AAC_SOURCE/configure && FDK_AAC_SOURCE_EXIST=true || FDK_AAC_SOURCE_EXIST=false

# configure information

lib_info() {
    if $1
    then
        echo -n "enable"
    else
        echo "disable"
        return
    fi
    $2 && echo "(source code: yes)" || echo "(source code: no)"
}

cat <<EOF
Libs:
  ffmpeg      `lib_info true $FFMPEG_SOURCE_EXIST`
  libx264:    `lib_info $ENABLE_X264 $X264_SOURCE_EXIST`
  libfdk-aac: `lib_info $ENABLE_FDK_AAC $FDK_AAC_SOURCE_EXIST`

Build options:
  CPU:          $ARCH
  MIN_API:      $MIN_API
  ARCH:         $CPU_ARCH
  NDK:          $NDK_ROOT
  LOG:          $CONFIGURE_LOG
  BUILD_DIR:    $BUILD_DIR
  TRHEADS:      $MAX_TH

EOF

make_choice "All configure OK?" || exit 0

log "> STEP 1/5 Check ffmpeg source code"

if ! $FFMPEG_SOURCE_EXIST
then
    warn "> Cloning ffmpeg source code"
    git clone https://git.ffmpeg.org/ffmpeg.git $FFMPEG_SOURCE
fi

if ! $X264_SOURCE_EXIST
then
    wran "> Cloning x264 source code"
    git clone https://code.videolan.org/videolan/x264.git $X264_SOURCE
fi

log "Source code is ok"

# Init the basic cross-compile environment
export PATH=$PATH:$TOOLCHAIN/bin
# if [ "$ARCH" == "armv7a" ]
# then
#     export CC=armv7a-linux-androideabi${MIN_API}-clang
#     export CXX=armv7a-linux-androideabi${MIN_API}-clang++
# else
#     export CC=${CROSS_PREFIX}${MIN_API}-clang
#     export CXX=${CROSS_PREFIX}${MIN_API}-clang++
# fi

log "> STEP 3/5 Build extra libraries"

build_x264() {
    if [ ! -d $BUILD_DIR/libx264 ]
    then
        mkdir -p $BUILD_DIR/libx264
    else
        rm -rf $BUILD_DIR/libx264/*
    fi
    cd $X264_SOURCE
    
    ./configure --prefix=$BUILD_DIR/libx264 \
    --host=$CPU_ARCH-linux \
    --enable-static \
    --enable-shared \
    --enable-pic \
    --enable-strip \
    --sysroot=$TOOLCHAIN/sysroot \
    --extra-cflags="$EXTRA_CFLAGS" \
    --disable-asm \
    --disable-cli || die "x264 configure failed"
    #--cross-prefix=$CROSS_PREFIX- \
    
    make_choice "libx264: configure done, start build?" || exit 0
    
    make clean
    make -j $MAX_TH || die "libx264: build error"
    make install
    log "libx264: build finished"

    cd ..
    return 0
}

if $ENABLE_X264
then
    log "start build libx264"
    if test -e $BUILD_DIR/libx264/lib/libx264.a
    then
        make_choice "found exist libx264.a, Use exists?" || build_x264
    else
        build_x264
    fi
    
    export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$BUILD_DIR/libx264/lib/pkgconfig
fi

log "> STEP 4/5 Configure ffmpeg"

cd $FFMPEG_SOURCE

if [ ! -d $BUILD_DIR/ffmpeg ]
then
    mkdir -p $BUILD_DIR/ffmpeg
else
    rm -rf $BUILD_DIR/ffmpeg/*
fi

echo "check pkg-config"
pkg-config --libs x264
pkg-config --cflags x264
echo "CC: $CC"
echo "CFLAGS: $EXTRA_CFLAGS"

./configure $FF_FLAGS \
--enable-gpl \
--enable-nonfree \
--target-os=android \
--enable-static \
--enable-shared \
--enable-pic \
--enable-strip \
--arch=$CPU_ARCH \
--prefix=$BUILD_DIR/ffmpeg \
--sysroot=$TOOLCHAIN/sysroot \
--disable-programs \
--disable-doc \
--disable-debug \
--disable-asm \
--enable-mediacodec \
--enable-jni \
--logfile=$CONFIGURE_LOG \
--enable-cross-compile \
--pkg-config=pkg-config \
--extra-cflags="$EXTRA_CFLAGS" \
--extra-ldflags="$EXTRA_LDFLAGS" || die "ffmpeg: configure failed"
#--cross-prefix=$CROSS_PREFIX- \
#--cc=$CC \
#--cxx=$CXX \
#--objcc=$CC \
#--dep-cc=$CC \

make_choice "ffmpeg: configure done, proceed compile?" || exit 0

log "> STEP 5/5 Start Compile with $MAX_TH processors"
make clean
make -j $MAX_TH
make install

log "> All Finished"
