#!/bin/sh

function install_bluemix_cli() {
#statements
echo "Installing Bluemix cli"
curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx
sudo mv cf /usr/local/bin
sudo curl -o /usr/share/bash-completion/completions/cf https://raw.githubusercontent.com/cloudfoundry/cli/master/ci/installers/completion/cf
cf --version
curl -L public.dhe.ibm.com/cloud/bluemix/cli/bluemix-cli/Bluemix_CLI_0.5.4_amd64.tar.gz > Bluemix_CLI.tar.gz
tar -xvf Bluemix_CLI.tar.gz
sudo ./Bluemix_CLI/install_bluemix_cli
}

function bluemix_auth() {
echo "Authenticating with Bluemix"
echo "1" | bx login -a https://api.ng.bluemix.net -u $BLUEMIX_USER -p $BLUEMIX_PASS
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
bx plugin install container-service -r Bluemix
echo "Installing kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
}

function cluster_setup() {
bx cs workers $CLUSTER
$(bx cs cluster-config $CLUSTER | grep export)

#Delete previous deployment and change image names.
kubectl delete --ignore-not-found=true -f manifests/deploy-schedule.yaml
kubectl delete --ignore-not-found=true -f manifests/deploy-session.yaml
kubectl delete --ignore-not-found=true -f manifests/deploy-speaker.yaml
kubectl delete --ignore-not-found=true -f manifests/deploy-vote.yaml
kubectl delete --ignore-not-found=true -f manifests/deploy-webapp.yaml
kubectl delete --ignore-not-found=true -f manifests/deploy-cloudant.yaml
kubectl delete --ignore-not-found=true -f manifests/deploy-job.yaml
kubectl delete --ignore-not-found=true -f manifests/ingress.yaml

curl -L https://git.io/getIstio | sh -
cd $(ls | grep istio)
sudo mv bin/istioctl /usr/local/bin/

kubectl apply -f install/kubernetes/istio-rbac-alpha.yaml
kubectl apply -f install/kubernetes/istio.yaml

PODS=$(kubectl get pods | grep istio | grep Pending)
while [ ${#PODS} -ne 0 ]
do
    echo "Some Pods are Pending..."
    PODS=$(kubectl get pods | grep istio | grep Pending)
    sleep 5s
done

PODS=$(kubectl get pods | grep istio | grep ContainerCreating)
while [ ${#PODS} -ne 0 ]
do
    echo "Some Pods are still creating Containers..."
    PODS=$(kubectl get pods | grep istio | grep ContainerCreating)
    sleep 5s
done
}

function initial_setup() {
echo "Creating Java MicroProfile with Injected Envoys..."
cd ..
kubectl create -f manifests/ingress.yaml
kubectl apply -f manifests/deploy-job.yaml
kubectl apply -f <(istioctl kube-inject -f manifests/deploy-schedule.yaml)
kubectl apply -f <(istioctl kube-inject -f manifests/deploy-session.yaml)
kubectl apply -f <(istioctl kube-inject -f manifests/deploy-speaker.yaml)
kubectl apply -f <(istioctl kube-inject -f manifests/deploy-cloudant.yaml --includeIPRanges=172.30.0.0/16,172.20.0.0/16)
kubectl apply -f <(istioctl kube-inject -f manifests/deploy-vote.yaml)
kubectl apply -f <(istioctl kube-inject -f manifests/deploy-webapp.yaml)

PODS=$(kubectl get pods | grep Init)
while [ ${#PODS} -ne 0 ]
do
    echo "Some Pods are Initializing..."
    PODS=$(kubectl get pods | grep Init)
    sleep 5s
done

echo "MicroProfile done."

}

function health_check() {

export GATEWAY_URL=$(bx cs workers $CLUSTER | grep normal | awk '{ print $2}' | head -1):$(kubectl get svc istio-ingress -o jsonpath={.spec.ports[0].nodePort})
sleep 60s #wait for Websphere Liberty to be up
export HEALTH=$(curl -o /dev/null -s -w "%{http_code}\n" http://$GATEWAY_URL)
echo $HEALTH
if [ $HEALTH -eq 200 ]
then
  echo "Everything looks good."
  echo "Cleaning up."
  kubectl delete --ignore-not-found=true -f manifests/deploy-schedule.yaml
  kubectl delete --ignore-not-found=true -f manifests/deploy-session.yaml
  kubectl delete --ignore-not-found=true -f manifests/deploy-speaker.yaml
  kubectl delete --ignore-not-found=true -f manifests/deploy-vote.yaml
  kubectl delete --ignore-not-found=true -f manifests/deploy-webapp.yaml
  kubectl delete --ignore-not-found=true -f manifests/deploy-cloudant.yaml
  kubectl delete --ignore-not-found=true -f manifests/deploy-job.yaml
  kubectl delete --ignore-not-found=true -f manifests/ingress.yaml
  cd $(ls | grep istio)
  kubectl delete -f install/kubernetes/istio.yaml
  kubectl delete -f install/kubernetes/istio-rbac-alpha.yaml
  echo "Deleted Istio in cluster"
else
  echo "Health check failed."
  exit 1
fi
}



install_bluemix_cli
bluemix_auth
cluster_setup
initial_setup
health_check
