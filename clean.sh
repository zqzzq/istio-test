#!/bin/bash

kubectl delete -f perf_k8svcs.yaml
kubectl delete -f perf_istio_rules.yaml

while :
do
  resp1=$(kubectl -n perf-istio  get po)
  resp2=$(kubectl -n perf-fortio get po)
  resp3=$(kubectl -n perf-client get po)
  if [ -z "$resp1" ]&&[ -z "$resp2" ]&&[ -z "$resp3" ]  
  then
    kubectl delete ns perf-istio perf-fortio perf-client
    break
  fi
  sleep 2
done






