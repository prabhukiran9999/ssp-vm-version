#! /bin/bash
sudo yum update -y
sudo amazon-linux-extras install ansible2 -y
sudo yum install git -y
cd /home/ssm-user/
git clone https://github.com/prabhukiran9999/ansible.git /home/ssm-user/playbook/
cd /home/ssm-user/playbook/
ansible-playbook dev.yml


