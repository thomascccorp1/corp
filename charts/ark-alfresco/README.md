#Create the cluster
./create_cluster.sh

eksctl create cluster \
--name alfresco-eks \
--version 1.21 \
--region us-east-1 \
--zones us-east-1a,us-east-1b \
--nodegroup-name alfresco-linux-nodes \
--nodes 2 \
--node-type m5.xlarge \
--nodes-min 0 \
--nodes-max 2 \
--with-oidc \
--ssh-access \
--ssh-public-key "~/.ssh/armcsbs-public.pub" \
--managed

#update local kubeconfig for LENS IDE
aws eks --region us-east-1 update-kubeconfig --name alfresco-eks

#Make sure to use correct cluster
kubectl config use-context  arn:aws:eks:us-east-1:300674751221:cluster/alfresco-eks

#Install istio using demo profile
istioctl install --set profile=demo

#This will install the Istio 1.9.3 demo profile with ["Istio core" "Istiod" "Ingress gateways" "Egress gateways"] components into the cluster.
#and creates the AWS classic ELB

helm repo update

#create EFS and ensure a mount target is created in each public subnet (since not using private nodes)
./create-efs.sh

kubectl create namespace alfresco
kubectl label namespace alfresco istio-injection=enabled

kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
a057bcf2e007f4be2baf6e85570cd540-1695087874.us-east-1.elb.amazonaws.com

#copied the alfresco helm chart repo locally to disable t-engines and search services in deployment.yamls
#added enabled flag to template:
{{- if .Values.tika.enabled }}
# update search services as well

helm dependency update ./alfresco-content-services/

#validate helm chart
helm alfresco-content-services/.
helm install --dry-run --generate-name alfresco-content-services/. --values=community_values.yaml --set externalPort="80" --set externalProtocol="http" --set externalHost="a057bcf2e007f4be2baf6e85570cd540-1695087874.us-east-1.elb.amazonaws.com" --set persistence.enabled=true --set persistence.storageClass.enabled=true --set persistence.storageClass.name="nfs-client" >&xx.out

helm upgrade --install acs ./alfresco-content-services \
--values=community_values.yaml \
--set externalPort="80" \
--set externalProtocol="http" \
--set externalHost="a057bcf2e007f4be2baf6e85570cd540-1695087874.us-east-1.elb.amazonaws.com" \
--set persistence.enabled=true \
--set persistence.storageClass.enabled=true \
--set persistence.storageClass.name="nfs-client" \
--atomic \
--timeout 10m0s \
--namespace=alfresco

#to get access to the /alfresco and /share end points install the istio gateway virtual services
kubectl -n alfresco apply -f alfresco-istio-gateway.yaml
gateway.networking.istio.io/alfresco-istio-gateway created
virtualservice.networking.istio.io/alfresco-istio-gateway created

kubectl -n alfresco get svc alfresco-istio-gateway
--Note the AWS ELB

kubectl get gateway -n alfresco
kubectl get vs -n alfresco
istioctl analyze -n alfresco

#This will install everything - all  the addons for istio metrics and tracing:
kubectl apply -f samples/addons   (run it twice if any error occurs)

#There are three mTLS modes you can use: STRICT , PERMISSIVE and DISABLE

kubectl apply -n alfresco -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: "default"
spec:
  mtls:
    mode: STRICT
EOF

kubectl apply -n alfresco -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: "default"
spec:
  mtls:
    mode: DISABLE
EOF

##################################
#CLEAN UP
##################################

#Reduce nodes to temporarily save costs
eksctl scale nodegroup --cluster alfresco-eks --name alfresco-linux-nodes --nodes 0

kubectl delete -n istio-system -f samples/addons

kubectl delete -n alfresco -f alfresco-istio-gateway.yaml

kubectl delete namespace alfresco

#should delete the istio ingress ELB in AWS
istioctl x uninstall --purge

kubectl delete namespace istio-system

#Go to the EFS Console, select the file system we created earlier and press the "Delete" button to remove the mount targets and file system.

eksctl delete cluster --name alfresco-eks