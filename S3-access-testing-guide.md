# S3 Access Testing Guide

This guide provides step-by-step instructions for testing S3 access across different EC2 instances in our VPC architecture and demonstrates the benefits of using an S3 Gateway Endpoint.

## Prerequisites

- The CloudFormation stack or Terraform deployment has been successfully completed
- You have access to the AWS Management Console
- Basic familiarity with AWS CLI commands

## 1. Connect to EC2 Instances

1. **Navigate to EC2 Console**:
   - Open the AWS Management Console
   - Go to EC2 service

2. **Connect to Each Instance**:
   - Connect to each instance using EC2 Instance Connect:
     - Public Instance
     - Private Instance with NAT
     - Isolated Private Instance
   - For private instances, make sure to use the EC2 Instance Connect Endpoint

## 2. Test Initial S3 Access (No Instance Profile)

Run the following command on each instance:

```bash
aws s3 ls
```

**Expected Result**: All instances should fail with an access denied error since no instance profile with S3 permissions is attached.

## 3. Attach S3 Read Access Role to Instances

1. **Navigate to EC2 Console**:
   - Go to EC2 service
   - Select "Instances"

2. **For Each Instance**:
   - Select the instance
   - Click "Actions"
   - Select "Security" > "Modify IAM role"
   - From the dropdown, select the role named `[stack-name]-S3ReadAccessRole` or the instance profile `[stack-name]-S3ReadAccessProfile`
   - Click "Update IAM role"

3. **Verify Role Attachment**:
   - Check the instance details to confirm the role is attached

4. **Optional: Reboot Instances**:
   - If S3 access doesn't work immediately, reboot the instances:
     - Select each instance
     - Click "Instance state" > "Reboot instance"

## 4. Test S3 Access After Role Attachment

Run the following command on each instance:

```bash
aws s3 ls
```

**Expected Results**:
- Public Instance: Success (via Internet Gateway)
- Private Instance with NAT: Success (via NAT Gateway)
- Isolated Private Instance: Failure (no internet access)

## 5. Create Test S3 Buckets

1. **Navigate to S3 Console**:
   - Go to S3 service

2. **Create First Bucket in Current Region**:
   - Click "Create bucket"
   - Enter a unique bucket name: `vpc-demo-[your-account-id]-[current-region]`
   - Select the same region as your VPC
   - Keep default settings
   - Click "Create bucket"

3. **Create Second Bucket in Different Region**:
   - Click "Create bucket"
   - Enter a unique bucket name: `vpc-demo-[your-account-id]-[different-region]`
   - Select a different region than your VPC
   - Keep default settings
   - Click "Create bucket"

## 6. Upload Test Files to Buckets

1. **For Each Bucket**:
   - Open the bucket
   - Click "Upload"
   - Click "Add files" and select a small text file
   - Click "Upload"

2. **Note the File Names**:
   - Remember the file names for testing

## 7. Test S3 Object Access

Run the following command on the public and private-with-NAT instances:

```bash
# For same-region bucket
aws s3api get-object --bucket vpc-demo-[your-account-id]-[current-region] --key [filename] /tmp/downloaded-file-1

# For different-region bucket
aws s3api get-object --bucket vpc-demo-[your-account-id]-[different-region] --key [filename] /tmp/downloaded-file-2
```

**Expected Results**:
- Public Instance: Success for both buckets
- Private Instance with NAT: Success for both buckets
- Isolated Private Instance: Failure for both buckets (no internet access)

## 8. Understanding NAT Gateway Limitations for S3 Access

While the private instance with NAT can access S3, this approach has several drawbacks:

- **Cost**: All S3 traffic goes through the NAT Gateway, incurring additional charges
- **Bandwidth**: NAT Gateway can become a bottleneck for high-volume S3 operations
- **Availability**: If the NAT Gateway fails, S3 access is lost
- **Security**: Traffic leaves the AWS network and re-enters, potentially exposing it to threats

