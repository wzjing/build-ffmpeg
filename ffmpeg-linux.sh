#/bin/bash

# info
VERSION=0.1
AUTHOR=wzjing
DESCRIPTION="this script can build ffmpeg lib"

# command line argment

ARGS=`getopt -o vhy --long version,help,yes,enable-libx264,enable-text -n 'testh.sh' -- "$@"`

if [[ $? != 0 ]]; then
    echo "invalid command, use -h/--help to see how to use."
    exit 1;
fi

# Congifure deault values
DEBUG=false
MAX_TH=$(cat /proc/cpuinfo | grep "processor" | wc -l)
ENABLE_X264=false
ENABLE_FDK_AAC=false
ENABLE_TEXT=false
EXTRA_CFLAGS="-fPIC -fPIE"
EXTRA_LDFLAGS="-fpie"
ASM_CONFIG=""
ALL_YES=false
FFMPEG_SOURCE=`pwd`/ffmpeg
X264_SOURCE=`pwd`/x264
FREE_TYPE_SOURCE=`pwd`/freetype
FONT_CONFIG_SOURCE=`pwd`/fontconfig
XML2_SOURCE=`pwd`/xml2
# FRIBIDI_SOURCE=`/fribidi`
FF_FLAGS="--disable-avdevice \
--disable-postproc \
--disable-decoders \
--disable-encoders \
--disable-muxers \
--disable-demuxers \
--enable-decoder=aac \
--enable-decoder=mp3 \
--enable-decoder=h263 \
--enable-decoder=h264 \
--enable-decoder=hevc \
--enable-decoder=mpeg4 \
--enable-decoder=png \
--enable-decoder=gif \
--enable-encoder=aac \
--enable-encoder=h263 \
--enable-encoder=libx264 \
--enable-encoder=mpeg4 \
--enable-encoder=png \
--enable-encoder=gif \
--enable-bsf=h264_mp4toannexb \
--enable-bsf=hevc_mp4toannexb \
--enable-parser=aac \
--enable-parser=aac_latm \
--enable-parser=mpegaudio \
--enable-parser=mpegvideo \
--enable-parser=mpeg4video \
--enable-parser=h263 \
--enable-parser=h264 \
--enable-parser=hevc \
--enable-parser=gif \
--enable-parser=png \
--enable-demuxer=flv \
--enable-demuxer=gif \
--enable-demuxer=h264 \
--enable-demuxer=hevc \
--enable-demuxer=aac \
--enable-demuxer=mp3 \
--enable-demuxer=mov \
--enable-demuxer=mpegts \
--enable-demuxer=mpegtsraw \
--enable-demuxer=mpegvideo \
--enable-muxer=flv \
--enable-muxer=mp3 \
--enable-muxer=latm \
--enable-muxer=adts \
--enable-muxer=mov \
--enable-muxer=mp4 \
--enable-muxer=gif \
--enable-muxer=mpegts"

debug() {
    if $DEBUG
    then
        echo -e $*
    fi
}

