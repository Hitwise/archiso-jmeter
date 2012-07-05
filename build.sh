#! /bin/bash -e
if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

installed=`whereis archiso`
regex="archiso\: /usr/share/archiso"
if [[ ! $installed =~ $regex ]]; then
    echo -e "Archiso does not appear to be installed. Please look at the README"
    exit 2
fi
#check that we have been given a directory
if [ $# -ne 1 ]; then
	echo "You need to supply a writable directory"
    exit 3
fi
work_directory=$1
echo -e "Using '${work_directory}' as base work directory"
if [ ! -d $work_directory ]; then
	echo "You need to supply an actual directory. Try quoting or escaping it if it has spaces"
    exit 4
fi


#check free space
min_space_required=1700 #in units of 1024 mb
space_avaliable=`df -BM -P ${work_directory} | sed -e 1d | awk '{print $4}' | sed -e 's:M::'`
echo -e "${space_avaliable}M avaliable in work directory"

if [ $space_avaliable -lt $min_space_required ]; then
    echo -e "You do not have enough space to build archiso-jmeter. \nRequired: ${min_space_required}M \nAvaliable: ${space_avaliable}M" 
    exit 5
fi
#ask for an actual clobberable temp folder
temp_directory=`mktemp -d --tmpdir=${work_directory}`
echo -e "Using '${temp_directory}' as temporary build directory"

#figure out where this script is
SOURCE="${BASH_SOURCE[0]}"
script_dir="$( dirname "$SOURCE" )"
while [ -h "$SOURCE" ]
do 
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  script_dir="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
done
script_dir="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
echo $script_dir

#now append the path to configs/releng
source_dir="${script_dir}/configs/releng"
echo -e "Copying from ${source_dir} to ${temp_directory}"
#start copying stuff...
cp -R ${source_dir}/* ${temp_directory}

echo -e "Calling Archiso build command"
cd ${temp_directory}
${temp_directory}/build.sh build single netinstall

#move iso file from ${temp_directory}/out to $script_dir out and change group permissions

#check that the destination directory exists
dest_dir="${script_dir}/build"
if [ ! -d $dest_dir ]; then
    echo "Creating ${dest_dir} and changing group to users"
    mkdir $dest_dir
    chgrp users $dest_dir
    chmod g+xrw $dest_dir
fi

echo "Moving output files..."
mv -v ${temp_directory}/out/* $dest_dir
echo "Changing group permissions..."
chgrp -R users $dest_dir

echo "Cleaning up: deleting temporary directory..."
rm -rf ${temp_directory}

echo "Done!"