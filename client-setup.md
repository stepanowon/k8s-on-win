# 윈도우에 k8s 관련 Client 도구 설정 방법

## WSL2 & Linux 설정

### Linux용 Windows 하위시스템, Virtual Machine Platform 설치

- '제어판 - 프로그램 및 기능 - Windows 기능 켜기/끄기' 로 이동
- 'Linux용 Windows 하위 시스템'과 'Virtual Machine Platform' 체크 후 확인
  - 이미 되어 있다면 Uncheck 후 확인하고 재부팅 후 다시 진행함
  - 필요한 파일 다운로드 화면이 나타나면 '다운로드'를 진행함
- 설치 완료 후 재부팅

### WSL 설치

- 다음 사이트에서 설치 파일을 다운로드 받아 설치를 진행함
  - 아래 사이트에서 최신 버전의 Assets 에서 x64 용 msi 설치 파일을 다운로드받아서 실행
  - https://github.com/microsoft/WSL/releases
- powershell을 관리자 권한으로 실행한 후 다음 명령어를 실행
  - `wsl.exe --update`
  - `wsl.exe --set-default-version 2`
- Ubuntu 24 설치
  - `wsl.exe --install -d Ubuntu-24.04`
  - 설치 후 사용자명과 패스워드를 설정해야 함

## 우분투 24 리눅스에 docker 설치

### 윈도우 터미널로 Ubuntu 24 터미널을 열고 다음 설정

```sh
# git 설치
sudo apt update -y
sudo apt install git -y

# docker 설치
sudo apt update -y
sudo apt install apt-transport-https ca-certificates curl -y

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository -y \
"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

sudo apt update -y
sudo apt install docker-ce docker-ce-cli containerd.io -y

sudo systemctl enable docker
sudo systemctl start docker
sudo chmod 666 /var/run/docker.sock
```

### WSL, 우분투 Linux에 클라이언트 도구 설치

#### kubectl : k8s 버전에 따라 달라질 수 있음

```
curl -LO https://dl.k8s.io/release/v1.36.2/bin/linux/amd64/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
```

#### argocd CLI

```
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

#### kubectl argo rollout

```
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x ./kubectl-argo-rollouts-linux-amd64
sudo mv ./kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
```

#### helm

```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh
```

## (선택)윈도우 Powershell에서 클라이언트 도구를 사용하고 싶다면

- kubectl
  - https://dl.k8s.io/release/v1.36.2/bin/windows/amd64/kubectl.exe
  - k8s 버전에 따라 달라질 수 있음
- argocd CLI
  - https://github.com/argoproj/argo-cd/releases/tag/v3.4.5
  - 가장 아래쪽 Assets 영역에서 윈도우용 파일을 다운로드받은 후 파일명을 argo.exe 로 변경
- kubectl argo rollout 다운로드
  - 다음 경로에서 다운로드
    - https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-windows-amd64
  - 파일명을 kubectl-argo-rollouts.exe로 변경
- helm
  - 다음 경로에서 windows amd64 용 압축파일 다운로드
    - https://github.com/helm/helm/releases
  - 압축을 풀고 helm.exe 파일을 사용
- **다운로드 받은 파일을 하나의 디렉토리로 모은 뒤 path 환경 변수에 등록**
