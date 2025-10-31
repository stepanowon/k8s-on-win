# 로컬 머신에 멀티노드 k8s 클러스터 만들기

[VirtualBox](https://www.virtualbox.org/)와 [Vagrant](https://www.vagrantup.com/) 최신 버전을 여러개의 VM을 실행할 수 있는 충분한 메모리를 가진 로컬 컴퓨터에 설치합니다.

- virtualbox는 반드시 확장팩까지 설치합니다.

## 기본 설치 사항 : k8s 1.34

- ubuntu-24.04
- node
  - master : 192.168.56.201 - 2vcpu, 4GB Memory
  - worker1 : 192.168.56.202 - 1vcpu, 2GB Memory
  - worker2 : 192.168.56.203 - 1vcpu, 2GB Memory
  - worker3 : 192.168.56.203 - 1vcpu, 2GB Memory
- 설치된 소프트웨어 : git, containerd, kubeadm v1.30
  - kubeadm v1.34 도구를 이용해 k8s 구성
- user1/asdf 로 사용자 생성
- user1을 sudoer로 등록
- 모든 vm에 hosts 파일 등록 : master, worker1~3

# 설치 방법

## 기본 환경 설치

- Oracle VirtualBox 설치 - https://www.virtualbox.org
- Vagrant 설치 - https://developer.hashicorp.com/vagrant/install?product_intent=vagrant

```sh
# github repo에서 vagrantfile을 내려받아 설치
git clone https://github.com/stepanowon/k8s-on-win
cd k8s-on-win
vagrant up

# 설치가 완료된 후 reload
vagrant reload

# 사용자명과 초기 패스워드 : user1/asdf
# 각 가상머신마다 접속하여 virtualbox 확장 설치
sudo apt-get install -y virtualbox-ext-pack
```

## Control Plane 역할의 VM(마스터) 초기화

```sh
# ssh 로 접속. user1/asdf 로 로그인
ssh user1@192.168.56.201
```

```sh
# kubeadm을 이용한 k8s cluster 초기화
sudo kubeadm init --apiserver-advertise-address=192.168.56.201 --pod-network-cidr=10.244.0.0/16

# kubeconfig 파일을 로컬 master의 vagrant 사용자의 홈디렉토리에 복사
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# kubectl 도구가 설치된 다른 컴퓨터를 이용하고 싶다면 ~/.kube/config 파일을 복사하여 사용함

# kubectl 자동완성 기능과 kubectl --> k로 사용하기
sudo apt install bash-completion
source /usr/share/bash-completion/bash_completion

echo 'source <(kubectl completion bash)' >>~/.bashrc
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -F __start_kubectl k' >>~/.bashrc

source ~/.bashrc
```

## [Calico](https://projectcalico.docs.tigera.io/getting-started/kubernetes/quickstart) CNI 플러그인을 설치함.

```sh
## calico CNI 설치
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.5/manifests/tigera-operator.yaml
kubectl create -f ~/vagrant/conf/calico-resources.yaml

## 설치 확인
$ kubectl get pods --all-namespaces
NAMESPACE          NAME                                       READY   STATUS    RESTARTS   AGE
calico-apiserver   calico-apiserver-8557fd65f-h5799           1/1     Running   0          57s
calico-apiserver   calico-apiserver-8557fd65f-p6mw4           1/1     Running   0          57s
calico-system      calico-kube-controllers-56fccc4788-7fjg9   1/1     Running   0          2m32s
calico-system      calico-node-xpkbv                          1/1     Running   0          2m33s
calico-system      calico-typha-74f5bfd6f7-z2pg5              1/1     Running   0          2m33s
calico-system      csi-node-driver-w24hd                      2/2     Running   0          2m33s
kube-system        coredns-55cb58b774-6ccdl                   1/1     Running   0          3m56s
kube-system        coredns-55cb58b774-dv58v                   1/1     Running   0          3m56s
kube-system        etcd-master                                1/1     Running   1          4m8s
kube-system        kube-apiserver-master                      1/1     Running   1          4m8s
kube-system        kube-controller-manager-master             1/1     Running   1          4m12s
kube-system        kube-proxy-ddj99                           1/1     Running   0          3m56s
kube-system        kube-scheduler-master                      1/1     Running   1          4m12s
tigera-operator    tigera-operator-576646c5b6-6h5t5           1/1     Running   0          2m46s
```

## 작업자 노드 추가(worker1과 worker2에서 수행)

```sh
# worker1에서 작업
$ ssh user1@192.168.56.202

```

```sh
# 마스터에서 kubeadm init 명령어 수행후 콘솔에 출력된 join 명령어를 실행함. 형식은 다음과 같음
$ sudo kubeadm join 192.168.56.201:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# 만일 token과 hash 값을 알수 없다면 다음 명령어 실행하여 확인
# kubeadm token list
# kubeadm token create --print-join-command

# worker2(192.168.56.203)에서도 동일하게 kubeadm join 할것
```

#### 로컬 컴퓨터에 3노드 k8s 클러스터 구성 완료 확인

```sh
# master 접속
$ ssh user1@192.168.56.201

$ kubectl get nodes
NAME      STATUS   ROLES           AGE     VERSION
master    Ready    control-plane   7m14s   v1.34.1
worker1   Ready    <none>          5m53s   v1.34.1
worker2   Ready    <none>          3m41s   v1.34.1

# calico CNI, worker1, worker2 설치 확인
$ kubectl get pods --all-namespaces
NAMESPACE          NAME                                       READY   STATUS    RESTARTS        AGE
calico-apiserver   calico-apiserver-7bb8b6d685-2ztrf          1/1     Running   0               80s
calico-apiserver   calico-apiserver-7bb8b6d685-ffcss          1/1     Running   0               80s
calico-system      calico-kube-controllers-77c5b95f97-9l9jz   1/1     Running   0               4m8s
calico-system      calico-node-8kgkm                          1/1     Running   0               4m
calico-system      calico-node-9b577                          1/1     Running   0               3m49s
calico-system      calico-node-g2mng                          1/1     Running   0               3m59s
calico-system      calico-typha-5885656b6d-9rjsn              1/1     Running   0               4m9s
calico-system      calico-typha-5885656b6d-x7lsg              1/1     Running   0               4m7s
calico-system      csi-node-driver-ccltk                      2/2     Running   0               4m11s
calico-system      csi-node-driver-dkfms                      2/2     Running   0               4m11s
calico-system      csi-node-driver-thvth                      2/2     Running   0               4m11s
kube-system        coredns-55cb58b774-hb4bg                   1/1     Running   0               8m3s
kube-system        coredns-55cb58b774-tmcdx                   1/1     Running   0               8m3s
kube-system        etcd-master                                1/1     Running   0               8m15s
kube-system        kube-apiserver-master                      1/1     Running   0               8m15s
kube-system        kube-controller-manager-master             1/1     Running   1 (5m27s ago)   8m15s
kube-system        kube-proxy-4rtb7                           1/1     Running   0               7m
kube-system        kube-proxy-qjdm9                           1/1     Running   0               4m48s
kube-system        kube-proxy-trcsp                           1/1     Running   0               8m3s
kube-system        kube-scheduler-master                      1/1     Running   1 (5m27s ago)   8m19s
tigera-operator    tigera-operator-576646c5b6-d4hdt           1/1     Running   0               4m47s
```

---

## metalLB 설치 (v0.15.2 기준)

#### 공식문서

https://metallb.universe.tf/installation/

- 설정 작업은 maser 노드에서 진행합니다.

#### kube-proxy의 strictARP 설정값을 true로 변경

```sh
kubectl get configmap kube-proxy -n kube-system -o yaml | sed -e "s/strictARP: false/strictARP: true/" | kubectl apply -f - -n kube-system
```

#### yaml 파일 이용해 metalLB 설치

```sh
# master 노드에서 실행
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
```

#### 설치된 metalLB 요소 확인

```sh
$ kubectl get all -n metallb-system
NAME                              READY   STATUS    RESTARTS      AGE
pod/controller-6dd967fdc7-jdcgq   1/1     Running   1 (33m ago)   34m
pod/speaker-ftfwm                 1/1     Running   0             34m
pod/speaker-vddww                 1/1     Running   0             34m
pod/speaker-x72gz                 1/1     Running   0             34m

NAME                              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/metallb-webhook-service   ClusterIP   10.96.10.203   <none>        443/TCP   34m

NAME                     DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/speaker   3         3         3       3            3           kubernetes.io/os=linux   34m

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/controller   1/1     1            1           34m

NAME                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/controller-6dd967fdc7   1         1         1       34m=
```

#### External IP로 사용할 IP Address Pool 과 L2 Advertisement 설정

```sh
$ cat ~/vagrant/conf/ip-addr-pool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: metallb-ip-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.56.51-192.168.56.80         #외부에서 접근가능한 IP 대역 지정
  autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  namespace: metallb-system
  name: example
spec:
  ipAddressPools:
  - metallb-ip-pool	    #직전 설정한 ip-pool 객체 지정
  nodeSelectors:	      # ip-pool을 이용해 접근하는 노드 지정 worker1, worker2 지정
  - matchLabels:
      kubernetes.io/hostname: worker1
  - matchLabels:
      kubernetes.io/hostname: worker2

$ kubectl apply -f ~/vagrant/conf/ip-addr-pool.yaml
```

#### LoadBalancer 테스트

```sh
$ kubectl apply -f ~/vagrant/conf/deployment.yaml
$ kubectl apply -f ~/vagrant/conf/svc-lb.yaml

$ kubectl get all
$ kubectl get all
NAME                                 READY   STATUS    RESTARTS   AGE
pod/nodeapp-deploy-986b998c4-kdbq8   1/1     Running   0          117s
pod/nodeapp-deploy-986b998c4-qfmjm   1/1     Running   0          117s

NAME                 TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
service/kubernetes   ClusterIP      10.96.0.1       <none>          443/TCP        17m
service/nodeapp-lb   LoadBalancer   10.103.201.26   192.168.56.51   80:31966/TCP   105s

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nodeapp-deploy   2/2     2            2           117s

NAME                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/nodeapp-deploy-986b998c4   2         2         2       117s

$ curl http://192.168.56.51
  <div>
    <h2> Version: 1.0.0 </h2>
    <h2> 호스트명 : nodeapp-deploy-986b998c4-qfmjm </h2>
  </div>

$ curl http://192.168.56.51
  <div>
    <h2> Version: 1.0.0 </h2>
    <h2> 호스트명 : nodeapp-deploy-986b998c4-kdbq8 </h2>
  </div>
```

#### 테스트용 deployment, sercice 삭제

```sh
$ kubectl delete -f ~/vagrant/conf/deployment.yaml
$ kubectl delete -f ~/vagrant/conf/svc-lb.yaml
```

---

## Ingress NGINX controller 테스트

[https://kubernetes.github.io/ingress-nginx/deploy/baremetal](https://kubernetes.github.io/ingress-nginx/deploy/baremetal).

#### 미리 설치할 것

- metalLB가 설치되어 있어야 함

#### ingress-nginx-controller 설치

```sh
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/baremetal/deploy.yaml

# 설치 확인
$ kubectl get all -n ingress-nginx
NAME                                           READY   STATUS      RESTARTS   AGE
pod/ingress-nginx-admission-create-xwll5       0/1     Completed   0          28s
pod/ingress-nginx-admission-patch-6kp5x        0/1     Completed   1          28s
pod/ingress-nginx-controller-548946fc6-xzs2j   1/1     Running     0          28s

NAME                                         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
service/ingress-nginx-controller             NodePort    10.110.86.20     <none>        80:30262/TCP,443:32420/TCP   29s
service/ingress-nginx-controller-admission   ClusterIP   10.110.172.255   <none>        443/TCP                      29s

NAME                                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ingress-nginx-controller   1/1     1            1           29s

NAME                                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/ingress-nginx-controller-548946fc6   1         1         1       29s

NAME                                       STATUS     COMPLETIONS   DURATION   AGE
job.batch/ingress-nginx-admission-create   Complete   1/1           7s         28s
job.batch/ingress-nginx-admission-patch    Complete   1/1           8s         28s
```

#### ingress-nginx-controller의 Service Type을 LoadBalancer로 변경

```sh
# 변경
### Linux
kubectl -n ingress-nginx patch service ingress-nginx-controller -p '{"spec":{"type":"LoadBalancer"}}'

### Windows
kubectl -n ingress-nginx patch service ingress-nginx-controller -p '{\"spec\":{\"type\":\"LoadBalancer\"}}'

# 변경후 EXTERNAL-IP 값 확인 (아래 예시에서는 192.168.56.51)
$ kubectl get svc -n ingress-nginx
NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.110.86.20     192.168.56.51   80:30262/TCP,443:32420/TCP   5m27s
ingress-nginx-controller-admission   ClusterIP      10.110.172.255   <none>          443/TCP                      5m27s
```

#### Host 컴퓨터 또는 master 노드의 hosts 파일에 EXTERNAL-IP에 대한 hostname 등록

```sh
# 윈도우 : c:\windows\system32\drivers\etc\hosts 파일을 관리자 권한으로 변경
# 리눅스 또는 맥 : sudo vi /etc/hosts
$ sudo vi /etc/hosts
192.168.56.51   demo.example.com
```

#### Service, Deployment 실행

```sh
# nodeapp1.yaml : /path1/* 패턴에 대한 요청 처리 애플리케이션
# nodeapp2.yaml : /path2/* 패턴에 대한 요청 처리 애플리케이션

$ kubectl apply -f ~/vagrant/conf/nodeapp1.yaml
$ kubectl apply -f ~/vagrant/conf/nodeapp2.yaml

# ingress 파일 편집 : host 필드의 값을 앞에서 hosts 파일에 등록한 hostname(demo.example.com) 으로 변경
$ cat ~/vagrant/conf/nodeapp-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - host: demo.example.com
    http:
      paths:
      - pathType: ImplementationSpecific
        path: /path1(/|$)(.*)
        backend:
          service:
            name: svc-nodeapp1
            port:
              number: 8080
      - pathType: ImplementationSpecific
        path: /path2(/|$)(.*)
        backend:
          service:
            name: svc-nodeapp2
            port:
              number: 8080

# ingresss 적용하기
$ kubectl apply -f ~/vagrant/conf/nodeapp-ingress.yaml
```

#### hosts 파일을 등록한 Host 또는 master 노드에서 다음과 같이 요청해보기

```sh
$ curl http://demo.example.com/path1/abc
  <div style="background-color:aqua">
    <h2> nodeapp-path1</h2>
    <h2> 호스트명 : nodeapp-path1-84c8cb66df-zglw2 </h2>
    <h2> 요청경로 : abc </h2>
  </div>

$ curl http://demo.example.com/path2/abc
  <div style="background-color:yellow">
    <h2> nodeapp-path2</h2>
    <h2> 호스트명 : nodeapp-path2-7c48f69bb5-x6rkm </h2>
    <h2> 요청경로 : abc </h2>
  </div>
```

#### 리소스 삭제

```sh
kubectl delete -f ~/vagrant/conf/nodeapp1.yaml
kubectl delete -f ~/vagrant/conf/nodeapp2.yaml
kubectl delete -f ~/vagrant/conf/nodeapp-ingress.yaml
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/baremetal/deploy.yaml

```

## Control Plane 추가 방법

#### 필수 요구 사항

- control plane으로 추가할 노드는 2vcpu, 2GB Memory 이상이어야 함

#### 기존 master 노드에서 certificate key 생성

- 아래 예시에서 생성된 key : f233b68f4......

```
$ sudo kubeadm init phase upload-certs --upload-certs
I1227 01:17:29.641399    7727 version.go:256] remote version is much newer: v1.32.0; falling back to: stable-1.30
[upload-certs] Storing the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
[upload-certs] Using certificate key:
f233b68f4c1ba881553aad28737a594c3fe181d59f1d9c0883e04c4ef33e893e
```

#### Token 생성

```
# 앞에서 생성한 certificate key를 이용해 token 생성하고 join command 생성
$ kubeadm token create --certificate-key  f233b68f4c1ba881553aad28737a594c3fe181d59f1d9c0883e04c4ef33e893e --print-join-command

kubeadm join 192.168.56.201:6443 --token rumtky.nkn0bjh0po0yxu9u --discovery-token-ca-cert-hash sha256:e002bd962b51c94a6eba26d37b93ee08c3717c53505309cb54eab7ece864160d --control-plane --certificate-key f233b68f4c1ba881553aad28737a594c3fe181d59f1d9c0883e04c4ef33e893e
```

#### control plane 추가 : 추가할 노드에서 실행

```
# 앞에서 생성한 kubeadm join 명령문을 sudo 로 실행함
$ sudo kubeadm join 192.168.56.201:6443 --token rumtky.nkn0bjh0po0yxu9u --discovery-token-ca-cert-hash sha256:e002bd962b51c94a6eba26d37b93ee08c3717c53505309cb54eab7ece864160d --control-plane --certificate-key f233b68f4c1ba881553aad28737a594c3fe181d59f1d9c0883e04c4ef33e893e
```
