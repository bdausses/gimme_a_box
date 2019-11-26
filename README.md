# Gimme A Box!
Have you ever needed to just spin up an EC2 instance, super quick and dirty to test out a thing?  Of course you have.  I personally despise having to log into a GUI to do something like that... I also got sick of pulling the last `aws ec2` command out of my command history.  I just want Amazon to `gimme_a_box` ASAP, and with as little fuss as possible!  Additionally, I want some sort of mechanism to prevent costs from racking up in the case that I forget to terminate the instance.  Thus, `gimme_a_box.sh` was created.  This script will give you an EC2 instance as quickly as possible and dump you right into the interface.  Additionally, the instances are set to self-destruct in 2 hours if you forget to terminate them.

*NOTE:  This was originally written and intended for use on Mac, so YMMV if you're on a different platform.*  
*NOTE 2:  PRs welcome!*

## Should you really be using this?
It should be noted that the use case here is for something super quick and dirty that you're not really going to care about in very short amount of time.  If what you are doing needs to be repeatable, or is more integrated than just a single box for testing purposes, you should probably be using Terraform.

## Requirements
If you've found this tool, you likely already have the prereqs, but for documentation completeness:

- `jq` - [https://stedolan.github.io/jq/](https://stedolan.github.io/jq/)
- `awscli` - [https://aws.amazon.com/cli/](https://aws.amazon.com/cli/)
- `timeout` - included in GNU coreutils: [https://github.com/coreutils/coreutils/](https://github.com/coreutils/coreutils/)
- Mac users with homebrew installed can get all 3 with `brew install jq awscli coreutils`.

You also need Remote Desktop if you're going to RDP to a Windows instance:
- Remote Desktop - https://apps.apple.com/us/app/microsoft-remote-desktop-10/id1295203466?mt=12

Additionally, you should have the AWS CLI tool set up so that you can issue `aws` commands without being prompted for credentials.  Generic instructions here:  [https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)

## Usage
NOTE:  To be able to connect to the instance, the default security group in the VPC you're spinning up in has to have 22/3389 open for ssh/RDP.  This script doesn't do anything with security groups (and ideally shouldn't... that bleeds in to the Terraform comment above).

### Linux
Start the instance and connect just by calling the script:
```
[brad@brads_mbp ~]$ gimme_a_box.sh                                                                                               

region = us-east-2
Instance ID:  i-07e61009b19971354
IP Address:   3.133.101.242

Waiting for instance to become available...
Instance is ready.  Starting ssh session...

Warning: Permanently added '3.133.101.242' (ECDSA) to the list of known hosts.
Last login: Mon Oct  7 23:28:02 2019 from c-73-37-119-155.hsd1.or.comcast.net
[centos@ip-172-31-17-192 ~]$
```
The instances are started with `--instance-initiated-shutdown-behavior terminate`, so when you're done, you can just do a `sudo halt -p`, `sudo init 0`,  or whatever you normally use to power off a machine.  Once you power it off, it'll terminate the instance at EC2.  If you forget to do this, the instance will self destruct via a `halt -p` command that gets scheduled with `user-data` as the instance was started.

### Windows
Start the instance and open Remote Desktop just by calling the script:
```
[brad@brads_mbp ~]$ gimme_a_box.sh                                                                                               

region = us-east-2
Instance ID:  i-08d9459443992843d
IP Address:   18.224.15.50

Waiting 1 seconds for instance to become available...

Attempting to get admin password...  Password still not available.
Attempting to get admin password...  Password still not available.
Attempting to get admin password...  Password retrieved.

Username:  Administrator
Password:  <PASSWORD GETS DISPLAYED HERE>

Starting RDP session...
```

## To-Dos
- Integrate the Linux and Windows scripts into one script
- Command line option to spin up the box, but not auto-start the SSH or RDP sessions?
- Allow for command line options to be able to specify different search terms for the AMI to be used
    - Potential Problems
        - `atd` is installed (or ensured to be installed) via `user-data` at launch time.  Different distros need different pkg management calls to do this.
        - Different AMIs have different default usernames.
- Figure out a better way to do passwords on Windows system.

## License
This is licensed under [the Apache 2.0 license](https://www.apache.org/licenses/LICENSE-2.0).
