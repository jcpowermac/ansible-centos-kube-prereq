#!/bin/bash

set -x

virtmach=(kube-master1 kube-node1 kube-node2)

wget -N https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2 -O /instances/images/centos.qcow2

for vm in ${virtmach[@]}
do
cp /instances/images/centos.qcow2 /instances/$vm.qcow2
qemu-img resize /instances/$vm.qcow2 +32G
qemu-img create -f qcow2 /nvme/$vm-overlay.qcow2 32G

virt-install --import --name $vm \
	--memory 8192 \
	--vcpus 2 \
	--disk path="/instances/$vm.qcow2,format=qcow2,bus=virtio" --disk path="/nvme/$vm-overlay.qcow2,format=qcow2,bus=virtio" \
	--network network=ovsbr0,portgroup=vlan-250 \
	--graphics none \
	--console pty,target_type=serial \
	--os-type linux \
	--os-variant centos7.0 \
	--noautoconsole
sleep 60
virsh shutdown $vm
sleep 30
virt-sysprep -d $vm \
	--firstboot-command 'yum erase -y cloud-init;yum install -y wget git net-tools bind-utils iptables-services bridge-utils bash-completion kexec-tools sos psacct;yum update -y' \
	--hostname $vm.virtomation.com \
	--root-password password: \
	--network

# nested virtual machine
virt-xml $vm --edit --cpu host-passthrough,require=svm
virsh start $vm
sleep 90
ip=`virsh qemu-agent-command $vm '{"execute":"guest-network-get-interfaces"}' | jq '.return[1]["ip-addresses"][0]["ip-address"]'`


temp="${ip%\"}"
temp="${temp#\"}"


echo "$vm ansible_host=$temp" >> hosts.ini

done
