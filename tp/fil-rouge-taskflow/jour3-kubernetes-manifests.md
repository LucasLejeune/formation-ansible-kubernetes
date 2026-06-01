# TP Jour 3 : Déploiement Kubernetes avec des manifests YAML

> **Durée** : ~2h | **Objectif** : Créer un cluster k3d local, importer l'image Docker de TaskFlow, écrire les six manifests Kubernetes (namespace, configmap, deployment, service, ingress, secret), les appliquer avec `kubectl` et accéder à l'application via un Ingress.

---

## Prérequis

- Docker installé et actif (`docker info` fonctionne)
- k3d installé (`k3d version`)
- kubectl installé (`kubectl version --client`)
- TP Jour 1 et Jour 2 terminés (l'application TaskFlow est buildable)
- Node.js >= 18 disponible (pour builder l'image)

Consultez [`../../ressources/setup-lab.md`](../../ressources/setup-lab.md) si l'un de ces outils n'est pas installé.

---

## Étape 1 : Construire l'image Docker (20 min)

### 1.1 Vérifier le Dockerfile

Le `Dockerfile` multi-stage est déjà fourni dans le starter. Il utilise :
- **Stage 1** (`builder`) : `node:20-alpine` pour installer les dépendances et builder le projet Vite
- **Stage 2** (production) : `nginx:alpine` pour servir les fichiers statiques

### 1.2 Construire l'image

Depuis la racine du projet (là où se trouve le `Dockerfile`) :

```bash
docker build -t taskflow:1.0.0 .
```

**Résultat attendu :**

```
[+] Building 45.3s (12/12) FINISHED
 => [internal] load build definition from Dockerfile
 => [builder 1/4] FROM docker.io/library/node:20-alpine
 => [builder 3/4] RUN npm ci
 => [builder 4/4] RUN npm run build
 => [stage-1 2/2] COPY --from=builder /app/dist /usr/share/nginx/html
 => exporting to image
 => => naming to docker.io/library/taskflow:1.0.0
```

### 1.3 Tester l'image localement (optionnel)

```bash
docker run --rm -d -p 8080:80 --name taskflow-test taskflow:1.0.0
curl http://localhost:8080
docker stop taskflow-test
```

---

## Étape 2 : Créer le cluster k3d (15 min)

### 2.1 Créer le cluster avec mapping de port

```bash
k3d cluster create taskflow --port "8080:80@loadbalancer"
```

> L'option `--port "8080:80@loadbalancer"` mappe le port 80 du LoadBalancer k3d sur le port 8080 de votre machine. Toutes les requêtes HTTP arrivant sur `localhost:8080` seront routées vers l'Ingress controller.

**Résultat attendu :**

```
INFO[0000] Prep: Network
INFO[0000] Created network 'k3d-taskflow'
INFO[0001] Created image volume k3d-taskflow-images
INFO[0001] Starting new tools node...
INFO[0007] Starting Node 'k3d-taskflow-server-0'
INFO[0012] All agents already running.
INFO[0012] All helpers already running.
INFO[0013] Cluster 'taskflow' created successfully!
```

### 2.2 Vérifier le cluster

```bash
kubectl get nodes
```

**Résultat attendu :**

```
NAME                     STATUS   ROLES                  AGE   VERSION
k3d-taskflow-server-0    Ready    control-plane,master   30s   v1.29.x+k3s1
```

### 2.3 Importer l'image dans k3d

k3d fait tourner k3s dans Docker. Il ne partage **pas** le cache Docker du démon local : il faut importer l'image explicitement.

```bash
k3d image import taskflow:1.0.0 -c taskflow
```

**Résultat attendu :**

```
INFO[0000] Importing image(s) into cluster 'taskflow'...
INFO[0009] Successfully imported image(s) into cluster 'taskflow'
```

---

## Étape 3 : Écrire les manifests Kubernetes (50 min)

Créez les fichiers suivants dans le dossier `k8s/` (à la racine du projet).

### 3.1 `k8s/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: taskflow
  labels:
    app: taskflow
    env: lab
```

### 3.2 `k8s/configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: taskflow-config
  namespace: taskflow
data:
  APP_ENV: "production"
  APP_TITLE: "TaskFlow - Lab Kubernetes"
```

### 3.3 `k8s/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: taskflow
  namespace: taskflow
  labels:
    app: taskflow
spec:
  replicas: 2
  selector:
    matchLabels:
      app: taskflow
  template:
    metadata:
      labels:
        app: taskflow
    spec:
      containers:
        - name: taskflow
          image: taskflow:1.0.0
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: taskflow-config
```

> `imagePullPolicy: IfNotPresent` est essentiel : il indique à Kubernetes d'utiliser l'image locale importée via k3d, sans essayer de la télécharger depuis un registry.

### 3.4 `k8s/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: taskflow
  namespace: taskflow
  labels:
    app: taskflow
spec:
  type: ClusterIP
  selector:
    app: taskflow
  ports:
    - name: http
      port: 80
      targetPort: 80
```

### 3.5 `k8s/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: taskflow
  namespace: taskflow
  labels:
    app: taskflow
spec:
  rules:
    - host: taskflow.localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: taskflow
                port:
                  number: 80
```

### 3.6 `k8s/secret.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: taskflow-secret
  namespace: taskflow
type: Opaque
stringData:
  API_TOKEN: "dev-token-please-change"
```

> Note : un Secret Kubernetes n'est **pas** chiffré, il est encodé en base64. Ne committez jamais de vraies valeurs dans un Secret en clair. La gestion sécurisée des secrets via Ansible Vault est l'objet du Jour 5.

---

## Étape 4 : Appliquer les manifests et vérifier (15 min)

### 4.1 Appliquer tous les manifests

```bash
kubectl apply -f k8s/
```

**Résultat attendu :**

```
namespace/taskflow created
configmap/taskflow-config created
deployment.apps/taskflow created
service/taskflow created
ingress.networking.k8s.io/taskflow created
secret/taskflow-secret created
```

### 4.2 Vérifier que les deux pods sont en état Running

```bash
kubectl get pods -n taskflow
```

**Résultat attendu (attendre ~30 secondes) :**

```
NAME                        READY   STATUS    RESTARTS   AGE
taskflow-6c7d4b9f8c-abc12   1/1     Running   0          45s
taskflow-6c7d4b9f8c-def34   1/1     Running   0          45s
```

### 4.3 Vérifier l'ensemble des ressources

```bash
kubectl get all -n taskflow
```

**Résultat attendu :**

```
NAME                            READY   STATUS    RESTARTS   AGE
pod/taskflow-6c7d4b9f8c-abc12   1/1     Running   0          2m
pod/taskflow-6c7d4b9f8c-def34   1/1     Running   0          2m

NAME               TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/taskflow   ClusterIP   10.43.12.34    <none>        80/TCP    2m

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/taskflow   2/2     2            2           2m

NAME                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/taskflow-6c7d4b9f8c   2         2         2       2m
```

### 4.4 Accéder à TaskFlow via l'Ingress

```bash
curl http://taskflow.localhost:8080
```

Si le DNS `taskflow.localhost` ne se résout pas automatiquement, ajoutez temporairement une entrée dans `/etc/hosts` :

```bash
echo "127.0.0.1 taskflow.localhost" | sudo tee -a /etc/hosts
```

**Résultat attendu :** le HTML de l'application TaskFlow s'affiche.

Vous pouvez également ouvrir `http://taskflow.localhost:8080` dans votre navigateur.

---

## Checklist de validation

- [ ] `docker build -t taskflow:1.0.0 .` s'est terminé sans erreur
- [ ] `k3d cluster list` montre le cluster `taskflow` en état `running`
- [ ] `k3d image import taskflow:1.0.0 -c taskflow` s'est terminé sans erreur
- [ ] Les 6 fichiers YAML existent dans le dossier `k8s/` (namespace, configmap, deployment, service, ingress, secret)
- [ ] `kubectl apply -f k8s/` ne retourne aucun `error`
- [ ] `kubectl get pods -n taskflow` affiche 2 pods en état `Running`
- [ ] `curl http://taskflow.localhost:8080` retourne du HTML contenant TaskFlow
- [ ] `kubectl get ingress -n taskflow` affiche l'Ingress avec l'host `taskflow.localhost`

---

## Erreurs courantes

**Les pods restent en état `ImagePullBackOff` ou `ErrImageNeverPull`**
L'image n'a pas été importée dans k3d. Relancez `k3d image import taskflow:1.0.0 -c taskflow`. Vérifiez aussi que `imagePullPolicy: IfNotPresent` est bien dans le Deployment.

**`curl http://taskflow.localhost:8080` retourne `connection refused`**
Vérifiez que le cluster k3d est bien démarré (`k3d cluster list`) et que le port 8080 est bien mappé (`docker ps | grep k3d`). Le mapping se fait uniquement au moment de la création du cluster avec `--port "8080:80@loadbalancer"`.

**`kubectl apply` retourne `Error from server (NotFound): namespaces "taskflow" not found`**
Appliquez d'abord le namespace seul : `kubectl apply -f k8s/namespace.yaml`, puis relancez `kubectl apply -f k8s/`.

**`Error: no objects passed to apply`**
Vérifiez que vos fichiers YAML ont bien l'extension `.yaml` (et non `.yml` dans certains cas) et qu'ils sont dans le dossier `k8s/`.

---

## Ressources

- [Documentation Kubernetes — Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Documentation Kubernetes — Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Documentation Kubernetes — Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Documentation Kubernetes — ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Documentation Kubernetes — Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Documentation k3d](https://k3d.io/v5.6.0/)

---

**Prochain TP** : [Jour 4 — Automatisation K8s avec Ansible](./jour4-automatisation-k8s-ansible.md)
