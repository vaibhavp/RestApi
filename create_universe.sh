#!/bin/bash

###############################################################################
#
# This script configures a list of nodes and creates a universe.
#
# Usage:
#   create_universe.sh <rf> <config ips> <ssh ips> <ssh user> <ssh-key file>
#       <config ips> : space separated set of ips the nodes should use to talk to
#                      each other
#       <ssh ips>    : space separated set of ips used to ssh to the nodes in
#                      order to configure them
#
###############################################################################


# Get the name of the cloud
CLOUD_NAME=$1

# Get the region name
REGION=$2

# Get the replication factor.
RF=$3
echo "Replication factor: $RF"

# Get the list of nodes (ips) used for intra-cluster communication.
NODES=$4
echo "Creating universe with nodes: [$NODES]"

# Get the list of ips to ssh to the corresponding nodes.
SSH_IPS=$5
echo "Connecting to nodes with ips: [$SSH_IPS]"

# Get the list of AZs for the nodes.
ZONES=$6

# Get the credentials to connect to the nodes.
SSH_USER=$7
SSH_KEY_PATH=$8

YB_HOME=/home/ec2-user/yugabyte-db
YB_MASTER_ADDRESSES=""

zone_array=($ZONES)
num_zones=`(IFS=$'\n';sort <<< "${zone_array[*]}") | uniq -c | wc -l`
SSH_IPS_array=($SSH_IPS)

idx=0
node_num=0
master_ips=""
###############################################################################
# Pick the masters as per the replication factor.
###############################################################################
declare -a ZONE_MAP

for node in $NODES
do
  if (( $num_zones > 1 )); then
     z_found=0
     for zname in ${ZONE_MAP[@]}
     do
         if [ "${zname}" == "${zone_array[$node_num]}" ]; then
            z_found=1
         fi
     done
     if [ $z_found -eq 0 ]; then
        if (( $idx < RF )); then
           ZONE_MAP[$idx]=${zone_array[$node_num]}
  	   if [ ! -z $YB_MASTER_ADDRESSES ]; then
  	      YB_MASTER_ADDRESSES="$YB_MASTER_ADDRESSES,"
  	   fi
           YB_MASTER_ADDRESSES="$YB_MASTER_ADDRESSES$node:7100"
           SSH_MASTER_IPS="$SSH_MASTER_IPS ${SSH_IPS_array[$node_num]}"
           master_ips="$master_ips $node"
           idx=`expr $idx + 1`
        fi
     fi
  else
     if (( $idx < $RF )); then
  	if [ ! -z $YB_MASTER_ADDRESSES ]; then
  	  YB_MASTER_ADDRESSES="$YB_MASTER_ADDRESSES,"
  	fi
        YB_MASTER_ADDRESSES="$YB_MASTER_ADDRESSES$node:7100"
        SSH_MASTER_IPS="$SSH_MASTER_IPS ${SSH_IPS_array[$idx]}"
        master_ips="$master_ips $node"
        idx=`expr $idx + 1`
     fi
  fi
  node_num=`expr $node_num + 1`;
done

# Error out if we do not have sufficient nodes.
if (( $idx < $RF )); then
  echo "Error: insufficient nodes - got $idx node(s) but rf = $RF"
  exit 1
fi
echo "Master addresses: $YB_MASTER_ADDRESSES"
MASTER_ADDR_ARRAY=($master_ips)

# Error out if number of AZ's is not 1 but not equal to RF
if (( $num_zones > 1 )); then
   if (( $num_zones < $RF )); then
      echo "Error insufficient AZ's for master placement - must be equal to $RF"
      exit 1
   else
      echo "Multi AZ placement detected. Nodes in ${zone_array[@]}"
   fi
else
   echo "Single AZ placement detected - all nodes in ${zone_array[0]}"
fi

###############################################################################
# Setup master addresses across all the nodes.
###############################################################################
echo "Finalizing configuration..."
echo "--master_addresses=${YB_MASTER_ADDRESSES}" >> ${YB_HOME}/master/conf/server.conf
echo "--tserver_master_addrs=${YB_MASTER_ADDRESSES}" >> ${YB_HOME}/tserver/conf/server.conf
echo "--replication_factor=${RF}" >> ${YB_HOME}/master/conf/server.conf
echo "--replication_factor=${RF}" >> ${YB_HOME}/tserver/conf/server.conf

