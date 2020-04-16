#!/bin/bash

# Обновляем и устанавливаем софт.
apt --assume-yes update
apt --assume-yes upgrade
apt --assume-yes install ruby-full ruby-bundler build-essential wget git python-apt python-pip unzip

# Обновляем pip.
pip install --upgrade pip

# Ставим ansible.
apt --assume-yes install ansible

# Переменные среды окружения с актуальными версиями terraform и packer.
export VER_TERRAFORM="0.12.24"
export VER_PACKER="1.5.5"

# Качаем terraform и packer.
wget https://releases.hashicorp.com/terraform/${VER_TERRAFORM}/terraform_${VER_TERRAFORM}_linux_amd64.zip	
wget https://releases.hashicorp.com/packer/${VER_PACKER}/packer_${VER_PACKER}_linux_amd64.zip

# Распаковываем terraform и packer.
unzip terraform_${VER_TERRAFORM}_linux_amd64.zip
unzip packer_${VER_PACKER}_linux_amd64.zip

# Ставим terraform и packer.
mv terraform /usr/local/bin/
mv packer /usr/local/bin/

# Линкуем terraform и packer.
which terraform
which packer

# Проверка версии софта.
git --version
terraform -v
packer -v
ansible --version
