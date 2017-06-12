df -h
setenforce 0

systemctl stop NetworkManager.service 
systemctl disable NetworkManager.service
killall -STOP NetworkManager

mkdir -p /openshift
yum install ca-certificates dnsmasq git nfs-utils -y
curl -o openshift.tar.gz -L https://github.com/openshift/origin/releases/download/v1.5.0/openshift-origin-server-v1.5.0-031cbe4-linux-64bit.tar.gz 
tar -xvf openshift.tar.gz
rm openshift.tar.gz
mv openshift-origin-server-v1.5.0-031cbe4-linux-64bit/ /var/lib/openshift/

curl -o oc.tar.gz -L https://github.com/openshift/origin/releases/download/v1.5.0/openshift-origin-client-tools-v1.5.0-031cbe4-linux-64bit.tar.gz
tar -xvf oc.tar.gz
rm oc.tar.gz

mv openshift-origin-client-tools-v1.5.0-031cbe4-linux-64bit/oc /usr/local/bin/oc
rm -rf ~/*


cat <<-EOF > /etc/systemd/system/origin.service
[Unit]
Description=OpenShift
After=docker.target network.target
[Service]
Type=notify
Environment=KUBECONFIG=/openshift.local.config/master/admin.kubeconfig
Environment=CURL_CA_BUNDLE=/openshift.local.config/master/ca.crt
ExecStart=/var/lib/openshift/openshift start --master-config=/openshift.local.config/master/master-config.yaml --node-config=/openshift.local.config/node-%H/node-config.yaml --dns=tcp://0.0.0.0:8053
[Install]
WantedBy=multi-user.target
EOF
systemctl enable origin

# copy ssh key
mkdir -p ~/.ssh
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCqogWTBOZvsLcz7Zxz7i4+Z00WA01Y+xpNsvUiC6bkB8F4PhuVkKMn+ww7F/UtLcQ9qO6U1K8f5FpkDmeQQLvV7uYCnG7X63ia+njPgF8euF5rpWvmjG5Zz/6gLGf8+wFNC4yXyjU7G7Vce59/JdbaPUdOmA3aL2WKMxoea/IDOTEAORFcyMLNNJdy0yYNxLfEl7w3IY12po/cPb2VKeqJqi3UqwJroDYjCOt5fS4Fp0tvzvbiXP8+nbhd0uTTEkgtl3/FU0ozQBAHgO6UlbSV1sJEIjZG+543FtRfV0tbmUyT7+N0NGOZYJ3FQ1B/MrP6H8O/8YhiaQDLwkL5zhxPqW9cyAZw207uZbM26ohfCQUMmFoYJ9fBA/dt7aXbw5rb0lihFYZMq94NUi3ABLDBEsT9J5+mJomdlUHDwHxztcjO8JnThP5iBcYmNiqAnhbn71Avr8Zz1vHVP0TFC8f40NnK/A7nwTQw0aQ+H0u+EGrx+2gVmSUlwQyDDUlHJpEI0IefWtdmBqYvMyfVDf8SGSolkcXUJxX63iCFEyPMyMLUWLbPcwRhlUn6G6NVDI6sLwfveeXFJppuSMx+Wqc3ZmyEHIj/mVuEuygVke3Bd4/v8e4o6adR93yF/Fuq0Q0bMhgf2xCwVFSaqlta/o5m0wMNwCO3NuDLCZjIFj3+vw== course@katacoda.com' >> ~/.ssh/authorized_keys

touch ~/.hushlogin
echo 'echo "Starting OpenShift"' >> ~/.launch.sh
echo 'echo "Waiting for OpenShift to start... This may take a couple of moments"' >> ~/.launch.sh
echo 'until $(oc status &> /dev/null); do' >> ~/.launch.sh
echo '  sleep 1' >> ~/.launch.sh
echo 'done' >> ~/.launch.sh
echo 'echo "OpenShift started. "' >> ~/.launch.sh
echo 'echo -n "Configuring... "' >> ~/.launch.sh
echo 'for i in {1..10}; do oc adm registry -n default --config=/openshift.local.config/master/admin.kubeconfig > /dev/null 2>&1 && break || sleep 1; done' >> ~/.launch.sh
echo 'for i in {1..10}; do oc adm policy add-scc-to-user hostnetwork -z router > /dev/null 2>&1 && break || sleep 1; done' >> ~/.launch.sh
echo 'for i in {1..10}; do oc adm router > /dev/null 2>&1 && break || sleep 1; done' >> ~/.launch.sh
echo 'until $(oc get svc router &> /dev/null); do' >> ~/.launch.sh
  echo 'sleep 1' >> ~/.launch.sh
echo 'done' >> ~/.launch.sh
echo 'oc create -f /openshift/image-streams-centos7.json --namespace=openshift > /dev/null' >> ~/.launch.sh
echo 'echo "OpenShift Ready"' >> ~/.launch.sh

chmod +x ~/.launch.sh

echo 'echo 127.0.0.1 \$HOSTNAME >> /etc/hosts' >> /root/.set-hostname
chmod +x /root/.set-hostname


echo 'nameserver 8.8.8.8' > /etc/resolv.conf.upstream
echo 'nameserver 8.8.4.4' > /etc/resolv.conf.upstream
echo 'nameserver 2001:4860:4860::8888' > /etc/resolv.conf.upstream
echo 'nameserver 2001:4860:4860::8844' > /etc/resolv.conf.upstream


cp /etc/resolv.conf /etc/resolv.conf.upstream
mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
echo 'strict-order' >> /etc/dnsmasq.conf
echo 'domain-needed' >> /etc/dnsmasq.conf
echo 'local=/router.default.svc.cluster.local/' >> /etc/dnsmasq.conf
echo 'bind-dynamic' >> /etc/dnsmasq.conf
echo 'resolv-file=/etc/resolv.conf.upstream' >> /etc/dnsmasq.conf
echo 'address=/.router.default.svc.cluster.local/127.0.0.1' >> /etc/dnsmasq.conf
echo 'log-queries' >> /etc/dnsmasq.conf

echo 'prepend domain-name-servers 127.0.0.1' > /etc/dhcp/dhclient.conf

systemctl disable dnsmasq


curl -Lk https://raw.githubusercontent.com/openshift/origin/master/examples/image-streams/image-streams-centos7.json -o /openshift/image-streams-centos7.json
oc create -f /openshift/image-streams-centos7.json --namespace=openshift
oc policy add-role-to-user system:masters developer

echo 'export KUBECONFIG=/openshift.local.config/master/admin.kubeconfig' >> ~/.bashrc
echo 'export CURL_CA_BUNDLE=/openshift.local.config/master/ca.crt' >> ~/.bashrc
echo 'export PS1="$ "' >> ~/.bashrc