###############################################################################
# Setup placement information if multi-AZ
###############################################################################

echo "Adding placement flag information ... number of zones = ${num_zones}"

echo "--placement_cloud=${CLOUD_NAME}" >> ${YB_HOME}/master/conf/server.conf
echo "--placement_cloud=${CLOUD_NAME}" >> ${YB_HOME}/tserver/conf/server.conf
echo "--placement_region=${REGION}" >> ${YB_HOME}/master/conf/server.conf
echo "--placement_region=${REGION}" >> ${YB_HOME}/tserver/conf/server.conf
if [ $num_zones -eq  1 ]; then
   echo "--placement_zone=${zone_array[0]}" >> ${YB_HOME}/master/conf/server.conf
   echo "--placement_zone=${zone_array[0]}" >> ${YB_HOME}/tserver/conf/server.conf
fi

idx=0
for node in $SSH_IPS
do
  if [ $num_zones -gt 1 ]; then
     echo "--placement_zone=${zone_array[idx]}" >> ${YB_HOME}/master/conf/server.conf
     echo "--placement_zone=${zone_array[idx]}" >> ${YB_HOME}/tserver/conf/server.conf
  fi
  idx=`expr $idx + 1`
done

###############################################################################
# Setup YSQL proxies across all nodes
###############################################################################
echo "Enabling YSQL..."
echo '--start_pgsql_proxy' >> ${YB_HOME}/tserver/conf/server.conf
idx=0
echo "--pgsql_proxy_bind_address=${MASTER_ADDR_ARRAY[idx]}:5433" >> ${YB_HOME}/tserver/conf/server.conf


###############################################################################
# Start the masters.
###############################################################################
echo "Starting masters..."
MASTER_EXE=${YB_HOME}/master/bin/yb-master
MASTER_OUT=${YB_HOME}/master/master.out
MASTER_ERR=${YB_HOME}/master/master.err
nohup ${MASTER_EXE} --flagfile ${YB_HOME}/master/conf/server.conf >>${MASTER_OUT} 2>>${MASTER_ERR} </dev/null &
  MASTER_CRON_OK="##";
  MASTER_CRON_OK+=`crontab -l`;
  MASTER_CRON_PATTERN="start_master.sh"
  if [[ "$MASTER_CRON_OK" == *${MASTER_CRON_PATTERN}* ]]; then
    echo "Found master crontab entry at [$node]"
  else
    crontab -l | { cat; echo "*/3 * * * * /home/ec2-user/start_master.sh > /dev/null 2>&1"; } | crontab - 
    echo "Created master crontab entry at [$node]"
  fi



###############################################################################
# Start the tservers.
###############################################################################
echo "Starting tservers..."
echo "--tserver_master_addrs=${YB_MASTER_ADDRESSES}" >> ${YB_HOME}/tserver/conf/server.conf
echo "export YB_MASTER_ADDRESSES=${YB_MASTER_ADDRESSES}" >> ${YB_HOME}/.yb_env.sh
TSERVER_EXE=${YB_HOME}/tserver/bin/yb-tserver
TSERVER_OUT=${YB_HOME}/tserver/tserver.out
TSERVER_ERR=${YB_HOME}/tserver/tserver.err

echo "Setting LANG and LC_* environment variables on all nodes"
echo -e 'export LC_ALL=en_US.utf-8 \nexport LANG=en_US.utf-8' > ~/env 
sudo mv ~/env /etc/environment
sudo chown root:root /etc/environment
sudo chmod 0644 /etc/environment
nohup ${TSERVER_EXE} --flagfile ${YB_HOME}/tserver/conf/server.conf >>${TSERVER_OUT} 2>>${TSERVER_ERR} </dev/null &

  TSERVER_CRON_OK="##";
  TSERVER_CRON_OK+=`ssh -o "StrictHostKeyChecking no" -i ${SSH_KEY_PATH} ${SSH_USER}@$node 'crontab -l'`;
  TSERVER_CRON_PATTERN="start_tserver.sh"
  if [[ "$TSERVER_CRON_OK" == *${TSERVER_CRON_PATTERN}* ]]; then
     echo "Found tserver crontab entry at [$node]"
  else
     crontab -l | { cat; echo "*/3 * * * * /home/ec2-user/start_tserver.sh > /dev/null 2>&1"; } | crontab - 
     echo "Created tserver crontab entry at [$node]"
  fi


