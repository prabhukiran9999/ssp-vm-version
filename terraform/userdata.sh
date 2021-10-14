#! /bin/bash
sudo yum update -y
sudo amazon-linux-extras install ansible2 -y
sudo yum install git -y
cd /home/ssm-user/
git https://github.com/prabhukiran9999/ssp-vm-version.git /home/ssm-user/repos/
cd /home/ssm-user/repos/
ansible-playbook dev.yml


