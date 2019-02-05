#!/bin/sh

######################################################################
#* shared library auto copy tool
#    by forteevo 2019
#
#  Github:
#     https://github.com/forte-evolution/forteevo-tools
#
#  Warning:
#     This script is force delete files in current "files" directory
#      % rm -rf ./output/
#
#  Depend(PATH required):
#    sh(dash),
#    awk, rm, mkdir, cp, ln, which, ldd, dirname, basename
#
#  USAGE:
#
#    1. exec
#      % ./autocopy.sh zsh bash ls cp cat
#
#    3. end
#      This scipt outputs
#      % ls -l
#          ./autocopy.sh
#          ./output/
#                   Dockerfile
#                   files.tar.gz
#                   files/
#                         lib/
#                             libc.so.6
#                             x86_64-.../libxxx.so
#                         bin/
#                             sh
#                         usr/bin/
#                                 bash
#                                 ls
#                                 cat
#                                 ...
#
#  Development Environment:
#     Debian GNU/Linux 10.0 buster amd64
#
######################################################################


# outputdir
readonly outputdir=./output
if [ ! -d $outputdir ]; then
    mkdir $outputdir
fi
cd $outputdir

# files (rm -rf $files, every execute this script)
readonly files=./files

# output Dockerfile
readonly dockerfile=./Dockerfile

######################################################################
AUTOCOPY(){
    # target
    p=$1
    if [ ! -r $p ]; then
	p=`which $1`
	if [ ! -r $p ]; then
	    echo "Warning: command not found. skipping. [$p]"
	    return
	fi
	
	# copy target
	p_dir=`dirname $p`
	mkdir -p .$p_dir
	cp -p $p .$p_dir

    else
	echo "using [$p] => [/usr/local/bin/$p]"

	porig=$p
	p=/usr/local/bin/$p
	
	# mkdir
	p_dir=`dirname $p`
	mkdir -p $p_dir
	cp -p $porig .$p_dir
    fi
    
    ldd .$p >> $lddres
}

COPYANDLN(){
    cat $1 | awk 'BEGIN{
    ignorefile = "linux-vdso.so.1";
}

$0 ~ ignorefile {
    next;
}

/ *([^ ]+) *=> *([^ ]+) */ {
    #print $3 "," $1;
    data[$3]=1
    data[$3 "," $1]=1
    next;
}

/ *([^ ]+) */ {
    #print $1;
    data[$1]=2
}

END{
    for(key in data){
        print key;
    }
}' | while read i
    do
	target=""
	link=""
	
	target=`echo $i | awk -F, '{print $1;}'`
	link=`echo $i | awk -F, '{print $2;}'`
	linkhead=`echo $link | cut -c 1-7`
	if [ "$link" != "" ] && [ "$linkhead" != "/lib64/" ]; then
	    if [ ! -d ./lib ]; then
		mkdir ./lib
	    fi
	    cd ./lib
	    ln -s $target $link
	    cd ..
	fi

	if [ -r $target ]; then
	    dir=`dirname $target`
	    file=`basename $target`
	    mkdir -p .$dir
	    cp -p $target .$dir
	fi
    done
}

######################################################################
# main

if [ `pwd` = "/" ]; then
    echo "Error: can not use root dir."
    exit 1
fi

# remove/mk dir
rm -rf ./$files files.tar files.tar.gz
mkdir ./$files
if [ ! -d "${files}" ]; then
    echo "Error: failed mkdir [$files]."
    exit 2
fi

curdir=`pwd`
cd $files

# copy command
lddres="../temp"
rm -f $lddres
touch $lddres
for key in $*
do
    AUTOCOPY $key
done

# exec copy and "ln -s"
COPYANDLN $lddres
rm -f $lddres

# force set /bin/sh
if [ ! -d ./bin ]; then
    mkdir ./bin/
fi
if [ ! -r ./bin/sh ]; then
    if [ -r ./usr/bin/sh ]; then
	cp ./usr/bin/sh ./bin/
    elif [ -r /bin/sh ]; then
	cp /bin/sh ./bin/
    fi
fi

tar cvf $curdir/files.tar ./

# cd to ./output/
cd ..

gzip files.tar
if [ ! -r files.tar.gz ]; then
    echo "Error: gzip file cannot read"
    exit 4
fi

# Make Dockerfile
rm -f ./$dockerfile
touch ./$dockerfile
if [ ! -w "${dockerfile}" ]; then
    echo "Error: dockerfile cannot write [$dockerfile]"
    exit 3
fi
echo "FROM scratch" > $dockerfile
echo "ADD ./files.tar.gz /" >> $dockerfile
echo "CMD [\"/bin/sh\"]"    >> $dockerfile

cd $curdir

# finish!
