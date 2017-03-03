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

## step 2, ref `rename`

We want to run multiple copies of the ASG, maybe one for a test environment, one
for production, but the name is too generic. We add a variable `env` and embed it
in the ASG name to disambiguate. Unfortunately, ASGs can not be directly renamed,
and we don't want to destroy and recreate the existing one, so we configure the
resource's lifecycle to ignore changes to `name`. This works as expected -- there
are no changes when applied to the existing tfstate:

```
$ terraform plan -var env=test
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but
will not be persisted to local or remote state storage.

aws_launch_configuration.lc: Refreshing state... (ID: asg-rename-bug-poc-00d6ed0a44a26ce4a3fc27f416)
aws_autoscaling_group.asg: Refreshing state... (ID: asg-rename-bug)

No changes. Infrastructure is up-to-date. This means that Terraform
could not detect any differences between your configuration and
the real physical resources that exist. As a result, Terraform
doesn't need to do anything.
```

## step 3, ref `tag`

Modify the tags on the ASG. In this case, we add a tag to store the environment.

```
$ terraform plan -var env=test
~ aws_autoscaling_group.asg
    tag.#:                            "1" => "2"
    tag.20478519.key:                 "" => "env"
    tag.20478519.propagate_at_launch: "" => "true"
    tag.20478519.value:               "" => "test"


Plan: 0 to add, 1 to change, 0 to destroy.
```

It's not immediately obvious, but this plan actually shows that the existing
tag will be removed, and the new one added, despite the `tag.#` value.
`apply` and look at the ASG tags again:

```
$ terraform apply -var env=test
aws_launch_configuration.lc: Refreshing state... (ID: asg-rename-bug-poc-00d6ed0a44a26ce4a3fc27f416)
aws_autoscaling_group.asg: Refreshing state... (ID: asg-rename-bug)
aws_autoscaling_group.asg: Modifying...
  tag.#:                            "1" => "2"
  tag.20478519.key:                 "" => "env"
  tag.20478519.propagate_at_launch: "" => "true"
  tag.20478519.value:               "" => "test"
aws_autoscaling_group.asg: Modifications complete

Apply complete! Resources: 0 added, 1 changed, 0 destroyed.

$ aws autoscaling describe-tags --filters Name=auto-scaling-group,Values=asg-rename-bug
{
    "Tags": [
        {
            "ResourceType": "auto-scaling-group",
            "ResourceId": "asg-rename-bug",
            "PropagateAtLaunch": true,
            "Value": "test",
            "Key": "env"
        }
    ]
}
```

The `original` tag is gone. Re-plan:

```
$ terraform plan -var env=test
~ aws_autoscaling_group.asg
    tag.#:                              "1" => "2"
    tag.4080504499.key:                 "" => "original"
    tag.4080504499.propagate_at_launch: "" => "true"
    tag.4080504499.value:               "" => "tag-value"


Plan: 0 to add, 1 to change, 0 to destroy.
```

This cycle will now repeat forever, just swapping the tags out for each other.
