#!/bin/bash
# This script launches multiple nodes to be used for installing MapR
#
# This script assumes the environment variables EC2_CERT and EC2_PRIVATE_KEY are set.
#
#
# TODO: Add option to specify VPC amd subnet!!
#
# check usage
if [ $# -ne 10 ] 
   then
      printf "Usage: $0 <nametag> <numinstances> <ami_id> <region> <zone> <secgroup> <keyfile> <instance_type> <number of EBS volumes> <volume size (GB)>\n"
      printf "Example: ./launch_aws_nodes.sh test 1 ami-10f0c30d eu-central-1 eu-central-1b default patric-1 m3.large 3 50 \n"
      exit 1
fi

NAMETAG=$1
NUMINSTANCES=$2
AMI_ID=$3
REGION=$4
ZONE=$5
SECGROUP=$6
KEYFILE=$7
INSTANCE_TYPE=$8
let NUM_DISKS=$9
let DISK_GB=${10}

let MAX_DISKS=25
OUTDIR=output/${NAMETAG}
# is set in node_init_script.sh:
#export MAPR_VERSION=5.0.0

if (( $NUM_DISKS > ${MAX_DISKS} || $NUM_DISKS < 0 )); then
    printf "$0: Valid range for number of disks is 0 - ${MAX_DISKS}, exiting. \n"
    exit 2
fi

printf "\n"
printf "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n"
printf "Start timestamp for the launch_installnodes script "`date '+%Y-%m-%d %H:%M:%S'`
printf "Start timestamp for the launch_installnodes script $(date '+%Y-%m-%d %H:%M:%S')"
printf "\n"
if [ -d "$OUTDIR" -o -f "$OUTDIR" ]
then
   printf "$OUTDIR exists -- exiting this script!\n"
   printf "please either delete $OUTDIR and rerun, or use another name tag\n"
   exit 3
fi
 
# create base directory for all subsidiary files and outputs
mkdir $OUTDIR
if [[ $? != 0 ]]; then
    printf "$0: Could not create dir $OUTDIR, exiting \n"
    exit 4
fi

# Don't mess with these variables much
#NODE_INIT_SCRIPT='node_init_script.sh'
NODE_INIT_SCRIPT='node_init_script_new.sh'
FILENAME_RUN=${OUTDIR}/._instance_run.out
FILENAME_INSTANCES1=${OUTDIR}/._instance_ids_b4_verificatn
FILENAME_INSTANCES2=${OUTDIR}/._instance_ids
FILENAME_DETAILS=${OUTDIR}/._instance_details
FILENAME_INT=${OUTDIR}/hostnames-int
FILENAME_EXT=${OUTDIR}/hostnames-ext
FILENAME_HTML=${OUTDIR}/hostnames.html
FILENAME_HOSTS_INT=${OUTDIR}/hosts.internal
FILENAME_HOSTS_EXT=${OUTDIR}/hosts.external

######### This is the start of the LAUNCH method.  
#
# And now for the code...
#

printf "\n "
printf "Start timestamp for the LAUNCH method $(date '+%Y-%m-%d %H:%M:%S')"
printf "\n"
printf `ls -1a $OUTDIR`
printf "\n"

printf "Launching $NUMINSTANCES instances...\n"

ec2-run-instances --region $REGION -g $SECGROUP -k $KEYFILE -n $NUMINSTANCES -t $INSTANCE_TYPE -z $ZONE --user-data-file $NODE_INIT_SCRIPT $AMI_ID > $FILENAME_RUN

grep INSTANCE $FILENAME_RUN | cut -f 2 > $FILENAME_INSTANCES1

printf $(cat $FILENAME_INSTANCES1)
printf "\n"

printf "There are $(cat $FILENAME_INSTANCES1 | wc -l ) instances launched\n"
printf "End timestamp for the LAUNCH method $(date '+%Y-%m-%d %H:%M:%S')"
printf "\n"
printf "\n"
#
#
#
########### This is the end of the LAUNCH method


########### This is the start of the VERIFY method
#
#  This  method is intended to verify that all launched nodes are in fact
#  running.  
#
printf "\n"
printf "Start timestamp for the VERIFY method $(date '+%Y-%m-%d %H:%M:%S')"
printf "\n"

for i in `cat $FILENAME_INSTANCES1`
do 
   # verify that the instance is in running state or is self-terminating

   VERIFY_WAITING_COUNT=0

   while [ `ec2-describe-instances --region $REGION | grep $i | egrep -c 'running|term'` -eq 0 ];do
        let VERIFY_WAITING_COUNT=(VERIFY_WAITING_COUNT+1)
        printf "VERIFY method timer count for this instance is " $VERIFY_WAITING_COUNT 
        printf "\n"
        printf "Waiting for instance " $i " to spin up ...\n"
        # if while loop gets stuck in an infinite loop, cancel out after 6 mintues on one instance
        printf "$VERIFY_WAITING_COUNT \n"

        if [ "$VERIFY_WAITING_COUNT" -gt 30 ] ;
          then 
              printf "Exiting with exit value 2 given that VERIFY method is stuck in a loop\n"
              exit 5
        fi
      sleep 12 
   done
 
   # Now that the instance is up, test the instance status to see if it is terminating or running

   if [ `ec2-describe-instances --region $REGION | grep $i | grep -c termin` -ne 0 ] ; then   
      printf "This is another example of an instance self-terminating right after being launched\n"
      printf "This is the instance that was self-terminating " $i
      printf "\n"
   fi 

   # If the instance is running then append name to the bottom of the FILENAME_INSTANCES2 list

   if [ `ec2-describe-instances --region $REGION | grep $i | grep -c running` -ne 0 ] ; then 
      `echo $i >> $FILENAME_INSTANCES2`
      echo "This instance was running " $i
   fi

done

printf "There are $(cat $FILENAME_INSTANCES2 | wc -l) instances verified as running \n"

printf "End timestamp for the LAUNCH method $(date '+%Y-%m-%d %H:%M:%S')"
printf "\n"

#
#
############ This is the end of the VERIFY method


########## This is the start of the TAG method
#
#  In this method we tag each instance and then we create 
#  and attach $NUM_DISKS volumes for each instance
#
printf "\n"
printf "This is the start timestamp for the TAG method $(date '+%Y-%m-%d %H:%M:%S')"
printf "\n"
printf "Instance IDs saved to ${FILENAME_INSTANCES2}. Now applying tags to each instance...\n"

hostNum=0
for i in `cat $FILENAME_INSTANCES2`
do 
   # wait for instance to be in running state -- based on previous
   # VERIFY method they should all be in a running state
   TAG_WAITING_COUNT=0
   while [ `ec2-describe-instances --region $REGION | grep $i | grep -c running` -eq 0 ]
   do
      let TAG_WAITING_COUNT=(TAG_WAITING_COUNT+1)
      printf "This is where the count is for this instance" $TAG_WAITING_COUNT 
      printf "\n"
      printf "waiting for instance $i to spin up ..."
      sleep 10 

      # if while loop gets stuck in an infinite loop, cancel out after 5 mintues on one instance
      if $TAG_WAITING_COUNT -gt 30 ;
      then 
         printf "Exiting with value of 3 given that TAG method is stuck in a loop\n"
         exit 6
      fi
   done 
   ec2-create-tags $i --tag Name=${NAMETAG} --region $REGION

   let idisk=1
   while (( $idisk <= $NUM_DISKS ))
   do
      # convert idisk to b,c,d,... for proper disk names:
      # 97=ASCII offset for character "a"
      let tmp=97+idisk
      disk=$(printf "\x$(printf %x $tmp)")
      printf "Creating volume sd$disk\n"
      ec2-create-volume --size $DISK_GB --region $REGION --availability-zone $ZONE --type standard > /tmp/myout$disk
      VOLID=`awk '{print $2}' /tmp/myout$disk`
      # check for $MAXCOUNT*sleep seconds until volume state is "ok"
      sleep 10
      let count=1
      let MAXCOUNT=10
      VOLSTATUS=$(ec2-describe-volume-status --region $REGION $VOLID | head -n 1| awk '{print $4}')
      while [[ $VOLSTATUS != "ok" ]]
      do
        sleep 10
        let count=count+1
        VOLSTATUS=$(ec2-describe-volume-status --region $REGION $VOLID | head -n 1| awk '{print $4}')
        if (( $count >= $MAXCOUNT ))
        then
          printf "EBS volume $VOLID failed to create, bailing out."
          printf "Make sure to delete instances.\n"
          exit 10
        fi
      done
      printf "volume id $VOLID created\n"

      printf "Attaching volume sd${disk}\n"
      ec2-attach-volume $VOLID --instance $i --device /dev/sd$disk --region $REGION 
      printf "Modifying volume sd${disk}\n"
      ec2-modify-instance-attribute --region $REGION  $i -b "/dev/sd${disk}=:true"
      let idisk=idisk+1
   done
done

printf "This is the end timestamp for the TAG method" `date '+%Y-%m-%d %H:%M:%S'`
printf "\n"
#
#
#
######## End of TAG method


printf "Looking up internal & external hostnames for all instances...\n"
ec2-describe-instances --region $REGION --filter "tag:Name=${NAMETAG}" > $FILENAME_DETAILS

printf "Storing results to '$FILENAME_INT' & '$FILENAME_EXT':\n"
grep INSTANCE $FILENAME_DETAILS | cut -f 4 > $FILENAME_EXT
grep INSTANCE $FILENAME_DETAILS | cut -f 5 > $FILENAME_INT

#echo "<table>" > $FILENAME_HTML
#echo "<tr><td>External IP</td><td>Internal Hostid</td></tr>\n" >> $FILENAME_HTML 
#cut -f 4,2 -d " " $FILENAME_DETAILS > tmp.txt; printf "<tr><td>%s</td><td>%s</td></tr>\n" $(cat "tmp.txt") >> $FILENAME_HTML
#echo "</table>" >> $FILENAME_HTML
#rm tmp.txt

# create external hosts file 
hostNum=0
while read line 
do 
   instance=`echo $line | grep INSTANCE | grep running` 
   if [ -n "$instance" ] 
   then
      pubIp=`echo $instance | awk '{print $14}'`
      privIp=`echo $instance | awk '{print $15}'`
      hostName=`echo $instance | awk '{print $5}' | cut -d. -f1`
      aliasName=${NAMETAG}-${hostNum}
      echo "$pubIp $hostName $aliasName" >> $FILENAME_HOSTS_EXT
      echo "$privIp $hostName $aliasName" >> $FILENAME_HOSTS_INT
      ((hostNum=$hostNum+1))
   fi
done < $FILENAME_DETAILS 


printf "\n"
printf "$0: This is the end timestamp of the launch install nodes script "`date '+%Y-%m-%d %H:%M:%S %Z'`
printf "\n"
printf "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n"
printf "\n"

exit 0
