provider "aws" {
  region = var.aws_region
}

/* Dynamo DB Table */
resource "aws_dynamodb_table" "ssp-greetings" {
  name      = "ssp-greetings-vm"
  hash_key  = "pid"
  range_key = "createdAt"

  billing_mode   = "PAY_PER_REQUEST"
  read_capacity  = 20
  write_capacity = 20
  attribute {
    name = "pid"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }
}
data "aws_alb" "main" {
  name = var.alb_name
}

# Redirect all traffic from the ALB to the target group
data "aws_alb_listener" "front_end" {
  load_balancer_arn = data.aws_alb.main.id
  port              = 443
}

resource "aws_alb_target_group" "app" {
  name                 = "sample-target-group-vm"
  port                 = var.app_port
  protocol             = "HTTP"
  vpc_id               = "vpc-018906cab60cf165b"
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    healthy_threshold   = "2"
    interval            = "5"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.health_check_path
    unhealthy_threshold = "2"
  }

  #tags = local.common_tags
}

resource "aws_lb_listener_rule" "host_based_weighted_routing" {
  listener_arn = data.aws_alb_listener.front_end.arn

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.app.arn
  }

  condition {
    host_header {
      values = [for sn in var.service_names : "${sn}.*"]
    }
  }
}

/* Auto Scaling & Launch Configuration */
module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 3.0"

  name = "asg-instances"

  # Launch configuration creation
  lc_name = "example-lc"
  image_id        = "ami-037c167242ac48a38"
  instance_type   = "t2.micro"
  security_groups = ["sg-03895fdd9a15adf6e"]
  iam_instance_profile = "ssp_profile"
  user_data = "${file("userdata.sh")}"
  

  # ebs_block_device = [
  #   {
  #     device_name           = "/dev/xvdz"
  #     volume_type           = "gp2"
  #     volume_size           = "50"
  #     delete_on_termination = true
  #   },
  # ]

  root_block_device = [
    {
      volume_size = "50"
      volume_type = "gp2"
    },
  ]

  # Auto scaling group creation
  asg_name                  = "example-asg"
  vpc_zone_identifier       = ["subnet-048e25be105ae01d3", "subnet-0896ff158c3ecdc53"]
  health_check_type         = "EC2"
  min_size                  = 0
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
  health_check_grace_period = 500
  target_group_arns         = [aws_alb_target_group.app.arn]
  
  #service_linked_role_arn= "arn:aws:iam::813318847992:role/asg_role"
  #target_group_arns         = [module.alb.target_group_arns[0]]

  tags = [
    {
      key                 = "Environment"
      value               = "dev"
      propagate_at_launch = true
    },
  ]
  
}

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.63.0"
    }
  }
}

resource "aws_iam_instance_profile" "ssp_profile" {
  name = "ssp_profile"
  role = aws_iam_role.ssp-db.name
}

resource "aws_iam_role" "ssp-db" {
  name = "ssp-db"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "db_ssp" {
  name        = "ssp_db"
  #path        = "/"
  description = "policy to give dybamodb permissions to ec2"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "dynamodb:PutItem",
                "dynamodb:DeleteItem",
                "dynamodb:GetItem",
                "dynamodb:Query",
                "dynamodb:UpdateItem",
                "dynamodb:UpdateTable"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "dynamodb:ListTables",
            "Resource": "*"
        },
        {
            "Action": [
                "kms:DescribeKey",
                "kms:GenerateDataKey*",
                "kms:Decrypt",
                "kms:Encrypt",
                "kms:ReEncrypt*"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": "kms:Decrypt",
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": "s3:GetEncryptionConfiguration",
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
         {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData",
                "ec2:DescribeVolumes",
                "ec2:DescribeTags",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams",
                "logs:DescribeLogGroups",
                "logs:CreateLogStream",
                "logs:CreateLogGroup"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter"
            ],
            "Resource": "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeAssociation",
                "ssm:GetDeployablePatchSnapshotForInstance",
                "ssm:GetDocument",
                "ssm:DescribeDocument",
                "ssm:GetManifest",
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:ListAssociations",
                "ssm:ListInstanceAssociations",
                "ssm:PutInventory",
                "ssm:PutComplianceItems",
                "ssm:PutConfigurePackageResult",
                "ssm:UpdateAssociationStatus",
                "ssm:UpdateInstanceAssociationStatus",
                "ssm:UpdateInstanceInformation"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2messages:AcknowledgeMessage",
                "ec2messages:DeleteMessage",
                "ec2messages:FailMessage",
                "ec2messages:GetEndpoint",
                "ec2messages:GetMessages",
                "ec2messages:SendReply"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ds:CreateComputer",
                "ds:DescribeDirectories"
            ],
            "Resource": "*"
        }

        
    ]
  })
}
resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.ssp-db.name
  policy_arn = aws_iam_policy.db_ssp.arn
  
}




