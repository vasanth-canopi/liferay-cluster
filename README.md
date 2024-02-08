# SCF - Liferay Cluster (Docker)

## 1. Services :

- **Liferay 7.1.2-GA3** (liferay/portal:7.1.2-ga3)
- **PostgreSQL 14** (postgres:14.8)
- **Elasticsearch** (docker.elastic.co/elasticsearch/elasticsearch:6.8.8)
- **HAProxy** *for sticky session* (haproxy:2.3.4)
- **PGAdmin** (pgadmin4:7.2)

## 2. Usage

```sh
docker compose up -d
```

### 2.1 Direcorty Structure

```sh
.
│   docker-compose.yml
│   Dockerfile-elasticsearch
│   Dockerfile-haproxy
│   Dockerfile-liferay
│   README.md
│
├───configs
│       com.liferay.portal.bundle.blacklist.internal.BundleBlacklistConfiguration.config
│       com.liferay.portal.cache.ehcache.multiple.jar
│       com.liferay.portal.cluster.multiple.jar
│       com.liferay.portal.scheduler.multiple.jar
│       com.liferay.portal.search.elasticsearch.configuration.ElasticsearchConfiguration.config
│       haproxy.cfg
│       portal-ext.properties
│       setenv.sh
│
└───tomcat-libs
        mysql.jar
        postgresql.jar
```

## 3. Details

| Service                  | Username            | Password         | Database  | Others                                 |
|--------------------------|---------------------|------------------|-----------|----------------------------------------------------|
| **liferay-portal-node-1**    | Not applicable     | Not applicable   | Not applicable| http://localhost:6080                                  |
| **liferay-portal-node-2**    | Not applicable     | Not applicable   | Not applicable| http://localhost:7080                                  |
| **postgres**                 | liferay             | password         | lportal   | PORT : 5432                                  |
| **es-node-1**                | Not applicable     | Not applicable   | Not applicable| HTTP_PORT:9200 , TRANSPORT_PORT:9300                                  |
| **pgadmin**                  | vasanth@canopi.in   | canopi_2023      | Not applicable| Access via web browser: http://localhost:8090     |
| **haproxy**                  | Not applicable     | Not applicable   | Not applicable| Access: http://localhost:80 (sticky session)|
| **redis**                  | Not applicable     | Not applicable   | Not applicable| Not implemented yet |

## 4. Session Affinity on Kubernetes
### (HAProxy sticky session solution won't work for kubernetes env)

### Note : Redis Session Management (Jedis for liferay) would be an idle way for session sharing issue on kubernetes env

<https://stackoverflow.com/questions/48993286/is-it-possible-to-route-traffic-to-a-specific-pod?rq=1>

You can guarantee session affinity with services, but not as you are describing.
So, your customers 1-1000 won't use pod-1,
but they will use all the pods (as a service makes a simple load balancing), 
but each customer, when gets back to hit your service, will be redirected to the same pod.

Note: always within time specified in (default 10800):

```text
service.spec.sessionAffinityConfig.clientIP.timeoutSeconds
```

This would be the yaml file of the service:

```yaml
kind: Service
apiVersion: v1
metadata:
  name: my-service
spec:
  selector:
    app: my-app
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
  sessionAffinity: ClientIP
```

If you want to specify time, as well, this is what needs to be added:

```yaml
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10
```

Note that the example above would work hitting ClusterIP type service directly (which is quite uncommon)
or with Loadbalancer type service, but won't with an Ingress behind NodePort type service.
This is because with an Ingress, the requests come from many, randomly chosen source IP addresses.
