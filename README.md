# Red Hat Openshift ServiceMesh (OSSM) and Red Hat Application Interconnect(RHAI) to access strimzi Kafka cluster(Kafka) Demo

This Demo LAB provides a step-by-step guide to deploy a highly restricted Openshift ServiceMesh(OSSM) with Outbound Policy restricted and enforced mTLS on the Control and Data plane.
The strimzi Kafka cluster(Kafka) will be included in these restrictions and producers and consumers are accessing the Kafka brokers from different namespaces on the same Cluster. 
Additionally we will deploy another Consumer on a second Red Hat Openshift Cluster(OCP) that will utilize RHAI to access the Kafka brokers through a mTLS enforced ServiceMesh and a RHAI 
connection to the Kafka OCP cluster.

## Requirements

* 2 OCP Clusters
* Network connectivity (https) between the OCP Clusters for RHAI
* OSSM operator and dependencies installed in both OCP Cluster
* RHAI operator installed in both OCP Clusters

### Deployment of the highly restricted and mTLS enforced ServiceMesh 

Apply the [ServiceMeshControlPlane)[#smcp.yml] CRD to both Clusters. We will not federate the two meshes so we do not need to configure alternative names and or exchange Certificate Authority information for this LAB.

```
# for completition only (expected that you have a istio-system namespace already
# oc --context cluster1 create namespace istio-system
# oc --context cluster2 create namespace istio-system

$ oc --context cluster1 -n istio-system apply -f smcp.yml
$ oc --context cluster2 -n istio-system apply -f smcp.yml
```

ensure all resources are up and healthy before proceeding 

### Deployment of the strimzi Kafka operator and Cluster 

the strimzi Kafka Cluster deployment has been copied from the original [LAB](https://github.com/michaelalang/kafka-ossm-demo) and adapted for multiple namespaces and RHAI separation of the `frontend` (consumer).

```
cd kafka-ossm-demo
$ oc --context cluster1 create -k overlays/openshift/
```

ensure all components are deployed and the `strimzi-cluster-operator` is restarted once to be included in the ServiceMesh 

```
$ oc --context cluster1 -n kafka rollout restart deploy/strimzi-cluster-operator

# check that the istio-proxy has been injected  (READY 2/2)
$ oc --context cluster1 -n kafka get pods 
NAME                                        READY   STATUS    RESTARTS   AGE
strimzi-cluster-operator-779df6b8df-cl7jr   2/2     Running   0          2m23s
```

create the Kafka cluster 

```
$ oc --context cluster1 -n kafka create -f cluster/cluster.yml

# check that all resources brokers,nodes,boostrap have been created and hve the istio-proxy injected accordingly (READY 2/2)
$ oc --context cluster1 -n kafka get pods
NAME                                        READY   STATUS    RESTARTS   AGE
pizza-kafka-0                               2/2     Running   0          37s
pizza-kafka-1                               2/2     Running   0          36s
pizza-kafka-2                               2/2     Running   0          36s
pizza-zookeeper-0                           2/2     Running   0          60s
pizza-zookeeper-1                           2/2     Running   0          60s
pizza-zookeeper-2                           2/2     Running   0          60s
strimzi-cluster-operator-779df6b8df-cl7jr   2/2     Running   0          6m15s
```

### Deployment of the producers (stores) 

the Kafka producers (stores) simulate customers walking into your pizza business and ordering food and drinks. Those are in the namespace `producers` 

```
$ oc --context cluster1 create -k producers/
```

you might face the pods in `CrashLoopBackOff` or without the istio-proxy (READY 1/1) running. Since we are not using a GitOPS controller, we need to restart the 
deployments to pick up the istio-proxy injection.

```
$ oc --context cluster1 -n producers rollout restart deploy
$ oc --context cluster1 -n producers get pods
NAME                      READY   STATUS    RESTARTS      AGE
store1-766c884b7b-2r76w   2/2     Running   1 (25s ago)   29s
store2-b6bd4b49-7rvt4     2/2     Running   1 (19s ago)   29s
store3-7d97665c89-69q2j   2/2     Running   1 (25s ago)   29s
store4-58d56b4bc7-t5nxf   2/2     Running   1 (24s ago)   29s
```

### Deployment of the consumers (kitchens, waiters)

the Kafka consumers (kitchens, waiters) simulate your employees taking workload for food and drinks. Those are in the namespace `consumers`

```
$ oc --context cluster1 create -k consumers/
```

you might face the pods in `CrashLoopBackOff` or without the istio-proxy (READY 1/1) running. Since we are not using a GitOPS controller, we need to restart the 
deployments to pick up the istio-proxy injection.


```
$ oc --context cluster1 -n consumers rollout restart deploy
$ oc --context cluster1 -n consumers get pods
NAME                        READY   STATUS    RESTARTS   AGE
kitchen1-5f7cd7d474-khmxp   2/2     Running   0          53s
kitchen2-5485c98867-hlqgl   2/2     Running   0          53s
waiter-589cb56c46-chkdc     2/2     Running   0          53s
waiter2-5c8d5c98f9-f5th5    2/2     Running   0          53s
```

#### Pro-active check if the deployment is working so far as expected

* check the logs of one store to see some workload being generated 

```
$ oc --context cluster -n producers logs --tail 10 deploy/store1
...
INFO:root:Sending: {'location': 'store1', 'psk': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJwaXp6YSIsImV4cCI6MTY4NzgwNjU4OX0.13IWfixjgpy7AV1n2iYEjskxcZ80JqHBYTn_B-U-UPI', 'name': 'Angela Martinez', 'address': ['465 Lewis Gateway Suite 190', 'Rodriguezside, AS 40357'], 'phone': '001-212-455-4355', 'timestamp': '19:04:49', 'customerid': 8378465, 'state': 'Mississippi', 'drinks': [{'name': 'Pepsi', 'count': 3}]}
```

* check the logs of one kitchen or waiter to see some workload being picked up

```
$ oc --context cluster -n consumers logs --tail 50 deploy/kitchen1
...
{
  "location": "store1",
  "psk": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJwaXp6YSIsImV4cCI6MTY4NzgwNjQ2MH0.mMAwk2WMSAxFl5jfLwsd-Fkxz8pXzRG45QIIfHM8moY",
  "name": "Philip Solis",
  "address": [
    "44352 Brenda Junction Apt. 064",
    "Andrewville, NC 01524"
  ],
  "phone": "(940)641-0906",
  "timestamp": "19:02:40",
  "customerid": 378,
  "state": "Kentucky",
  "pizza": [
    {
      "name": "Pepperoni",
      "topings": "Ham"
    },
    {
      "name": "Pepperoni",
      "topings": "Cheese"
    },
    {
      "name": "Pepperoni",
      "topings": "Ham"
    }
  ]
}
```

### Deployment of RHAI on both OCP clusters

**!!! NOTE !!!** you need to adjust the names for the routes prior deploying the RHAI CRDs.

```
# change back to the git repository root directory
$ cd ~/ossm-rhai-kafka-demo/
$ oc --context cluster1 create -k cluster1/
$ oc --context cluster2 create -k cluster2/
```

Both RHAI deployments are in separate namespaces. The reason the namespace for `cluster2` is picked as `kafka` relates to how Kafka distributes and balances between broker/broker-nodes.
To simplify the LAB, we will deploy our `cluster2` RHAI in the namespace `kafka`.

Check on both RHAI instances are coming up and istio-proxy has been injected (skupper-router READY 3/3, skupper-service-controller READY 2/2)

```
$ oc --context cluster1 -n test get pods
NAME                                         READY   STATUS    RESTARTS   AGE
skupper-router-6564d5644f-jfhnk              3/3     Running   0          2m40s
skupper-service-controller-6545db74f-pcg2k   2/2     Running   0          2m38s

$ oc --context cluster2 -n kafka get pods
NAME                                          READY   STATUS    RESTARTS       AGE
skupper-router-c965864d4-nl4mt                3/3     Running   0              3m17s
skupper-service-controller-69bdf9b48c-88p4m   2/2     Running   2 (3m1s ago)   3m15s
```

Check on both RHAI instances that we have not misconfigured the skupper internal resources from OSSM perspective. 
Your logs should contain lines similar to those below indicating that connections to the RHAI AMQP service are working (:5671)

```
$ oc --context cluster1 -n test logs --tail 10 deploy/skupper-router -c router
...
2023-06-26 19:10:40.826772 +0000 SERVER (info) [C4] Accepted connection to :5671 from 127.0.0.6:43547
2023-06-26 19:10:40.832770 +0000 ROUTER_CORE (info) [C4] Connection Opened: dir=in host=127.0.0.6:43547 encrypted=TLSv1.3 auth=EXTERNAL user=CN=skupper-router-local container_id=QuIAdZaq4inUdxuOBl8xzVtmQuOJfVvx1QQM-Gx_SrfhjPRjKliLYA props=
2023-06-26 19:10:40.833944 +0000 ROUTER_CORE (info) [C4][L7] Link attached: dir=out source={(dyn)<none> expire:sess} target={<none> expire:sess}
2023-06-26 19:10:40.834468 +0000 ROUTER_CORE (info) [C4][L8] Link attached: dir=in source={<none> expire:sess} target={$management expire:sess}
2023-06-26 19:10:40.835231 +0000 ROUTER_CORE (info) [C4][L9] Link attached: dir=in source={<none> expire:sess} target={<none> expire:sess}
2023-06-26 19:10:40.836790 +0000 ROUTER_CORE (info) [C4][L10] Link attached: dir=out source={5b491c9c-bcf3-49f4-9f23-6a8512fd0a14/skupper-site-query expire:sess} target={<none> expire:sess}
```

For additional debugging needs, the SMCP has been configured to provide access logs which will indicate through records like `BlackHoleCluster` that we are missing some configuration. 
SSL protcol issues indicate that a `DestinationRule` might be missing and will be visible in the logs of `deploy/skupper-router -c router` pods.

```
# check the istio-proxy logs for issues 
$ oc --context cluster -n kafka logs --tail 10 deploy/skupper-router -c istio-proxy
...
[2023-06-26T19:15:14.008Z] "- - -" 0 - - - "-" 581 2524 3 - "-" "-" "-" "-" "10.130.0.201:8080" inbound|8080|| 127.0.0.6:35617 10.130.0.201:8080 10.130.0.2:51152 - -
[2023-06-26T19:15:19.012Z] "- - -" 0 - - - "-" 581 2524 3 - "-" "-" "-" "-" "10.130.0.201:8080" inbound|8080|| 127.0.0.6:55881 10.130.0.201:8080 10.130.0.2:54256 - -
[2023-06-26T19:15:24.016Z] "- - -" 0 - - - "-" 581 2524 2 - "-" "-" "-" "-" "10.130.0.201:8080" inbound|8080|| 127.0.0.6:38107 10.130.0.201:8080 10.130.0.2:54260 - -
[2023-06-26T19:15:29.020Z] "- - -" 0 - - - "-" 581 2524 4 - "-" "-" "-" "-" "10.130.0.201:8080" inbound|8080|| 127.0.0.6:42813 10.130.0.201:8080 10.130.0.2:39314 - -

# as well for the service-controller 
$ oc --context cluster1 -n test logs --tail 10 deploy/skupper-service-controller -c istio-proxy
[2023-06-26T19:17:45.815Z] "- - -" 0 - - - "-" 581 2521 4 - "-" "-" "-" "-" "10.132.0.125:8080" inbound|8080|| 127.0.0.6:46577 10.132.0.125:8080 10.132.0.2:56162 - -
[2023-06-26T19:17:50.821Z] "- - -" 0 - - - "-" 581 2521 14 - "-" "-" "-" "-" "10.132.0.125:8080" inbound|8080|| 127.0.0.6:58709 10.132.0.125:8080 10.132.0.2:56168 - -
[2023-06-26T19:17:55.835Z] "- - -" 0 - - - "-" 581 2521 3 - "-" "-" "-" "-" "10.132.0.125:8080" inbound|8080|| 127.0.0.6:51669 10.132.0.125:8080 10.132.0.2:43798 - -
``` 

### RHAI Link both OCP Clusters 

As mentioned, we are utilizing two different namespaces. From RHAI perspective it does not matter if you create the Link from cluster1 to cluster2 or vice-versa.
For the example here we will create the Link from `cluster1` to `cluster2` 

**NOTE** RHAI Links are bi-directional. You do not need to create another link in the other direction, furthermore there is a memory leak Bug in the currently shipped RHAI if you configure duplicated Links.

If you haven't done so far, download the RHAI cli tool. At the time of this LAB the RHAI Operator version was 1.2.2 and the corresponding cli binary is available at [github.com](https://github.com/skupperproject/skupper/releases/tag/1.2.2)

```
[ -d ~/bin ] || mkdir ~/bin
$ curl -s -o- -L https://github.com/skupperproject/skupper/releases/download/1.2.2/skupper-cli-1.2.2-linux-amd64.tgz | tar -xz -C ~/bin && chmod +x ~/bin/skupper
$ skupper -c cluster1 -n test version
client version                 1.2.2
transport version              registry.redhat.io/application-interconnect/skupper-router-rhel8@sha256:8f49633e98e4c8900a32cdbb5a67b859be188525305b969f019e4d445b5488f0 (sha256:23578939590a)
controller version             registry.redhat.io/application-interconnect/skupper-service-controller-rhel8@sha256:1a5f058401b10ecd45dc0841e485d73a686de8d0c20dcb1139f26c550677997b (sha256:1a5f058401b1)
config-sync version            registry.redhat.io/application-interconnect/skupper-config-sync-rhel8@sha256:5e01564d9f2f6a4929cf01f9d81652bff007834ffcc6727eac6c90bd8b71869e (sha256:5e01564d9f2f)

$ skupper -c cluster2 -n kafka version
client version                 1.2.2
transport version              registry.redhat.io/application-interconnect/skupper-router-rhel8@sha256:8f49633e98e4c8900a32cdbb5a67b859be188525305b969f019e4d445b5488f0 (sha256:23578939590a)
controller version             registry.redhat.io/application-interconnect/skupper-service-controller-rhel8@sha256:1a5f058401b10ecd45dc0841e485d73a686de8d0c20dcb1139f26c550677997b (sha256:1a5f058401b1)
config-sync version            registry.redhat.io/application-interconnect/skupper-config-sync-rhel8@sha256:5e01564d9f2f6a4929cf01f9d81652bff007834ffcc6727eac6c90bd8b71869e (sha256:5e01564d9f2f)
```

#### creating a Token 

Tokens are created on the RHAI namespace/cluster the other cluster connects to. So in our example `cluster1` creates a Token for `cluster2` which will be used to connect. `cluster2` is the RHAI where we create the Link.

```
# we do not need to specify expiry and uses but for the case that we did not get the configuration correct, we do not need to re-create tokens over and over
~/bin/skupper -c cluster1 -n test token create --name cluster2 --expiry 48h --uses 10 cluster2.token
```

the `token create` command drops a file `cluster2.token` into the current directory which we require for establishing the Link on `cluster2`.

```
$ ~/bin/skupper -c cluster2 -n kafka link create --name cluster1 cluster2.token 
Site configured to link to https://claims-test.apps.cluster1.example.com:443/cluster2 (name=cluster1)
Check the status of the link using 'skupper link status'.

# and after a few seconds you should see the Link under the `created` List on cluster2 and under the `other sites` on cluster1
$ ~/bin/skupper -c cluster2 -n kafka link status
Links created from this site:
-------------------------------
Link cluster1 is active

Currently active links from other sites:
----------------------------------------
There are no active links


# now the link on cluster1
$ ~/bin/skupper -c cluster1 -n test link status

Links created from this site:
-------------------------------
There are no links configured or active

Currently active links from other sites:
----------------------------------------
A link from the namespace kafka on site kafka(5b491c9c-bcf3-49f4-9f23-6a8512fd0a14) is active 
```

#### exposing our Kafka Service to cluster2

At the time of writing the LAB, RHAI is lacking the capability to expose Pods which strimzi Kafka creates for broker nodes, so we need to add a service CRD for those to our Kafka cluster.

```
$ oc --context cluster1 -n kafka create -f cluster1/services.yml 
```

now we can expose on `cluster` in our RHAI namespace `test` the created services for `cluster2` 

```
$ cat create-services.sh 
for name in pizza-kafka-bootstrap pizza-kafka-brokers pizza-kafka-0 pizza-kafka-1 pizza-kafka-2 ; do 
	skupper -c cluster1 -n test service create ${name} 9092
	skupper -c cluster1 -n test service bind ${name} service ${name}.kafka.svc.cluster.local --target-port 9092 
done 

$ sh create-services.sh
```

if our ServiceMesh configuration was accurate, we can already see those services on `cluster2` in the namespace `kafka`.

```
$ oc --context cluster2 -n kafka get services
NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)               AGE
pizza-kafka-0           ClusterIP   172.30.66.59     <none>        9092/TCP              54s
pizza-kafka-1           ClusterIP   172.30.45.8      <none>        9092/TCP              52s
pizza-kafka-2           ClusterIP   172.30.30.213    <none>        9092/TCP              50s
pizza-kafka-bootstrap   ClusterIP   172.30.148.0     <none>        9092/TCP              57s
pizza-kafka-brokers     ClusterIP   172.30.203.193   <none>        9092/TCP              55s
skupper                 ClusterIP   172.30.189.62    <none>        8080/TCP,8081/TCP     42m
skupper-router          ClusterIP   172.30.164.59    <none>        55671/TCP,45671/TCP   42m
skupper-router-local    ClusterIP   172.30.29.192    <none>        5671/TCP              42m
```

### Deployment of the Pizza Businiess frontend on cluster2

Due to the mechanism of Kafka on leader election, sharding and active broker node, we need to ensure our frontend does get the Services resolved. Unfortunately I was only able to achive that through adding Hosts entries in the deployment.

```
# grab the servicenames and IPs of the pizza-kafka-[0-2] services
$ oc --context cluster2 -n kafka get services
NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)               AGE
pizza-kafka-0           ClusterIP   172.30.66.59     <none>        9092/TCP              54s
pizza-kafka-1           ClusterIP   172.30.45.8      <none>        9092/TCP              52s
pizza-kafka-2           ClusterIP   172.30.30.213    <none>        9092/TCP              50s
...

``` 
adjust the IP Addresses in the frontend deployment yaml 

```
$ vi kafka-ossm-demo/frontend/frontend.yml
    spec:
      hostAliases:
      - ip: "172.30.66.59"
        hostnames:
        - "pizza-kafka-0.pizza-kafka-brokers.kafka.svc"
      - ip: "172.30.45.8"
        hostnames:
        - "pizza-kafka-1.pizza-kafka-brokers.kafka.svc"
      - ip: "172.30.30.213"
        hostnames:
        - "pizza-kafka-2.pizza-kafka-brokers.kafka.svc"
```

save the change and deploy the frontend 

``` 
oc --context cluster2 -n kafka create -k kafka-ossm-demo/frontend/
```

You can now connect through `curl` or your favorite browser at the Route configured accordingly.

```
curl https://pizza-frontend.cluster2.example.com
<table border="1"><tr><th>location</th><td>store1</td></tr><tr><th>psk</th><td>eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJwaXp6YSIsImV4cCI6MTY4NzgwOTg4MX0.hJq7abMtlk9vEqjmUvqiXlkYuinzyC6CDZvzjZJ3WbE</td></tr><tr><th>name</th><td>Mariah Robinson</td></tr><tr><th>address</th><td><ul><li>8551 Kyle Road Apt. 970</li><li>Reedburgh, MD 79194</li></ul></td></tr><tr><th>phone</th><td>585.705.1602</td></tr><tr><th>timestamp</th><td>19:59:41</td></tr><tr><th>customerid</th><td>22</td></tr><tr><th>state</th><td>Michigan</td></tr><tr><th>pizza</th><td><table border="1"><thead><tr><th>name</th><th>topings</th></tr></thead><tbody><tr><td>Diavola</td>
...
```

if all configurations are accurate you will see log output in the frontend pods similar to that

```
INFO:kafka.coordinator:Starting new heartbeat thread
INFO:kafka.coordinator.consumer:Revoking previously assigned partitions set() for group 46673445-fb77-4f0f-8b54-6ea8a25d7652
INFO:kafka.coordinator:(Re-)joining group 46673445-fb77-4f0f-8b54-6ea8a25d7652
INFO:kafka.coordinator:Elected group leader -- performing partition assignments using range
INFO:kafka.coordinator:Successfully joined group 46673445-fb77-4f0f-8b54-6ea8a25d7652 with generation 1
INFO:kafka.consumer.subscription_state:Updated partition assignment: [TopicPartition(topic='store1.drinks', partition=0), TopicPartition(topic='store1.orders', partition=0), TopicPartition(topic='store2.drinks', partition=0), TopicPartition(topic='store2.orders', partition=0), TopicPartition(topic='store3.drinks', partition=0), TopicPartition(topic='store3.orders', partition=0), TopicPartition(topic='store4.drinks', partition=0), TopicPartition(topic='store4.orders', partition=0)]
INFO:kafka.coordinator.consumer:Setting newly assigned partitions {TopicPartition(topic='store4.drinks', partition=0), TopicPartition(topic='store4.orders', partition=0), TopicPartition(topic='store2.orders', partition=0), TopicPartition(topic='store2.drinks', partition=0), TopicPartition(topic='store3.orders', partition=0), TopicPartition(topic='store3.drinks', partition=0), TopicPartition(topic='store1.orders', partition=0), TopicPartition(topic='store1.drinks', partition=0)} for group 46673445-fb77-4f0f-8b54-6ea8a25d7652
INFO:kafka.conn:<BrokerConnection node_id=2 host=pizza-kafka-2.pizza-kafka-brokers.kafka.svc:9092 <connecting> [IPv4 ('172.30.30.213', 9092)]>: connecting to pizza-kafka-2.pizza-kafka-brokers.kafka.svc:9092 [('172.30.30.213', 9092) IPv4]
INFO:kafka.conn:<BrokerConnection node_id=2 host=pizza-kafka-2.pizza-kafka-brokers.kafka.svc:9092 <connecting> [IPv4 ('172.30.30.213', 9092)]>: Connection complete.
INFO:kafka.conn:<BrokerConnection node_id=0 host=pizza-kafka-0.pizza-kafka-brokers.kafka.svc:9092 <connecting> [IPv4 ('172.30.66.59', 9092)]>: connecting to pizza-kafka-0.pizza-kafka-brokers.kafka.svc:9092 [('172.30.66.59', 9092) IPv4]
INFO:kafka.conn:<BrokerConnection node_id=0 host=pizza-kafka-0.pizza-kafka-brokers.kafka.svc:9092 <connecting> [IPv4 ('172.30.66.59', 9092)]>: Connection complete.
```
