#!/bin/bash
export AKS_CLUSTER_NAME="aks-cluster-name"  # Set your AKS cluster name here

# Enable AKS Application Routing with Internal NGINX
az aks approuting enable --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --nginx Internal