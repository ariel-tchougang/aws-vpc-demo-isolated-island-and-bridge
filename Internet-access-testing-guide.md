# Internet Access Testing Guide

This guide provides step-by-step instructions for testing the network connectivity in our VPC architecture with public, private, and isolated subnets.

## Prerequisites

- The CloudFormation stack or Terraform deployment has been successfully completed
- You have access to the AWS Management Console
- Your IP address is included in the `PingCidr` parameter if you want to ping instances from your local machine

## Testing Scenarios

### 1. Connect to EC2 Instances Using EC2 Instance Connect

1. **Navigate to EC2 Console**:
   - Open the AWS Management Console
   - Go to EC2 service

2. **Connect to Public Instance**:
   - Select the instance named "public-instance"
   - Click "Connect"
   - Choose "EC2 Instance Connect" tab
   - Click "Connect"

3. **Connect to Private Instance with NAT**:
   - Select the instance named "private-instance-with-nat"
   - Click "Connect"
   - Choose "EC2 Instance Connect" tab
   - Select "EC2 Instance Connect Endpoint" from the dropdown
   - Click "Connect"

4. **Connect to Isolated Private Instance**:
   - Select the instance named "isolated-private-instance"
   - Click "Connect"
   - Choose "EC2 Instance Connect" tab
   - Select "EC2 Instance Connect Endpoint" from the dropdown
   - Click "Connect"

### 2. Test Connectivity Between EC2 Instances

1. **Get Private IPs**:
   - In the EC2 Console, note the **private IP addresses** of all three instances
   - Let's call them:
     - `PUBLIC_INST_PRIVATE_IP` for public-instance
     - `INST_WITH_NAT_PRIVATE_IP` for private-instance-with-nat
     - `ISOLATED_INST_PRIVATE_IP` for isolated-private-instance

2. **Test Ping Between Instances**:
   - From Public Instance terminal:
     ```bash
     ping -c 4 INST_WITH_NAT_PRIVATE_IP  # Should succeed
     ping -c 4 ISOLATED_INST_PRIVATE_IP  # Should succeed
     ```
   
   - From Private Instance with NAT terminal:
     ```bash
     ping -c 4 PUBLIC_INST_PRIVATE_IP    # Should succeed
     ping -c 4 ISOLATED_INST_PRIVATE_IP  # Should succeed
     ```
   
   - From Isolated Private Instance terminal:
     ```bash
     ping -c 4 PUBLIC_INST_PRIVATE_IP    # Should succeed
     ping -c 4 INST_WITH_NAT_PRIVATE_IP  # Should succeed
     ```

### 3. Test Internet Access from Public Instance

1. **From Public Instance terminal**:
   ```bash
   ping -c 4 www.amazon.com  # Should succeed
   ```

2. **Verify DNS Resolution**:
   ```bash
   nslookup www.amazon.com  # Should return IP addresses
   ```

### 4. Test Internet Access from Private Instance with NAT

1. **From Private Instance with NAT terminal**:
   ```bash
   ping -c 4 www.amazon.com  # Should succeed
   ```
   ```

2. **Verify DNS Resolution**:
   ```bash
   nslookup www.amazon.com  # Should return IP addresses
   ```

3. **Test Public Instance IP Access**:
   ```bash
   ping -c 4 PUBLIC_EXTERNAL_IP  # Should fail due to security group rules
   ```
   Note: Replace `PUBLIC_EXTERNAL_IP` with the public IP of your public instance

### 5. Test Internet Access from Isolated Private Instance

1. **From Isolated Private Instance terminal**:
   ```bash
   ping -c 4 www.amazon.com  # Should fail - no internet access
   ```

2. **Verify DNS Resolution**:
   ```bash
   nslookup www.amazon.com  # Should fail - no internet access
   ```


3. **Test Public Instance IP Access**:
   ```bash
   ping -c 4 PUBLIC_EXTERNAL_IP  # Should fail due to no internet access + security group rules
   ```

## Understanding the Results

- **Successful pings between instances**: Demonstrates that the security groups allow ICMP traffic within the VPC
- **Public instance internet access**: Shows direct internet connectivity via Internet Gateway
- **Private instance with NAT internet access**: Shows outbound-only internet connectivity via NAT Gateway
- **Isolated instance no internet access**: Confirms the "isolated island" concept with no outbound internet route
- **Failed pings to public IP**: Shows security group restrictions for inbound traffic

## Troubleshooting

If tests don't produce expected results:

1. **Check Security Groups**:
   - Verify ICMP is allowed between instances within the VPC
   - Confirm SSH access is properly configured

2. **Check Route Tables**:
   - Public subnet should have a route to Internet Gateway
   - Private subnet 1 should have a route to NAT Gateway
   - Private subnet 2 should have no internet route

3. **Verify EC2 Instance Connect Endpoint**:
   - Ensure it's in the correct subnet
   - Check its security group allows outbound SSH to VPC CIDR