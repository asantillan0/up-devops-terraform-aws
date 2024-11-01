locals {
  name   = "up-devops"
  region = "eu-east-1"
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.14.0"

  name = "${local.name}-vpc"

  cidr           = "10.0.0.0/16"
  public_subnets = ["10.0.1.0/24"]

  azs = ["us-east-1a"]
}

################################################################################
# Security Groups
################################################################################

module "sg_ec2" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  name        = "${local.name}-sg-ec2"
  description = "Security Group for EC2"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = "0"
      to_port     = "0"
      protocol    = "-1"
      description = "ingress-all-alan"
      cidr_blocks = "179.60.208.62/32"
    }
  ]
  egress_with_cidr_blocks = [
    {
      from_port   = "0"
      to_port     = "0"
      protocol    = "-1"
      description = "egress-all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

################################################################################
# EC2 Instance
################################################################################

module "ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name = "${local.name}-ec2"

  instance_type               = "t2.micro"
  monitoring                  = false
  vpc_security_group_ids      = [module.sg_ec2.security_group_id]
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  create_iam_instance_profile = true
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    AmazonSSMReadOnlyAccess      = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess",
    ECRAccess                    = "arn:aws:iam::563935605077:policy/ecr-permissions-up-devops",
    CodeDeployAccess             = "arn:aws:iam::563935605077:policy/CodeDeployAccess"
  }
  user_data = <<-EOF
    #!/bin/bash
    
    # Update the package index
    sudo yum update -y
    
    # Install Docker
    sudo yum install -y docker
    
    # Start the Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Retrieve the New Relic API key from Parameter Store
    NEW_RELIC_API_KEY=$(aws ssm get-parameter --name "new-relic-linux" --with-decryption --query "Parameter.Value" --output text --region us-east-1)
    
    # Install New Relic using the retrieved API key
    curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash
    sudo NEW_RELIC_API_KEY=$NEW_RELIC_API_KEY NEW_RELIC_ACCOUNT_ID=3510195 /usr/local/bin/newrelic install
  
    # Pull the Docker image from ECR
    aws ecr get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin 563935605077.dkr.ecr.us-east-1.amazonaws.com
    
    # Pull the image
    sudo docker pull 563935605077.dkr.ecr.us-east-1.amazonaws.com/up-devops-webapp:develop
    
    # Run the Docker container
    sudo docker run -d -p 3000:3000 --name up_devops_backend 563935605077.dkr.ecr.us-east-1.amazonaws.com/up-devops-webapp:develop
  EOF
}