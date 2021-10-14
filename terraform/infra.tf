
/* Dynamo DB Table */
resource "aws_dynamodb_table" "ssp-greetings" {
  name      = "ssp-greetings-vm"
  hash_key  = "pid"
  range_key = "id"

  billing_mode   = "PAY_PER_REQUEST"
  read_capacity  = 5
  write_capacity = 5
  attribute {
    name = "pid"
    type = "S"
  }
  attribute {
    name = "id"
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

  image_id        = "ami-0a70476e631caa6d3"
  instance_type   = "t2.micro"
  security_groups = ["sg-03895fdd9a15adf6e"]
  #associate_public_ip_address = true
  #key_name = "ssp-instance"
  #user_data = "${file("userdata.sh")}"
  

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






