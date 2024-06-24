#!/bin/bash
set -e

COMPRESS_TYPE="JPG_PNG"
COMPRESS_DIR="."

function usage()
{
cat <<EOF

    usage: jpg_png_compress.sh [options]

    if options are unspecified, print the help information.

    options:
        -s  compress directory,default current directory
        -j  compress jpg
        -p  compress png
        -s  compress size,default 1024k, 1024k/2M

    Example:
        jpg_png_compress.sh -j -s 1024k
        jpg_png_compress.sh -p -s 1024k
        jpg_png_compress.sh -s 1024k
        jpg_png_compress.sh -d static/img/ -s 1024k
EOF
}

function compress_install()
{
    echo
    echo "=======================compress_install=========================="
    echo

    apt install -y jpegoptim
    apt install -y optipng
}

function jpg_compress()
{
    echo
    echo "=======================jpg_compress=========================="
    echo

    COMPRESS_TYPE="JPG"

}

function png_compress()
{
    echo
    echo "=======================png_compress=========================="
    echo

    COMPRESS_TYPE="PNG"

}


function compress_dir()
{
    echo
    echo "=======================compress_dir=========================="
    echo

    COMPRESS_DIR=$OPTARG
}

function compress_size()
{
    echo
    echo "=======================compress_size=========================="
    echo

    echo "dir: $COMPRESS_DIR type: $COMPRESS_TYPE size: $OPTARG"

    if [ $COMPRESS_TYPE == "JPG_PNG" ]
    then
        for jpg_name in $(find $COMPRESS_DIR -maxdepth 1 -regex '.*\(jpg\|JPG\|jpeg\)')
        do
            echo $OPTARG $jpg_name
            jpegoptim --size=$OPTARG $jpg_name
        done
        
        for png_name in $(find $COMPRESS_DIR -maxdepth 1 -regex '.*\(png\)')
        do
            echo $OPTARG $png_name
            optipng $png_name
        done

    elif [ $COMPRESS_TYPE == "JPG" ]
    then

        for jpg_name in $(find $COMPRESS_DIR -maxdepth 1 -regex '.*\(jpg\|JPG\|jpeg\)')
        do
            echo $OPTARG $jpg_name
            jpegoptim --size=$OPTARG $jpg_name
        done

    elif [ $COMPRESS_TYPE == "PNG" ]
    then

        for png_name in $(find $COMPRESS_DIR -maxdepth 1 -regex '.*\(png\)')
        do
            echo $OPTARG $png_name
            optipng $png_name
        done

    fi

}

if [ $# -eq 0 ]
then
    usage
    exit 1
fi

while getopts 'id:jps:' OPT; do
    case $OPT in
        i) compress_install;;
        d) compress_dir;;
        j) jpg_compress;;
        p) png_compress;;
        s) compress_size;;
    esac
done