info() {
    echo -e "\033[36m$*\033[0m"
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

success() {
    echo -e "\033[32m$*\033[0m"
}

die() {
    error $*
    exit 1
}

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

make_choice() {
    warn "$1 Y/N[Y]"
    if $ALL_YES
    then
        choice=Y
    else
        read -n1 choice
    fi
    if [[ $choice =~ ^[yY] || -z $choice ]]
    then
        return 0
    elif [[ $choice =~ ^[nN] ]]
    then
    	echo ""
        return 1
    else
        choice=""
        warn -n "invalid choice '$choice' use Y or N: "
        make_choice
    fi
}

build_xml2() {

    if [[ -e $BUILD_DIR/lib/libxml2.so ]]
    then
        make_choice "found exist libxml2 builds, use it?" && return 0
    fi

	log "libxml2: start build..."

    cd $XML2_SOURCE

    log "libxml2 configuring..."

    ./autogen.sh --prefix=$1 \
    --disable-static \
    --enable-shared \
    --with-debug=off || die "libxml2: autogen.sh failed"

    ./configure --prefix=$1 || die "libxml2: configure fialed"

    make_choice "libxml2: configure done, start build?" || exit 0
    
    make clean
    make -j $MAX_TH || die "libxml2: build failed"
    make install
    success "libxml2: build finished"
    
    return 0
}

build_fontconfig() {

    if [[ -e $BUILD_DIR/lib/libfontconfig.so ]]
    then
        make_choice "found exist libfontconfig builds, use it?" && return 0
    fi

	log "libfontconfig: start build..."

    cd $FONT_CONFIG_SOURCE

    log "libfontconfig configuring..."

    ./autogen.sh --prefix=$1 \
    --disable-static \
    --enable-shared \
    --enable-libxml2 || die "libfontconfig: autogen.sh failed"

    ./configure --prefix=$1 || die "libfontconfig: configure fialed"

    make_choice "libfontconfig: configure done, start build?" || exit 0
    
    make clean
    make -j $MAX_TH || die "libfontconfig: build failed"
    make install
    success "libfontconfig: build finished"
    
    return 0
}

build_freetype() {

    if [[ -e $BUILD_DIR/lib/libfreetype.so ]]
    then
        make_choice "found exist libfreetype builds, use it?" && return 0
    fi

	log "libfreetype: start build..."

    cd $FREE_TYPE_SOURCE

    log "libfreetype configuring..."

    ./autogen.sh --prefix=$1 \
    --disable-static \
    --enable-shared || die "libfreetype: autogen.sh failed"

    ./configure --prefix=$1 || die "libfreetype: configure failed"

    make_choice "libfreetype: configure done, start build?" || exit 0
    
    make clean
    make -j $MAX_TH || die "libfreetype: build failed"
    make install
    success "libfreetype: build finished"
    
    return 0
}

build_x264() {

    if [[ -e $BUILD_DIR/lib/libx264.so ]]
    then
        make_choice "found exist libx264 builds, use it?" && return 0
    fi
    
    log "libx264: start build..."
    
    cd $X264_SOURCE
    
    log "libx264: configuring..."
    
    
    ./configure --prefix=$1 \
    --host=x86_64-linux \
    --disable-static \
    --enable-shared \
    --enable-pic \
    --enable-strip \
    --extra-cflags="$EXTRA_CFLAGS" \
    --extra-ldflags="$EXTRA_LDFLAGS" \
    --disable-cli \
    $ASM_CONFIG || die "libx264: configure failed"
    
    warn "CFLAGS: $EXTRA_CFLAGS"
    warn "LDLAGS: $EXTRA_LDFLAGS"
    make_choice "libx264: configure done, start build?" || exit 0
    
    make clean
    make -j $MAX_TH || die "libx264: build failed"
    make install
    success "libx264: build finished"
    
    return 0
}

build_ffmpeg() {
    
    log "ffmpeg: start build..."
    
    log "ffmpeg: check pkg-config"
    pkg-config --libs x264 freetype2
    pkg-config --cflags x264 freetype2
    
    log "ffmpeg: configuring..."
    
    cd $FFMPEG_SOURCE
    
    ./configure $FF_FLAGS \
    --enable-gpl \
    --enable-version3 \
    --enable-nonfree \
    --target-os=linux \
    --disable-static \
    --enable-shared \
    --enable-pic \
    --arch=x86_64 \
    --prefix=$1 \
    --enable-small \
    --disable-programs \
    --disable-doc \
    --enable-debug \
    --logfile=$CONFIGURE_LOG \
    --cc=$CC \
    --cxx=$CXX \
    --objcc=$CC \
    --dep-cc=$CC \
    --pkg-config=pkg-config \
    --extra-cflags="$EXTRA_CFLAGS" \
    --extra-ldflags="$EXTRA_LDFLAGS" \
    $ASM_CONFIG || die "ffmpeg: configure failed"
    
    warn "CFLAGS: $EXTRA_CFLAGS"
    warn "LDLAGS: $EXTRA_LDFLAGS"
    make_choice "ffmpeg: configure done, start compile?" || exit 0
    
    make clean
    make -j $MAX_TH || die "ffmpeg: build failed"
    make install
    success "ffmpeg: build finished"
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
This is script to compile ffmpeg

Usage: $0 --arch <arch> --api <min-version>

Options:
    --arch <arch>           cpu arch [arm, arm64, x86, x86_64]
    --api <min-version>     min api support, the lowest version is 16
                                if use 64-bit arch like arm64 and x86_64
                                api must greater or equal than 21
    --enable-libx264        enable libx264 for H264 codec
    --enable-libfdk-aac     enable libfdk-aac for aac codec
    --enable-text     		enable text libs for draw text

Example:
    $0 --arch arm64 --api 21 --enable-libx264

EOF
            exit 0
        ;;
        --enable-libx264)
            debug x264
            ENABLE_X264=true
            FF_FLAGS+=" --enable-libx264"
            shift 1
        ;;
        --enable-text)
            debug text
            FF_FLAGS+=" --enable-libfreetype --enable-libfontconfig"
            ENABLE_TEXT=true
            shift 1
        ;;
        -y|--yes)
            debug yes
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

ARCH=x64

