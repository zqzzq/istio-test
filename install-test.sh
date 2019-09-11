#!/bin/bash

source ./istio-test-config.conf

current_image=$(grep "image:" perf_k8svcs.yaml |tail -1 | awk '{print $2}')
sed -i "s|image: $current_image|image: $test_image|g" ./perf_k8svcs.yaml

function create_instances() {
  echo "----------------------------------------------------------creating the necessary service----------------------------------------------------------"
  kubectl create ns perf-istio
  kubectl label ns perf-istio istio-injection=enabled
  kubectl create ns perf-fortio
  kubectl create ns perf-client
  kubectl apply -f ./perf_istio_rules.yaml
  kubectl apply -f ./perf_k8svcs.yaml
}

function wait_pod_up() {
  echo "----------------------------------------------------------waiting the pod up----------------------------------------------------------"
  kubectl  rollout status deploy  echo-svc-deployment1 -n perf-istio   -w
  kubectl  rollout status deploy  echo-svc-deployment2 -n perf-istio   -w
  kubectl  rollout status deploy  echo-svc-deployment3 -n perf-fortio   -w
  kubectl  rollout status deploy  echo-svc-deployment4 -n perf-fortio   -w
  kubectl  rollout status deploy  fortio-client -n perf-client  -w
}


function ingress_to_s1() {
  if [ $1 -eq -1  ]; then
    echo "          "
    echo "--------------------------max qps|gateway|have sidecar--------------------------"
    echo "Max qps: using istio ingress to fortio1, more details saving to 'log/ingress_to_s1_max_qps.log'"
    kubectl -n perf-client  exec -it $CLIENT_POD_NAME -c fortio-client /usr/bin/fortio  -- load -qps -1 -c 48  -t 30s http://$ISTIO_INGRESSGATEWAY_IP/fortio1/echo | tee "./log/ingress_to_s1_max_qps.log" | grep -E "Code|All"
  else
    echo "          "
    echo "--------------------------400 qps|gateway|have sidecar--------------------------"
    echo "400 qps: using istio ingress to fortio1, more details saving to 'log/ingress_to_s1_400_qps.log'"
    kubectl -n perf-client  exec -it $CLIENT_POD_NAME -c fortio-client /usr/bin/fortio  -- load -qps 400 -c 48  -t 30s http://$ISTIO_INGRESSGATEWAY_IP/fortio1/echo | tee "./log/ingress_to_s1_400_qps.log" | grep -E "Code|All"
  fi
}

function ingress_to_s3() {
  if [ $1 -eq -1  ]; then
    echo "          "
    echo "--------------------------max qps|gateway|no sidecar--------------------------"
    echo "Max qps: using istio ingress to fortio3 without sidecar, more details saving to 'log/ingress_to_s3_no_sidecar_max_qps.log'"
    kubectl -n perf-client  exec -it $CLIENT_POD_NAME -c fortio-client /usr/bin/fortio  -- load -qps -1 -c 48  -t 30s http://$ISTIO_INGRESSGATEWAY_IP/fortio3/echo | tee "./log/ingress_to_s3_no_sidecar_max_qps.log" | grep -E "Code|All"
  else
    echo "          "
    echo "--------------------------400 qps|gateway|no sidecar--------------------------"
    echo "400 qps: using istio ingress to fortio3 without sidecar, more details saving to 'log/ingress_to_s3_no_sidecar_400_qps.log'"
    kubectl -n perf-client  exec -it $CLIENT_POD_NAME -c fortio-client /usr/bin/fortio -- load -qps 400 -c 48  -t 30s http://$ISTIO_INGRESSGATEWAY_IP/fortio3/echo | tee "./log/ingress_to_s3_no_sidecar_400_qps.log" | grep -E "Code|All"
  fi
}

function s1_to_s2() {
  if [ $1 -eq -1  ]; then
    echo "          "
    echo "--------------------------max qps|mesh|have sidecar--------------------------"
    echo "Max qps: using s1 to s2, more details saving to 'log/s1_to_s2_max_qps.log'"
    kubectl -n perf-istio  exec -it $S1_POD_NAME -c echosrv  /usr/bin/fortio  -- load -qps -1 -c 48  -t 30s http://echosrv2.perf-istio:8080/echo | tee "./log/s1_to_s2_max_qps.log" | grep -E "Code|All"
  else
    echo "          "
    echo "--------------------------400 qps|mesh|have sidecar--------------------------"
    echo "400 qps: using s1 to s2, more details saving to 'log/s1_to_s2_400_qps.log'"
    kubectl -n perf-istio  exec -it $S1_POD_NAME -c echosrv  /usr/bin/fortio  -- load -qps 400 -c 48 -t 30s http://echosrv2.perf-istio:8080/echo | tee "./log/s1_to_s2_400_qps.log" | grep -E "Code|All"
  fi
}

