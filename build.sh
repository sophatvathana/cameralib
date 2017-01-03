#!/bin/bash -e
###############################################################################
unamestr=`uname`
set -e           
set -E           
set -o pipefail  
#set -x  

output="strmrecv.so"
output_mac="strmrecv.dylib"
output_mac_test="strmrecv"
output_1="strmrecv.so.2"
output_dep="libstrmrecv.so"

target_dir=dist/
#Users/sophatvathana/Desktop/Project/ipcam/IPCAM-VIDEO-STREAMING-API/native/mac/x86_64/
target_dir_dep=../lib/dep/

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

mac_install_NoLib() {
DYLD_LIBRARY_PATH=/usr/local/lib/
g++ -std=c++11 -arch x86_64  -g -W -Wall -O2 -o $output_mac\
	-I$(pwd) \
	-I/System/Library/Frameworks/JavaVM.framework/Versions/A/Headers  \
	-I./include/ \
	-I.\
	-I/usr/local/opt/log4cplus/include/ -L/usr/local/opt/log4cplus/lib/ -llog4cplus \
	-lavcodec -lavformat -lavutil\
	-lstdc++ \
	-stdlib=libc++\
	-fPIC ./src/server.cpp ./src/loghandler.cpp ./src/strmrecvclient.cpp ./src/strmrecvclientapi.cpp ./src/strmjni.cpp\


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
	-Li|--linux)   
		linux_install; ;;
	-M|--mac)     # Set a thing to a value (DEFAULT: $THING)
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
