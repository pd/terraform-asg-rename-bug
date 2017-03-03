Demo of `ignore_changes = [name]` + ASG tag changes causing terraform to
repeatedly clobber existing tag values.

```
$ terraform version
Terraform v0.8.7
```

Ensure AWS credentials are available to terraform (ie, set `$AWS_PROFILE`),
and set `$AWS_REGION` to whatever makes sense for you. I use `us-east-1`
below.

## step 1, ref `initial`

terraform will create a single AWS autoscaling group, named `asg-rename-bug`
(with size zero, so you will not have to pay for actual instances):

```
$ terraform apply
aws_launch_configuration.lc: Creating...
  associate_public_ip_address: "" => "false"
  ebs_block_device.#:          "" => "<computed>"
  ebs_optimized:               "" => "<computed>"
  enable_monitoring:           "" => "true"
  image_id:                    "" => "ami-da04d5cc"
  instance_type:               "" => "t2.medium"
  key_name:                    "" => "<computed>"
  name:                        "" => "<computed>"
  name_prefix:                 "" => "asg-rename-bug-poc-"
  root_block_device.#:         "" => "<computed>"
aws_launch_configuration.lc: Creation complete
aws_autoscaling_group.asg: Creating...
  arn:                                "" => "<computed>"
  availability_zones.#:               "" => "1"
  availability_zones.986537655:       "" => "us-east-1c"
  default_cooldown:                   "" => "<computed>"
  desired_capacity:                   "" => "0"
  force_delete:                       "" => "false"
  health_check_grace_period:          "" => "300"
  health_check_type:                  "" => "<computed>"
  launch_configuration:               "" => "asg-rename-bug-poc-00d6ed0a44a26ce4a3fc27f416"
  load_balancers.#:                   "" => "<computed>"
  max_size:                           "" => "0"
  metrics_granularity:                "" => "1Minute"
  min_size:                           "" => "0"
  name:                               "" => "asg-rename-bug"
  protect_from_scale_in:              "" => "false"
  tag.#:                              "" => "1"
  tag.4080504499.key:                 "" => "original"
  tag.4080504499.propagate_at_launch: "" => "true"
  tag.4080504499.value:               "" => "tag-value"
  vpc_zone_identifier.#:              "" => "<computed>"
  wait_for_capacity_timeout:          "" => "10m"
aws_autoscaling_group.asg: Creation complete

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

Using awscli, we can see the tags set on the ASG:

```
$ aws autoscaling describe-tags --filters Name=auto-scaling-group,Values=asg-rename-bug
{
    "Tags": [
        {
            "ResourceType": "auto-scaling-group",
            "ResourceId": "asg-rename-bug",
            "PropagateAtLaunch": true,
            "Value": "tag-value",
            "Key": "original"
        }
    ]
}
```
