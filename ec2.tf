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


# use data source to get all availability zones in region
data "aws_availability_zones" "available_zones" {}


# create default subnets if one does not exist
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]

  tags = {
    Name = "default subnet 1"
  }
}

resource "aws_default_subnet" "default_az2" {
  availability_zone = data.aws_availability_zones.available_zones.names[1]

  tags = {
    Name = "default subnet 2"
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


# launch the ec2 instances and install website
resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "ec2_terraform"
  user_data              = file("install_techmax.sh")

  tags = {
    Name = "techmax server 1"
  }
}

resource "aws_instance" "ec2_instance2" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_default_subnet.default_az2.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "ec2_terraform"
  user_data              = file("install_techmax.sh")

  tags = {
    Name = "techmax server 2"
  }
}


resource "aws_cloudwatch_metric_alarm" "myalarm2" {
  alarm_name          = "daeomo_alarm2"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "10"
  alarm_description   = "This alarm is triggered if CPU utilization is under 10% for 4 minutes."
  dimensions = {
      InstanceId = [
      aws_instance.ec2_instance.id,
      aws_instance.ec2_instance2.id,
    ]
  }

}


# Lambda function to trigger CodePipeline
resource "aws_lambda_function" "trigger_code_pipeline" {
  filename      = "lambda_function.zip"
  function_name = "trigger_code_pipeline"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_execution_role.arn
  source_code_hash = filebase64sha256("lambda_function.zip")

  environment {
    variables = {
      PIPELINE_NAME = "redployment1"
    }
  }
}

# IAM Role for Lambda function
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_execution_policy_attachment_lambda" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_execution_policy_attachment_codepipeline" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess"
}


resource "aws_lambda_permission" "allow_cloudwatch_invoke" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger_code_pipeline.function_name
  principal     = "lambda.alarms.cloudwatch.amazonaws.com"  # CloudWatch principal

  source_arn = "arn:aws:cloudwatch:us-east-1:730335578247:alarm:*"  # Modify as needed
}


# print the url of the server
output "ec2_public_ipv4_url" {
  value = join("", ["http://", aws_instance.ec2_instance.public_ip])
}
