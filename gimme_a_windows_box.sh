#!/usr/bin/env bash
####################################################################
#
# Title:        gimme_a_box.sh
#
# Description:  This script will launch a self-destructing instance
#               at AWS.
####################################################################


# Set variables
TIMESTAMP=`date '+%Y%m%d.%H%M%S'`
SELF_DESTRUCT_TIME="6600" # 110 Minutes, in seconds.
INSTANCE_TYPE="m5.large"
RDP_HEIGHT=1300
RDP_WIDTH=2400

# Check for jq
which jq >/dev/null 2>&1
if [ $? -ne 0 ]
  then
    echo "ERROR:  It appears that JQ is not installed on this system.  Please install it and re-run this program."
    exit 1
fi

# Launch instance
INSTANCE_ID=`aws ec2 run-instances \
  --image-id $(aws ssm get-parameters --names /aws/service/ami-windows-latest/Windows_Server-2016-English-Full-Base --query 'Parameters[0].[Value]' --output text) \
  --count 1 \
  --instance-initiated-shutdown-behavior terminate \
  --instance-type ${INSTANCE_TYPE} \
  --key-name bdausses_sa \
  --user-data "<script>
               shutdown -s -t ${SELF_DESTRUCT_TIME}
               echo Current date and time >> %SystemRoot%\Temp\test.log
               echo %DATE% %TIME% >> %SystemRoot%\Temp\test.log
               </script>" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=bdausses_testing_box_${TIMESTAMP}},
                                                    {Key=X-Dept,Value=Sales},
                                                    {Key=X-Application,Value=NA-Central},
                                                    {Key=X-Customer,Value=Test},
                                                    {Key=X-Project,Value=Test},
                                                    {Key=X-Contact,Value=bdausses},
                                                    {Key=X-TTL,Value=2},
                                                    {Key=X-Production,Value=No},
                                                    {Key=X-Role,Value=test_box},
                                                    {Key=X-Sleep,Value=true}]"|jq -r .Instances[].InstanceId`

INSTANCE_IP_ADDRESS=`aws ec2 describe-instances --instance-ids ${INSTANCE_ID}|jq -r .Reservations[].Instances[].PublicIpAddress`

# Print details
echo
cat ~/.aws/config|grep ^region
echo "Instance ID:  ${INSTANCE_ID}"
echo "IP Address:   ${INSTANCE_IP_ADDRESS}"
echo

secs=60
while [ $secs -gt 0 ]; do
   echo -ne "Waiting $secs seconds for instance to become available...\033[0K\r"
   sleep 1
   : $((secs--))
done
echo
echo

INSTANCE_AVAILABLE=no
while [ "${INSTANCE_AVAILABLE}" != "yes" ]; do
  echo -n "Attempting to get admin password...  "
  INSTANCE_PASSWORD=`aws ec2 get-password-data --instance-id ${INSTANCE_ID} --priv-launch-key ~/.ssh/id_rsa|jq -r .PasswordData`
  if [ "$INSTANCE_PASSWORD" = "" ]; then
    echo "Password still not available."
    sleep 5
  else
    INSTANCE_AVAILABLE="yes"
    echo "Password retrieved."
    echo
    echo "Username:  Administrator"
    echo "Password:  ${INSTANCE_PASSWORD}"
  fi
done

echo
echo "Starting RDP session..."
open "rdp://full%20address=s:${INSTANCE_IP_ADDRESS}:3389&username=s:administrator&audiomode=i:2&disable%20themes=i:1&screen%20mode%20id=i:1&desktopwidth=i:${RDP_WIDTH}&desktopheight=i:${RDP_HEIGHT}"
