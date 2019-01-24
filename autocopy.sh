#!/bin/zsh

######################################################################
#* shared library auto copy tool
#    by forteevo 2019
#
#  Github:
#     https://github.com/forte-evolution/forteevo-tools
#
#  Warning:
#     This script is force delete files in current "files" directory
#      % rm -rf ./files
#
#  Depend(PATH required):
#    zsh,
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
#                                 zsh
#                                 bash
#                                 ls
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

# library libraries
typeset -g -A liblibs
liblibs=()

# library links
typeset -g -A libliblinks
libliblinks=()

# read target commands (HASH value is not using)
typeset -A targetcommands
targetcommands=(sh 1 ln 1)
for a in $*
do  
    targetcommands[$a]=1
done

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
	mkdir -p $files$p_dir
	cp -p $p $files$p_dir

    else
	echo "using [$p] => [/usr/local/bin/$p]"

	porig=$p
	p=/usr/local/bin/$p
	
	# mkdir
	p_dir=`dirname $p`
	mkdir -p $files$p_dir
	cp -p $porig $files$p_dir
    fi
    

    # self
    dockerlines="${dockerlines}COPY $files$p $p\n"
    
    ldd $files$p | awk 'BEGIN{
    ignorefile = "linux-vdso.so.1";
}

$0 ~ ignorefile {
    next;
}

/ *([^ ]+) *=> *([^ ]+) */ {
    print $3 "," $1;
    next;
}

/ *([^ ]+) */ {
    print $1;
}' | while read i
    do
	target=""
	link=""
	
	target=`echo $i | awk -F, '{print $1;}'`
	link=`echo $i | awk -F, '{print $2;}'`
	linkhead=`echo $link | cut -c 1-7`
	if [ "$link" != "" ] && [ "$linkhead" != "/lib64/" ]; then
	    tmp="${target},${link}"
	    libliblinks[$tmp]=1
	fi

	if [ -r $target ]; then
	    dir=`dirname $target`
	    file=`basename $target`
	
	    tmp="${files}${dir}/${file},${dir}/${file}"
	    liblibs[$tmp]=1

	    mkdir -p ./$files$dir
	    cp -p $target ./$files$dir
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

# copy command and libraries
for key in ${(k)targetcommands}
do
    AUTOCOPY $key
done

curdir=`pwd`
cd $files

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

# ln -s
cd ./lib
for key in ${(k)libliblinks}
do
    target=`echo $key | awk -F, '{print $1;}'`
    link=`echo $key | awk -F, '{print $2;}'`
    ln -s $target $link
done
# ./outputdir/files/lib
cd ..
# ./outoutdir/files/

cd ..
# ./outputdir/

rm -f ./$dockerfile
touch ./$dockerfile
if [ ! -w "${dockerfile}" ]; then
    echo "Error: dockerfile cannot write [$dockerfile]"
    exit 3
fi
echo "FROM scratch" > $dockerfile

cd $files
tar cvf $curdir/files.tar ./

cd $curdir
gzip files.tar
if [ ! -r files.tar.gz ]; then
    echo "Error: gzip file cannot read"
    exit 4
fi
echo "ADD ./files.tar.gz /" >> $dockerfile
echo "CMD [\"/bin/sh\"]" >> $dockerfile


cd ..