BUILD_DIR=`pwd`/build/$ARCH
CONFIGURE_LOG=$BUILD_DIR/configure.log
CONFIGURE_EXEC_LOG=$BUILD_DIR/configure_exec.log

test -e $FFMPEG_SOURCE/configure && FFMPEG_SOURCE_EXIST=true || FFMPEG_SOURCE_EXIST=false
test -e $X264_SOURCE/configure && X264_SOURCE_EXIST=true || X264_SOURCE_EXIST=false
test -e $FREE_TYPE_SOURCE/autogen.sh && FREE_TYPE_SOURCE_EXIST=true || FREE_TYPE_SOURCE_EXIST=false
test -e $FONT_CONFIG_SOURCE/autogen.sh && FONT_CONFIG_SOURCE_EXIST=true || FONT_CONFIG_SOURCE_EXIST=false
test -e $XML2_SOURCE/configure && XML2_SOURCE_EXIST=true || XML2_SOURCE_EXIST=false
# test -e $FRIBIDI_SOURCE/configure && FRIBIDI_SOURCE_EXIST=true || FRIBIDI_SOURCE_EXIST=false
	
if [[ $ARCH =~ ^x86* ]]
then
	ASM_CONFIG="--disable-asm"
else
    ASM_CONFIG=""
fi

# configure information

TOOLCHAIN=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64

cat <<EOF
Build info:

  Libs:
  ffmpeg         `lib_info true $FFMPEG_SOURCE_EXIST`
  libx264:       `lib_info $ENABLE_X264 $X264_SOURCE_EXIST`
  libfreetype:   `lib_info $ENABLE_TEXT $FREE_TYPE_SOURCE_EXIST`
  libfontconfig: `lib_info $ENABLE_TEXT $FONT_CONFIG_SOURCE_EXIST`
  libxml2:       `lib_info $ENABLE_TEXT $XML2_SOURCE_EXIST`

  Build options:
  CPU:          $ARCH
  MIN_API:      $MIN_API
  NDK:          $NDK_ROOT
  LOG:          $CONFIGURE_LOG
  BUILD_DIR:    $BUILD_DIR
  TRHEADS:      $MAX_TH
  TOOLCHAIN     $TOOLCHAIN
  ASM           $ASM_CONFIG

EOF

make_choice "All configure OK?" || exit 0

info "> STEP 1/5 Check source code"

if ! $FFMPEG_SOURCE_EXIST
then
    warn "> Cloning ffmpeg source code"
    git clone https://git.ffmpeg.org/ffmpeg.git $FFMPEG_SOURCE
fi

if ! $X264_SOURCE_EXIST
then
    warn "> Cloning x264 source code"
    git clone https://code.videolan.org/videolan/x264.git $X264_SOURCE
fi

if ! $XML2_SOURCE_EXIST
then
    warn "> Cloning xml2 source code"
    git clone https://gitlab.gnome.org/GNOME/libxml2.git xml2
fi

if ! $FONT_CONFIG_SOURCE_EXIST
then
    warn "> Cloning fontconfig source code"
    git clone https://gitlab.freedesktop.org/fontconfig/fontconfig.git fontconfig
fi

if ! $FREE_TYPE_SOURCE_EXIST
then
    warn "> Cloning freetype source code"
    git clone https://git.savannah.gnu.org/git/freetype/freetype2.git freetype
fi

success "Source code is ok"

info "> STEP 2/5 Initial Toolchain"

export CC=clang-8
export CXX=clang++-8

cat <<EOF
  Toolchain info:

  CC:    $CC (`$CC --version | grep -E "\bclang\sversion\s[0-9.]+" -o`)
  CXX:   $CXX (`$CXX --version | grep -E "\bclang++\sversion\s[0-9.]+" -o`)
  AS     $AS  (`$AS --version | grep -E "\bclang\sversion\s[0-9.]+" -o`)
  AR:    $AR (`$AR --version | head -1`)
  LD:    $LD (`$LD --version | head -1`)
  STRIP: $STRIP (`$STRIP --version | head -1`)

EOF

make_choice "Toolchain configure finished, continue?" || exit 0

info "> STEP 3/5 Build libraries"

export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$BUILD_DIR/lib/pkgconfig

$ENABLE_TEXT && build_xml2 $BUILD_DIR

$ENABLE_TEXT && build_freetype $BUILD_DIR

$ENABLE_TEXT && build_fontconfig $BUILD_DIR

$ENABLE_X264 && build_x264 $BUILD_DIR

info "> STEP 4/5 Build ffmpeg"

log "Start build ffmpeg: "
build_ffmpeg $BUILD_DIR

info "> All Finished"
