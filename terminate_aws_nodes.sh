#!/bin/bash
#
#
# This script terminates AWS instances with tag $NAMETAG
#
# This script assumes the environment variables EC2_CERT and EC2_PRIVATE_KEY are set.
#

SCRIPTDIR=.

if [ $# -ne 2 ]
then
   printf "usage $0 <nametag> <region>\n"
   exit 1
fi

NAMETAG=$1
REGION=$2
OUTDIR=output/${NAMETAG}

# terminate instances (if existing)
INSTANCE_FILE=${SCRIPTDIR}/${OUTDIR}/._instance_ids
if [[ -r $INSTANCE_FILE ]]; then
    while read instance
    do 
        printf "$0: Terminating ${lab} instance $instance \n"
        ec2-terminate-instances --region $REGION $instance
        if [[ $? = 0 ]]; then
            printf "done\n"
        else
            printf "failed!!\n"
        fi
    done < $INSTANCE_FILE 
else
    printf "$O: $INSTANCE_FILE not found, no ${lab} class? Please check \n"
fi

# remove files and directories associated with nametag
FILELIST="${SCRIPTDIR}/$NAMETAG.hosts ${SCRIPTDIR}/$NAMETAG.out ${SCRIPTDIR}/$NAMETAG.out"
DIRLIST="${SCRIPTDIR}/${OUTDIR}"

for ifile in ${FILELIST}; do
    if [[ -f $ifile ]]; then
        printf "$0: Deleting $ifile ..."
        rm -f $ifile
        printf "$? \n"
    fi
done
for idir in ${DIRLIST}; do
    if [[ -d $idir ]]; then
        printf "$0: Deleting $idir ..."
        rm -rf $idir
        printf "$? \n"
    fi
done

exit 0
