# 
helm dependency update ./alfresco-content-services/
helm upgrade --install acs ./alfresco-content-services \
--values=community_values.yaml \
--set externalPort="80" \
--set externalProtocol="http" \
--set externalHost="aae41100e10c54d6fa10664f29ac0d51-1034373249.us-east-1.elb.amazonaws.com" \
--set persistence.enabled=true \
--set persistence.storageClass.enabled=true \
--set persistence.storageClass.name="nfs-client" \
--atomic \
--timeout 10m0s \
--namespace=alfresco