## 9. S3 Gateway Endpoint Overview

**Purpose**:
- Provide private connectivity to S3 without using the internet
- Allow instances in private subnets to access S3 without NAT Gateway

**Benefits**:
- **Cost Reduction**: No NAT Gateway charges for S3 traffic
- **Security**: Traffic stays within AWS network
- **Performance**: Potentially better throughput
- **Availability**: Higher availability than NAT Gateway

**Restrictions**:
- Only works for S3 buckets in the same region as the VPC
- Only supports S3 service (separate endpoints needed for other services)
- Uses route tables rather than DNS (unlike Interface Endpoints)

## 10. Create an S3 Gateway Endpoint

1. **Navigate to VPC Console**:
   - Go to VPC service
   - Select "Endpoints" in the left navigation

2. **Create Endpoint**:
   - Click "Create Endpoint"
   - Select "AWS services" for Service category
   - Search for "S3" and select the Gateway type endpoint (com.amazonaws.[region].s3)
   - Select your VPC

3. **Configure Route Tables**:
   - Select both private route tables:
     - private-rt-1-with-nat
     - private-rt-2-no-internet
   - Click "Create endpoint"

4. **Verify Endpoint Creation**:
   - Check that the endpoint status becomes "Available"
   - Verify route tables have been updated with a route to the S3 prefix list

## 11. Test S3 Access with Gateway Endpoint

Run the following commands on all instances:

```bash
# For same-region bucket
aws s3api get-object --bucket vpc-demo-[your-account-id]-[current-region] --key [filename] /tmp/downloaded-file-1

# For different-region bucket
aws s3api get-object --bucket vpc-demo-[your-account-id]-[different-region] --key [filename] /tmp/downloaded-file-2
```

**Expected Results**:
- Public Instance: Success for both buckets (via Internet Gateway)
- Private Instance with NAT: 
  - Success for same-region bucket (via S3 Gateway Endpoint)
  - Success for different-region bucket (via NAT Gateway)
- Isolated Private Instance:
  - Success for same-region bucket (via S3 Gateway Endpoint)
  - Failure for different-region bucket (no internet access)

## 12. Conclusion

This demonstration shows:

1. **Role-Based Access**: How IAM roles provide S3 permissions to EC2 instances
2. **Network Path Matters**: How network connectivity affects S3 access
3. **S3 Gateway Endpoint Benefits**:
   - Enables S3 access for isolated instances with no internet connectivity
   - Reduces costs by bypassing NAT Gateway for S3 traffic
   - Improves security by keeping traffic within AWS network
4. **Regional Limitations**: Gateway endpoints only work for same-region resources

These concepts are fundamental to designing secure, cost-effective AWS architectures.

## 13. Clean Up

1. **Empty and Delete S3 Buckets**:
   - Navigate to each bucket
   - Select all objects and delete them
   - Go back to S3 dashboard
   - Select each bucket and click "Delete"
   - Confirm deletion by typing the bucket name

2. **Delete S3 Gateway Endpoint**:
   - Go to VPC > Endpoints
   - Select the S3 endpoint
   - Click "Actions" > "Delete VPC endpoints"
   - Confirm deletion

3. **Remove IAM Roles from Instances** (optional):
   - Go to EC2 > Instances
   - For each instance, select "Actions" > "Security" > "Modify IAM role"
   - Select "No IAM role" from dropdown
   - Click "Update IAM role"

4. **Delete CloudFormation Stack or Terraform Deployment**:
   - This will remove all resources created by the template

## Additional Tips

- **Troubleshooting**: If S3 access doesn't work as expected, check:
  - IAM role permissions
  - Route table entries
  - Security group rules
  - VPC endpoint policy (if customized)

- **Performance Testing**: For production workloads, consider testing S3 transfer speeds with and without the Gateway Endpoint

- **Cost Analysis**: Monitor your AWS Cost Explorer to see the reduction in NAT Gateway costs after implementing the S3 Gateway Endpoint