function s3_to_s4() {
  if [ $1 -eq -1  ]; then
    echo "          "
    echo "--------------------------max qps|mesh|no sidecar--------------------------"
    echo "Max qps: using s3 to s4 without sidecar, more details saving to 'log/s3_to_s4_no_sidecar_max_qps.log'"
    kubectl -n perf-fortio  exec -it $S3_POD_NAME -c echosrv  /usr/bin/fortio  -- load -qps -1 -c 48 -t 30s  http://echosrv4.perf-fortio:8080/echo | tee "./log/s3_to_s4_no_sidecar_max_qps.log" | grep -E "Code|All"
  else
    echo "          "
    echo "--------------------------400 qps|mesh|no sidecar--------------------------"
    echo "400 qps: using s3 to s4 without sidecar, more details saving to 'log/s3_to_s4_no_sidecar_400_qps.log'"
    kubectl -n perf-fortio  exec -it $S3_POD_NAME -c echosrv  /usr/bin/fortio  -- load -qps 400 -c 48 -t 30s  http://echosrv4.perf-fortio:8080/echo | tee "./log/s3_to_s4_no_sidecar_400_qps.log" | grep -E "Code|All"
  fi
}

function get_IP_and_name() {
  echo "----------------------------------------------------------get ingress ip and test pod name----------------------------------------------------------"
  ISTIO_INGRESSGATEWAY_IP=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.clusterIP}')
  echo "ISTIO_INGRESSGATEWAY_IP is :" $ISTIO_INGRESSGATEWAY_IP
  CLIENT_POD_NAME=$(kubectl get pod -n perf-client| grep fortio-client |grep Running | awk '{ print $1 }')
  echo "CLIENT_POD_NAME is :" $CLIENT_POD_NAME
  S1_POD_NAME=$(kubectl get pod -n perf-istio| grep echo-svc-deployment1 |grep Running | awk '{ print $1 }')
  echo "S1_POD_NAME is :" $S1_POD_NAME
  S3_POD_NAME=$(kubectl get pod -n perf-fortio| grep echo-svc-deployment3 |grep Running | awk '{ print $1 }')
  echo "S3_POD_NAME is :" $S3_POD_NAME
}

function check_svc_available() {
  echo "----------------------------------------------------------check svc available----------------------------------------------------------"
  while :
  do
    resp1=$(kubectl -n perf-client  exec -it $CLIENT_POD_NAME -c fortio-client /usr/bin/fortio  -- load -qps -1 -c 48  -n 1 http://$ISTIO_INGRESSGATEWAY_IP/fortio1/echo |grep 200|grep 100)
    resp2=$(kubectl -n perf-istio  exec -it $S1_POD_NAME -c echosrv /usr/bin/fortio  -- load -qps -1 -c 48  -n 1 http://echosrv2.perf-istio:8080/echo |grep 200|grep 100)
    resp3=$(kubectl -n perf-client  exec -it $CLIENT_POD_NAME -c fortio-client /usr/bin/fortio  -- load -qps -1 -c 48  -n 1 http://$ISTIO_INGRESSGATEWAY_IP/fortio3/echo |grep 200|grep 100)
    resp4=$(kubectl -n perf-fortio  exec -it $S3_POD_NAME -c echosrv /usr/bin/fortio  -- load -qps -1 -c 48  -n 1 http://echosrv4.perf-fortio:8080/echo |grep 200|grep 100) 
    if [ -z "$resp1" ]||[ -z "$resp2" ]||[ -z "$resp3" ]||[ -z "$resp4" ]
    then
      echo "no available"
      sleep 1
      continue
    fi
    echo "all service is ready"
    break
  done
}

function run_test() {
  echo "----------------------------------------------------------running test----------------------------------------------------------"
  ingress_to_s1 -1
  ingress_to_s3 -1
  s1_to_s2 -1
  s3_to_s4 -1
  ingress_to_s1 400
  ingress_to_s3 400
  s1_to_s2 400
  s3_to_s4 400
}

create_instances
wait_pod_up
get_IP_and_name
check_svc_available
sleep 10
run_test


