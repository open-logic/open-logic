#!/bin/bash
#set -e

# Variables
if [ -z "$1" ]; then
    echo "Usage: $0 <ami-image-id> <instance-type>"
    exit 1
fi
if [ -z "$2" ]; then
    echo "Usage: $0 <ami-image-id> <instance-type>"
    exit 1
fi

echo "Using image: $1"
AMI_ID="$1"
INSTANCE_TYPE="$2"
AVAILABILITY_ZONE="eu-central-1a"
ENI_QUESTA="eni-0ba2390c78b29ff3d"
ENI_GOWIN="eni-037106146f437262d"
ENI_MICROCHIP="eni-0e30091a452c7f74b"

# Check if ENI_QUESTA is already attached
ENI_STATUS=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_QUESTA --query 'NetworkInterfaces[0].Attachment.InstanceId' --output text)
if [ "$ENI_STATUS" != "None" ]; then
    echo "ENI Attached - instance seems running already. Quitting"
    sleep 5
    return 0
fi

# Create the instance with the first ENI as the primary network interface
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --placement AvailabilityZone=$AVAILABILITY_ZONE \
  --key-name olo-build-aws \
  --query 'Instances[0].InstanceId' \
  --network-interfaces "DeviceIndex=0,NetworkInterfaceId=$ENI_QUESTA" \
  --output text)

echo "Created instance: $INSTANCE_ID"

# Start the instance (should already be running, but ensure it)
aws ec2 start-instances --instance-ids $INSTANCE_ID

# Wait for 20 seconds to ensure the instance is ready to attach additional ENIs
echo "Waiting for the instance to be ready..."
sleep 30

# Attach the other ENIs
aws ec2 attach-network-interface --network-interface-id $ENI_GOWIN --instance-id $INSTANCE_ID --device-index 1
aws ec2 attach-network-interface --network-interface-id $ENI_MICROCHIP --instance-id $INSTANCE_ID --device-index 2

# Create CloudWatch alarm to terminate the instance if CPU utilization is < 5% for 3 consecutive 5-minute periods
aws cloudwatch put-metric-alarm \
    --alarm-name "Terminate-OnLowCPU" \
    --alarm-description "TErminate instance if CPU < 5% for 30 minutes" \
    --metric-name CPUUtilization \
    --namespace AWS/EC2 \
    --statistic Average \
    --period 300 \
    --evaluation-periods 6 \
    --threshold 5 \
    --comparison-operator LessThanThreshold \
    --dimensions Name=InstanceId,Value=$INSTANCE_ID \
    --alarm-actions arn:aws:automate:eu-central-1:ec2:terminate \
    --unit Percent

aws cloudwatch put-metric-alarm \
    --alarm-name "Notify-OnLowCPU" \
    --alarm-description "Notiify if instance if CPU < 5% for 30 minutes" \
    --metric-name CPUUtilization \
    --namespace AWS/EC2 \
    --statistic Average \
    --period 300 \
    --evaluation-periods 6 \
    --threshold 5 \
    --comparison-operator LessThanThreshold \
    --dimensions Name=InstanceId,Value=$INSTANCE_ID \
    --alarm-actions arn:aws:sns:eu-central-1:612153846898:OloShutdown \
    --unit Percent

# Create alarm to notify when the instance runs for more than 4 hours
aws cloudwatch put-metric-alarm \
    --alarm-name "Notify-RunningFor4h" \
    --alarm-description "Notify when instance has been running for more than 4 hours" \
    --metric-name StatusCheckFailed_System \
    --namespace AWS/EC2 \
    --statistic Minimum \
    --period 14400 \
    --evaluation-periods 1 \
    --threshold 1 \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --dimensions Name=InstanceId,Value=$INSTANCE_ID \
    --alarm-actions arn:aws:sns:eu-central-1:612153846898:OloOnForTooLong \

echo "Instance $INSTANCE_ID is running with ENIs attached."