provider "aws" {
    region = "eu-west-1"
}

terraform {
    backend "s3" {
        bucket         = "${s3_bucket}"
        key            = "terraform.tfstate"
        region         = "eu-west-1"
        dynamodb_table = "${DynamoDB_table}"
        encrypt        = true
  }
}

module "vpc" {
    source   = "terraform-aws-modules/vpc/aws"
    name    = "TechnicalTask-VPC"

    cidr    = "10.0.0.0/16"
    azs             = ["eu-west-1a"]
    private_subnets = ["10.0.1.0/24"]
    public_subnets  = ["10.0.101.0/24"]

    enable_nat_gateway = true
    single_nat_gateway = true
    one_nat_gateway_per_az = false

    public_subnet_tags = var.common_tags
    tags = var.common_tags
    vpc_tags = var.common_tags
}

resource "aws_key_pair" "JumpHost_key" {
    key_name   = "JumpHost-key"
    public_key = "${file("JumpHost_key.pub")}"
}

resource "aws_key_pair" "NginxContainer_key" {
    key_name   = "NginxContainer-key"
    public_key = "${file("NginxContainer_key.pub")}"
}

resource "aws_elb" "Technical_Task_elb" {
    name               = "Technical-Task-elb"
    subnets            = flatten(module.vpc.public_subnets)

    listener {
        instance_port       = 80
        instance_protocol   = "http"
        lb_port             = 80
        lb_protocol         = "http"
        }
    
    health_check {
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 3
        target              = "HTTP:80/"
        interval            = 30
        }
        
    instances                   = [aws_instance.docker_instance.id]
    cross_zone_load_balancing   = false
    idle_timeout                = 400
    connection_draining         = true
    connection_draining_timeout = 400
    security_groups             = [aws_security_group.SG_elb.id]

    tags                        = var.common_tags
}

data "aws_ami" "latest_centos_ami" {
    owners      = ["125523088429"]
    most_recent = true
    filter {
        name   = "name"
        values = ["CentOS 8*x86_64"]
    }
}

resource "aws_instance" "jump_host" {
    ami                    = data.aws_ami.latest_centos_ami.id
    instance_type          = var.Jump_host_type
    vpc_security_group_ids = [aws_security_group.SG_jump_host.id]
    key_name               = "JumpHost-key"
    subnet_id              = flatten(module.vpc.public_subnets)[0]
    tags                   = merge(var.common_tags, { Name = "${var.Name_of_Jump_host}"})
    depends_on             = [aws_key_pair.JumpHost_key]
    }

resource "aws_instance" "docker_instance" {
    ami                    = data.aws_ami.latest_centos_ami.id
    instance_type          = var.Docker_host_type
    vpc_security_group_ids = [aws_security_group.docker_instance.id]
    key_name               = "NginxContainer-key"
    subnet_id              = flatten(module.vpc.private_subnets)[0]
    tags                   = merge(var.common_tags, { Name = "${var.Docker_with_Nginx_container}"})
    depends_on             = [aws_key_pair.NginxContainer_key, module.vpc]
    user_data              = <<EOF
#!/bin/bash
yum -y install  python36.x86_64
EOF

    provisioner "remote-exec" {
        inline = ["echo 'Waiting for server to be initialized...'"]

    connection {
        type              = "ssh"
        agent             = false
        host              = self.private_ip
        user              = "centos"
        private_key       = "${file("NginxContainer_key")}"
        bastion_host      = aws_instance.jump_host.public_ip
      bastion_private_key = "${file("JumpHost_key")}"
    }
  }
 
    provisioner "local-exec" {
        command = "ansible-playbook -i ${self.private_ip}, --ssh-common-args ' -o StrictHostKeyChecking=no -o ProxyCommand=\"ssh -o StrictHostKeyChecking=no -A -W %h:%p -q centos@${aws_instance.jump_host.public_ip} -i JumpHost_key\"' -u centos --private-key NginxContainer_key main.yml"
        }
    }

resource "aws_security_group" "SG_jump_host" {
    name = "SG_for_Jump_host"
    description = "Security Group for Jump host"
    vpc_id = module.vpc.vpc_id
    
    dynamic "ingress" {
        for_each = var.ssh_access_to_jump_host
        content {
            from_port   = 22
            to_port     = 22
            protocol    = "tcp"
            cidr_blocks = var.ssh_access_to_jump_host
        }
    }
    
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

  tags = var.common_tags
}

resource "aws_security_group" "SG_elb" {
    name = "SG_for_ELB"
    description = "Security Group for ELB"
    vpc_id = module.vpc.vpc_id

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

  tags = var.common_tags
}

resource "aws_security_group" "docker_instance" {
    name = "SG_for_Docker_instance"
    description = "Security Group for Docker instance"
    vpc_id = module.vpc.vpc_id

    ingress {
        from_port         = 80
        to_port           = 80
        protocol          = "tcp"
        security_groups   = [aws_security_group.SG_elb.id]
    }
    
        ingress {
        from_port         = 22
        to_port           = 22
        protocol          = "tcp"
        security_groups   = [aws_security_group.SG_jump_host.id]
    }

    egress {
        from_port         = 0
        to_port           = 0
        protocol          = "-1"
        cidr_blocks       = ["0.0.0.0/0"]
    }

  tags = var.common_tags
}
