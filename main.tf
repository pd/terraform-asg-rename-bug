variable "az" {
  default = "us-east-1c"
}

resource "aws_launch_configuration" "lc" {
  name_prefix   = "asg-rename-bug-poc-"
  image_id      = "ami-da04d5cc"
  instance_type = "t2.medium"
}

resource "aws_autoscaling_group" "asg" {
  name                 = "asg-rename-bug"
  launch_configuration = "${aws_launch_configuration.lc.name}"
  availability_zones   = ["${var.az}"]

  min_size         = 0
  max_size         = 0
  desired_capacity = 0

  tag {
    key                 = "original"
    value               = "tag-value"
    propagate_at_launch = true
  }
}
