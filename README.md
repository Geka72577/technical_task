## About
The repository consists two Terraform configurations and one Ansible Playbook. The main purpose of which is to prepare infrastructure according technical specifications.

First Terraform configuration is located in "Terraform_Provision_Storing_State" directory and creates following resourses:
- aws S3 buket (for remote storing state file);
- aws DynamoDB table (for keeping lock state in Dynamo DB).

Second Terraform configuration is located in "Terraform-Ansible" directory and creates the next resources:
- aws VPC ( 2 Subnets - private and public, One Internet GW, One Nat GW, via VPC module - https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest); 
- aws 2 EC2 VMs (Nginx container in private subnet and Jump host in public subnet);
- aws Load Balancer;
- aws 2 Key Pairs;
- aws 3 Security Groups.

Ansible playbook will be invoked directly from second Terrafom configuration. Playbook is located in "Terraform-Ansible" directory and installs Docker Engine, CLI, and Containerd packages, and running Nginx container on EC2 instance in a private subnet. 

## Requirements
- installed Terraform (Checked on version 15);
- installed Ansible (Checked on version 2.5.1);
- installed git;
- installed ssh-keygen package;
- API access to aws account (with access to provision the above resources);

## Usage

1. Clone project to local PC:
```
git clone https://github.com/Geka72577/technical_task.git
```
2. Set your AWS credentials as the environment variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.
```
export AWS_ACCESS_KEY_ID="xxxxxxxxxxxxxxxxx"
export AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxxx"
```
3. cd into first Terraform configuration - "technical_task/Terraform_Provision_Storing_State"
4. Specify name of S3 bucket and name of DynamoDB table in main.tf file for storing terraform state in the next variables:
```
resource "aws_s3_bucket" "terraform_state" {
    bucket = "${s3_bucket}"
    versioning {
      enabled = true
    }

    lifecycle {
      prevent_destroy = true
    }
}

  resource "aws_dynamodb_table" "terraform_state_lock" {
    name           = "${DynamoDB_name}"
    read_capacity  = 1
    write_capacity = 1
    hash_key       = "LockID"

    attribute {
      name = "LockID"
      type = "S"
```
where, *${s3_bucket}* - name of S3 bucket for storing terraform state;
       *${DynamoDB_name}* - name of DynamoDB table for storing lock state.

5. Run terraform init.
6. Run terraform apply.
7. After it's done deploying, S3 bucket and DynamoDB table was created.
8. cd into second Terraform configuration - *technical_task/Terraform-Ansible*.
9. Generate SSH keys:
- For public subnet:
```
ssh-keygen -f JumpHost_key
```
- For private subnet:
```
ssh-keygen -f NginxContainer_key
```
10. In main.tf file, under *backend "s3"* specify the name of S3 bucket and name of Dynamo DB table(the same as was specified in 4 item):
```
   backend "s3" {
        bucket         = "${s3_bucket}"
        key            = "terraform.tfstate"
        region         = "eu-west-1"
        dynamodb_table = "${DynamoDB_name}"
        encrypt        = true
  }
```
11. Run terraform init.
12. Run terraform  apply.
13. After deploying, the terraform will output LB URL.
14. Nginx Welcome page should be displayed by Load Balancer URL.
15. Issue next command to destroy infrastracture.
```
terraform destroy
```
