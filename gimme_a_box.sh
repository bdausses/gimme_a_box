#!/usr/bin/env bash
####################################################################
#
# Title:        gimme_a_box.sh
#
# Description:  This script will launch a self-destructing instance
#               at AWS.
####################################################################

# Check for jq
which jq >/dev/null 2>&1
if [ $? -ne 0 ]
  then
    echo "ERROR:  It appears that JQ is not installed on this system.  Please install it and re-run this program."
    exit 1
fi

# Check for aws cli
which aws >/dev/null 2>&1
if [ $? -ne 0 ]
  then
    echo "ERROR:  It appears that the AWS CLI is not installed on this system.  Please install it and re-run this program."
    exit 1
fi

# Check for timeout
which timeout >/dev/null 2>&1
if [ $? -ne 0 ]
  then
    echo "ERROR:  It appears that timeout (coreutils) is not installed on this system.  Please install it and re-run this program."
    exit 1
fi

# Set variables
TIMESTAMP=`date '+%Y%m%d.%H%M%S'`
SELF_DESTRUCT_TIME="117 min"
INSTANCE_TYPE="t3.medium"
AMI_SEARCH_TERM="chef-highperf*"
AMI_USER="centos"
KEY_NAME="aws_key_pair_name"

# Set tag variables
X_APPLICATION="NA-Central"
# NOTE: X-Contact must be an email address.  This is required per Chef tagging standards and will
# be expected below when generating the X-Name tag.
X_CONTACT="user@chef.io"
X_CUSTOMER="Testing"
X_DEPT="Sales"
X_PRODUCTION="No"
X_PROJECT="Testing"
X_ROLE="Testing"
X_SLEEP="false"
X_TTL="24"

# Generate X-Name Tag
CONTACT_SHORT_NAME=`echo ${X_CONTACT}|cut -d "@" -f1`
X_NAME="${CONTACT_SHORT_NAME}_testing_box_${TIMESTAMP}"

# Get the most recent AMI ID
AMI_ID=`aws ec2 describe-images --filters "Name=name,Values=${AMI_SEARCH_TERM}" --query 'sort_by(Images,&CreationDate)[-1].ImageId'|jq -r .`

# Launch instance
INSTANCE_ID=`aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-initiated-shutdown-behavior terminate \
  --instance-type ${INSTANCE_TYPE} \
  --key-name ${KEY_NAME} \
  --user-data "#!/bin/bash
               yum install -y at
               service atd start
               echo \"halt -p\" | at now + ${SELF_DESTRUCT_TIME}
               curl https://raw.githubusercontent.com/habitat-sh/habitat/master/components/hab/install.sh | bash
               hab license accept
               groupadd hab
               useradd -g hab hab
               cat <<EOF > /etc/systemd/system/hab-sup.service
[Unit]
Description=The Habitat Supervisor

[Service]
# Uncomment this to enable reporting in to Chef Automate
# Environment=HAB_FEAT_EVENT_STREAM=1
ExecStart=/bin/hab sup run
# Add these to the ExecStart to actually report the data into Chef Automate
# --event-stream-application=GimmeABox --event-stream-environment=POC_Env --event-stream-site=AWS --event-stream-url=bdausses-test-automate.chef-demo.com:4222 --event-stream-token=-RU-9_oS-BRYSzfwx_Wx_bbJ22Y=

[Install]
WantedBy=default.target
EOF
              systemctl start hab-sup.service
" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${X_NAME}},
                                                    {Key=X-Dept,Value=${X_DEPT}},
                                                    {Key=X-Application,Value=${X_APPLICATION}},
                                                    {Key=X-Customer,Value=${X_CUSTOMER}},
                                                    {Key=X-Project,Value=${X_PROJECT}},
                                                    {Key=X-Contact,Value=${X_CONTACT}},
                                                    {Key=X-TTL,Value=${X_TTL}},
                                                    {Key=X-Production,Value=${X_PRODUCTION}},
                                                    {Key=X-Role,Value=${X_ROLE}},
                                                    {Key=X-Sleep,Value=${X_SLEEP}}]"|jq -r .Instances[].InstanceId`

INSTANCE_IP_ADDRESS=`aws ec2 describe-instances --instance-ids ${INSTANCE_ID}|jq -r .Reservations[].Instances[].PublicIpAddress`

# Print details
echo
cat ~/.aws/config|grep ^region
echo "Instance ID:  ${INSTANCE_ID}"
echo "IP Address:   ${INSTANCE_IP_ADDRESS}"
echo
echo "Waiting for instance to become available..."

# Wait for and report on instance's ready state
INSTANCE_AVAILABLE=no
while [ "${INSTANCE_AVAILABLE}" != "yes" ]; do
  timeout 2 bash -c "</dev/tcp/${INSTANCE_IP_ADDRESS}/22" > /dev/null 2>&1
  if [ "$?" = "0" ]; then
    INSTANCE_AVAILABLE="yes"
    echo "Instance is ready.  Starting ssh session..."
    echo
    sleep 2
  fi
done

# Start SSH Session
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${AMI_USER}@${INSTANCE_IP_ADDRESS}
