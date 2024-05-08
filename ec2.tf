# configured aws provider with proper credentials
provider "aws" {
  region  = "us-east-1"
  profile = "ssh_admin_user"
}


# store the terraform state file in s3
terraform {
  backend "s3" {
    bucket  = "aosnote-terraform-state-bucket-firas"
    key     = "build/terraform.tfstate"
    region  = "us-east-1"
    profile = "ssh_admin_user"
  }
}


# create default vpc if one does not exit
resource "aws_default_vpc" "default_vpc" {

  tags = {
    Name = "default vpc"
  }
}


# use data source to get all avalablility zones in region
data "aws_availability_zones" "available_zones" {}


# create default subnet if one does not exit
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]

  tags = {
    Name = "default subnet"
  }
}


# create security group for the ec2 instance
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2 security group"
  description = "allow access on ports 80 and 22"
  vpc_id      = aws_default_vpc.default_vpc.id

  ingress {
    description = "http access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2 security group"
  }
}


# use data source to get a registered amazon linux 2 ami
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}


# launch the ec2 instance and install website
resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "ec2_terraform"
  user_data              = file("install_techmax.sh")

  tags = {
    Name = "techmax server"
  }
}
resource "aws_cloudwatch_metric_alarm" "myalarm" {
  alarm_name          = "daeomo_alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "10"
  alarm_description   = "This alarm is triggered if CPU utilization is under 10% for 4 minutes."
  dimensions = {
    InstanceId = aws_instance.ec2_instance.id
  }

  alarm_actions = ["arn:aws:automate:us-east-1:ec2:stop"]
}

resource "aws_cloudwatch_event_rule" "trigger_deployment_rule" {
  name        = "trigger_deployment_rule"
  description = "Trigger CodePipeline execution on CloudWatch Alarm state change"
  event_pattern = <<PATTERN
{
  "source": ["aws.cloudwatch"],
  "detail-type": ["CloudWatch Alarm State Change"],
  "detail": {
    "state": ["ALARM"],
    "alarmName": ["${aws_cloudwatch_metric_alarm.myalarm.alarm_name}"]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "trigger_deployment_target" {
  rule      = aws_cloudwatch_event_rule.trigger_deployment_rule.name
  target_id = "trigger-deployment-target"
  arn       = "arn:aws:codepipeline:us-east-1:730335578247:pipeline/redployment1"
}

# print the url of the server
output "ec2_public_ipv4_url" {
  value = join("", ["http://", aws_instance.ec2_instance.public_ip])
}
