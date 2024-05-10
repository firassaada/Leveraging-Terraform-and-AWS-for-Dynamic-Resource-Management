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


# Create a load balancer
resource "aws_lb" "my_lb" {
  name               = "my-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ec2_security_group.id]
  subnets            = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]

  tags = {
    Name = "My Load Balancer"
  }
}

# Create a listener for the load balancer
resource "aws_lb_listener" "my_lb_listener" {
  load_balancer_arn = aws_lb.my_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}

# Create a target group for the load balancer
resource "aws_lb_target_group" "my_target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_default_vpc.default_vpc.id

  health_check {
    protocol = "HTTP"
    port     = 80
    path     = "/"
    timeout  = 5
  }
}

# Register EC2 instances with the target group
resource "aws_lb_target_group_attachment" "instance_attachment1" {
  target_group_arn = aws_lb_target_group.my_target_group.arn
  target_id        = aws_instance.ec2_instance.id
}

resource "aws_lb_target_group_attachment" "instance_attachment2" {
  target_group_arn = aws_lb_target_group.my_target_group.arn
  target_id        = aws_instance.ec2_instance2.id
}



resource "aws_cloudwatch_metric_alarm" "http_request_alarm" {
  alarm_name          = "daeomo_alarm2"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "HttpRequestCount"   # Name of the metric related to HTTP requests
  namespace           = "AWS/EC2"
  period              =  "60" # 5 minutes (adjust as per your requirements)
  statistic           = "Sum"
  threshold           = "10"# Example threshold for triggering the alarm
  alarm_description   = "Alarm triggered if HTTP request count below 10 in 1 minute."
  
  dimensions = {
    InstanceId = aws_instance.ec2_instance.id
  }

 alarm_actions = [ "arn:aws:lambda:us-east-1:730335578247:function:${aws_lambda_function.trigger_code_pipeline2.function_name}" ]

}



# Lambda function to trigger CodePipeline
resource "aws_lambda_function" "trigger_code_pipeline2" {
  filename      = "lambda_function.zip"
  function_name = "trigger_code_pipeline2"
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
  function_name = aws_lambda_function.trigger_code_pipeline2.function_name
  principal     = "lambda.alarms.cloudwatch.amazonaws.com"  # CloudWatch principal

  source_arn = "arn:aws:cloudwatch:us-east-1:730335578247:alarm:*"  # Modify as needed
}


# print the url of the server
output "ec2_public_ipv4_url" {
  value = join("", ["http://", aws_instance.ec2_instance.public_ip])
}
