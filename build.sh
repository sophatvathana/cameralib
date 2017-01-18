# @Author: sophatvathana
# @Date:   2017-01-12 11:43:54
# @Last Modified by:   sophatvathana
# @Last Modified time: 2017-01-12 13:17:02
#!/bin/bash -e
###############################################################################

# yum install centos-release-scl-rh
# yum install devtoolset-3-gcc devtoolset-3-gcc-c++
# scl enable devtoolset-3 bash

unamestr=`uname`
set -e           
set -E           
set -o pipefail  
#set -x  

output="strmrecv.so"
output_mac="strmrecv"
output_mac_test="strmrecv"
output_1="strmrecv.so.2"
output_dep="libstrmrecv.so"

target_dir=dist/
#/Users/sophatvathana/Desktop/Project/ipcam/IPCAM-VIDEO-STREAMING-API/native/mac/x86_64/
target_dir_dep=../lib/dep/
if [[ $unamestr == "Darwin" ]];then
	echo "work"
	GCC_HOME=/usr/local/opt/
	else 
		GCC_HOME=/usr/local/include/
fi


function install_boost {
: ${PATH:=}
: ${LD_LIBRARY_PATH:=}

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <version: 1.39.0>"
  exit 1
fi

VERSION="$1"
VERSION_UNDERSCORES="$(echo "$VERSION" | sed 's/\./_/g')"
TARBALL="boost_${VERSION_UNDERSCORES}.tar.gz"
DOWNLOAD_URL="https://sourceforge.net/projects/boost/files/boost/${VERSION}/${TARBALL}"

if [ -z "${GCC_HOME}" ]; then
  echo "[FATAL] \$GCC_HOME is not set"
  exit 1
fi

GCC_VERSION="$(gcc -dumpversion)"

echo "[INFO] Boost '$VERSION'"
echo "[INFO] GCC   '$GCC_VERSION'"

# Installation location
: ${PREFIX:=${VERSION_UNDERSCORES}/gcc/${GCC_VERSION}}

mkdir -p "$PREFIX"
cd "$PREFIX"
PREFIX="$(pwd)"

echo "[INFO] Installing to '$PREFIX'"

echo "[INFO] Creating workspace in '$(pwd)'"
mkdir -p workspace
cd workspace

SOURCE="$(pwd)/boost_${VERSION_UNDERSCORES}"

#-------------------------------------------------------------------------------
# Download and unpack
#-------------------------------------------------------------------------------
if [ ! -f "$TARBALL" ]; then
    echo "[INFO] Downloading '$DOWNLOAD_URL'"
    wget --no-check-certificate "$DOWNLOAD_URL"
else
    echo "[INFO] '$TARBALL' already exists. Skipping..."
fi

if [ ! -d "$SOURCE" ]; then
    echo "[INFO] Unpacking $TARBALL"
    tar xzf "$TARBALL"
else
    echo "[INFO] '$SOURCE' already exists. Skipping..."
fi

#-------------------------------------------------------------------------------
# Setup build environment and toolchain
#-------------------------------------------------------------------------------
echo "[INFO] Build environment:"
echo "[INFO] - BOOST  ${GCC_VERSION}"

#-------------------------------------------------------------------------------
# Build and install
#-------------------------------------------------------------------------------
cd "$SOURCE"

if [ ! -e "${PREFIX}/bin" ]; then
    echo "[INFO] Configuring BOOST"
    time "./bootstrap.sh" --prefix="${PREFIX}"

    echo "[INFO] Building BOOST"
    BOOST_BUILD_CMD=
    if [ -e "${SOURCE}/bjam" ]; then
        BOOST_BUILD_CMD="bjam"
    elif [ -e "${SOURCE}/b2" ]; then
        BOOST_BUILD_CMD="b2"
    else
      echo "[ERROR] boost build script not found (bjam/b2)"
    fi

    PROCESSORS="$(cat /proc/cpuinfo | grep processor | wc -l)"
    PARALLELISM="$((($PROCESSORS * 2)))"
    echo "[INFO] Using '$PARALLELISM' levels of parallelism"

    time "./${BOOST_BUILD_CMD}" install --prefix="${PREFIX}" -j "${PARALLELISM}"

    if [ "$(uname --machine)" = "x86_64" ]; then
        export LIBDIR="lib64"
    else
        export LIBDIR="lib"
    fi

    echo "[INFO] Creating BOOST environment setup file"
    cat > "${PREFIX}/setup.sh" <<-EOF
	#!/bin/bash
	#
	# Automatically generated by $0 on $(date)
	export BOOST_HOME="${PREFIX}"
	export LD_LIBRARY_PATH="\${BOOST_HOME}/lib:\${LD_LIBRARY_PATH}"
	source "${GCC_HOME}/setup.sh"
EOF

    echo "[INFO] Setting file permissions for group"

    chmod -R g+r "${PREFIX}"
    find "${PREFIX}" -type d -exec chmod g+x {} \;
else
    echo "[INFO] Installation already exists in '$PREFIX'. Skipping..."
fi
cd ../../
sudo cp -r `pwd`/include/boost/ /usr/local/include
sudo cp -r `pwd`/lib/* /usr/local/lib/

echo "[INFO] Success!"
rm -r $VERSION_UNDERSCORES
}

on_err() {
	echo ">> ERROR: $?"
	FN=0
	for LN in "${BASH_LINENO[@]}"; do
		[ "${FUNCNAME[$FN]}" = "main" ] && break
		echo ">> ${BASH_SOURCE[$FN]} $LN ${FUNCNAME[$FN]}"
		FN=$(( FN + 1 ))
	done
}
trap on_err ERR


declare -a EXIT_CMDS
add_exit_cmd() { EXIT_CMDS+="$*;  "; }
on_exit(){ eval "${EXIT_CMDS[@]}"; }
trap on_exit EXIT

CMD_PWD=$(pwd)
CMD="$0"
CMD_DIR="$(cd "$(dirname "$CMD")" && pwd -P)"

[ "$VERBOSE" ] ||  VERBOSE=
[ "$DEBUG" ]   ||  DEBUG=
[ "$THING" ]   ||  THING=123	# assuming that you have a thing

out() { echo "$(date +%Y%m%dT%H%M%SZ): $*"; }
err() { out "$*" 1>&2; }
vrb() { [ ! "$VERBOSE" ] || out "$@"; }
dbg() { [ ! "$DEBUG" ] || err "$@"; }
die() { err "EXIT: $1" && [ "$2" ] && [ "$2" -ge 0 ] && exit "$2" || exit 1; }

if [[ $unamestr == "Darwin" ]]; then
	echo "MacOsx"
	lopenssl=$GCC_HOME"openssl/"
	llog4cplus=$GCC_HOME"log4cplus/"
	else
	lopenssl=$GCC_HOME"openssl/"
	llog4cplus=$GCC_HOME"log4cplus/"
	libdir=/usr/local/lib/
fi

linux_install() {

g++ -g -W -Wall -O2 -shared -o $output\
	-I$(pwd) \
	-I/usr/lib/jvm/default-java/include/linux \
	-I/usr/lib/jvm/default-java/include \
	-L/usr/lib/jvm/default-java/jre/lib/amd64/server/ \
	-L/usr/bin/java \
	-I../include/ \
	-lstdc++ -llog4cplus\
	-fPIC -rdynamic strmrecv.cpp strmjni.cpp \
	-ljvm \

cp $output $target_dir

}

mac_install() {
DYLD_LIBRARY_PATH=/usr/local/lib/
g++ -g -W -Wall -O2 -dynamiclib -o $output_mac\
	-I$(pwd) \
	-I/System/Library/Frameworks/JavaVM.framework/Versions/A/Headers  \
	-I../include/ \
	-lstdc++ -llog4cplus\
	-fPIC -rdynamic main.cpp strmrecv.cpp strmjni.cpp logfactory.cpp\

cp $output_mac $target_dir
exit 1;
}

linux_install_NoLib() {
DYLD_LIBRARY_PATH=/usr/local/lib/
g++ -std=c++14 -g -W -Wall -O2 -o $output_mac\
	-I$(pwd) \
	-I./include/ \
	-I/usr/include/ \
	-I./src/ \
	-L/usr/local/lib/\
	-I/usr/local/include/log4cplus/ -llog4cplus \
	-I/usr/local/opt/include/ \
	-L/usr/local/opt/lib/\
	-lavcodec -lavformat -lavutil\
	-I$lopenssl\
	-I$lopenssl"include"\
	-L$lopenssl"lib"\
	-lpthread -L/usr/lib/x86_64-linux-gnu -L/usr/lib -I/usr/include/boost -I/usr/local/include/boost -lboost_system -lboost_regex\
	-lstdc++ -ldl -static-libstdc++\
	-fPIC \
	-L/lib64/\
	./src/runner.cpp \
	./src/base64.cpp \
	./src/loghandler.cpp \
	./src/strmrecvclient.cpp \
	./src/strmrecvclientapi.cpp\
	./src/package.cpp\
    	./src/connection.cpp \
    	./src/response.cpp\
    	./src/request.cpp\
    	./src/parser.cpp\
    	./src/ThreadPool.cpp\
    	./src/server.cpp\
    	./src/RequestHandler.cpp\
    	./src/MimeType.cpp\
       ./src/utils.cpp\
    	./src/net.cpp\
    	./src/TcpConnection.cpp\
    	./src/exception.cpp\


cp $output_mac $target_dir
exit 1;
}

mac_install_NoLib() {
DYLD_LIBRARY_PATH=/usr/local/lib/
g++ -std=c++14 -arch x86_64  -g -W -Wall -O2 -o $output_mac\
	-I$(pwd) \
	-I./include/ \
	-I.\
	-I./src/ \
	-I$llog4cplus"include"/ -L$llog4cplus"lib"/ -llog4cplus \
	-lavcodec -lavformat -lavutil\
	-I$lopenssl\
	-I$lopenssl"include"\
	-L$lopenssl"lib"\
	-lssl -lcrypto -lpthread -lboost_system -lboost_regex\
	-lstdc++ \
	-stdlib=libc++\
	-fPIC \
	./src/runner.cpp \
	./src/base64.cpp \
	./src/loghandler.cpp \
	./src/strmrecvclient.cpp \
	./src/strmrecvclientapi.cpp\
	./src/package.cpp\
    	./src/connection.cpp \
    	./src/response.cpp\
    	./src/request.cpp\
    	./src/parser.cpp\
    	./src/ThreadPool.cpp\
    	./src/server.cpp\
    	./src/RequestHandler.cpp\
    	./src/MimeType.cpp\
       ./src/utils.cpp\
    	./src/net.cpp\
    	./src/TcpConnection.cpp\
    	./src/exception.cpp\


cp $output_mac $target_dir
exit 1;
}

mac_install_Lib() {
DYLD_LIBRARY_PATH=/usr/local/lib/
g++ -std=c++11 -dynamiclib -arch x86_64  -g -W -Wall -O2 -o $output_mac\
	-I$(pwd) \
	-I/System/Library/Frameworks/JavaVM.framework/Versions/A/Headers  \
	-I./include/ \
	-I.\
	-I/usr/local/opt/log4cplus/include/ -L/usr/local/opt/log4cplus/lib/ -llog4cplus \
	-lavcodec -lavformat -lavutil\
	-lstdc++ \
	-stdlib=libc++\
	-fPIC -rdynamic ./src/main.cpp ./src/loghandler.cpp ./src/strmrecvclient.cpp ./src/strmrecvclientapi.cpp ./src/strmjni.cpp\


cp $output_mac $target_dir
exit 1;
}

mac_install_test() {
	g++  -std=c++11 -Wall -Wextra -Wshadow -Wformat-security -Winit-self -Wmissing-prototypes -O2 -D OSX -o $output_mac_test\
	-I$(pwd) \
	-I../include/ \
	 -I /usr/local/include\
       -I /usr/local/opt/log4cplus/include/ -L  /usr/local/opt/log4cplus/lib/ -l log4cplus \
       -fPIC main.cpp \

cp $output_mac_test $target_dir
exit 1;
}
function ProgressBar {
	let _progress=(${1}*100/${2}*100)/100
	let _done=(${_progress}*4)/10
	let _left=40-$_done
	_done=$(printf "%${_done}s")
	_left=$(printf "%${_left}s")

printf "\rProgress : [${_done// /#}${_left// /-}] ${_progress}%%"

}
function program_is_installed {
  # set to 1 initially
  local return_=1
  # set to 0 if not found
  type $1 >/dev/null 2>&1 || { local return_=0; }
  # return value
  echo "$return_"
}

function iFolderIsExist {
	local return_=0
	if [ -d $1$2 ];then
		local return_=1; 
	fi
	echo "$return_"
}

function npm_package_is_installed {
  # set to 1 initially
  local return_=1
  # set to 0 if not found
   which $1 >/dev/null 2>&1 || { local return_=0; }
  # return value
  echo "$return_"
}

function echo_fail {
  # echo first argument in red
  printf "\e[31m ✘ ${1} \033[0m"
  # reset colours back to normal
  #echo '\033[0m'
}

function echo_pass {
  # echo first argument in green
  printf "\e[32m ✔ ${1} \033[0m"
  # reset colours back to normal
  #echo '\033[0m'
}

function echo_if {
  if [ $1 == 1 ]; then
    echo_pass $2
  else
    echo_fail $2
  fi
}

if [[ $unamestr == "Darwin" && $(program_is_installed brew) != 1 ]]; then
	echo "Installation brew"
	/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

check_log4cplus() {
	if [[ $(iFolderIsExist $GCC_HOME "log4cplus") != 1 ]]; then
		if [[ $unamestr == "Darwin" ]]; then
		echo "Installation Log4cplus"
		brew install log4cplus
		else
		echo "Installation log4cplus"
		if [[ $(iFolderIsExist "./" "log4cplus") != 1 ]]; then
			sudo rm -vrf log4cplus >/dev/null
		fi
		mkdir log4cplus
		cd log4cplus 
		wget https://github.com/log4cplus/log4cplus/archive/REL_1_2_0.tar.gz
		tar -xvzf REL_1_2_0.tar.gz
		rm REL_1_2_0.tar.gz
		cd log4cplus-REL_1_2_0/
		COMMON_FLAGS="-L/lib/x86_64-linux-gnu/ -L/usr/lib/x86_64-linux-gnu/ -mt=yes -O"
		./configure --enable-threads=yes LDFLAGS="-lpthread"
		make
		sudo make install
		cd ../../
	fi
	fi
}
check_log4cplus
check_boost() {
	if [[ $(iFolderIsExist $GCC_HOME "boost") != 1 ]]; then
		if [[ $unamestr == "Linux" ]]; then
			OS=$(lsb_release -si)
			if [[ $OS == "CentOS" ]]; then
				sudo yum install centos-release-scl
				sudo yum install devtoolset-4
				sudo yum install python-devel
				scl enable devtoolset-4 bash
				echo "Installation boost"
				install_boost "1.63.0"
				else
			sudo apt-get install libbz2-dev    
			sudo apt-get install python-dev
			echo "Installation boost"
			install_boost "1.63.0"
		fi
		fi
	fi
}
check_boost
check_ffmpeg() {
	if [[ $(program_is_installed ffmpeg) != 1 ]]; then
		 cd ./tools/components
		 sudo ./install.sh
		 cd ../../
	fi
}
check_ffmpeg
#strmrecvclient.cpp istrmrecvclient.cpp logfactory.cpp
show_help() {
	awk 'NR>1{print} /^(###|$)/{exit}' "$CMD"
	echo "USAGE: $(basename "$CMD") [arguments]"
	echo "ARGS:"
	MSG=$(awk '/^NARGS=-1; while/,/^esac; done/' "$CMD" | sed -e 's/^[[:space:]]*/  /' -e 's/|/, /' -e 's/)//' | grep '^  -')
	EMSG=$(eval "echo \"$MSG\"")
	echo "$EMSG"
}

NARGS=-1; while [ "$#" -ne "$NARGS" ]; do NARGS=$#; case $1 in
	# SWITCHES
	-h|--help)      # This help message
		show_help; exit 1; ;;
	-d|--debug)     # Enable debugging messages (implies verbose)
		DEBUG=$(( DEBUG + 1 )) && VERBOSE="$DEBUG" && shift && echo "#-INFO: DEBUG=$DEBUG (implies VERBOSE=$VERBOSE)"; ;;
	-v|--verbose)   # Enable verbose messages
		VERBOSE=$(( VERBOSE + 1 )) && shift && echo "#-INFO: VERBOSE=$VERBOSE"; ;;
	# PAIRS
	-Linux|--linux)   
		linux_install_NoLib; ;;
	-Mac|--mac)     # Set a thing to a value (DEFAULT: $THING)
		mac_install_NoLib; ;;
	*)
		break;
esac; done

[ "$DEBUG" ]  &&  set -x

###############################################################################

# Validate some things

[ $# -gt 0 -a -z "$THING" ]  &&  THING="$1"  &&  shift
[ "$THING" ]  ||  die "You must provide some thing!"
[ $# -eq 0 ]  ||  die "ERROR: Unexpected commands!"

