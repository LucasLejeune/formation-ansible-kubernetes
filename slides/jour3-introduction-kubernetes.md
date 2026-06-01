---
marp: true
theme: uncover
paginate: true
footer: M2 ESTD - DevOps Ansible & Kubernetes | ForEach Academy
style: |
  section {
    font-size: 20px;
    padding: 40px 50px;
  }
  h1 { font-size: 36px; color: #326CE5; margin: 0 0 15px 0; }
  h2 { font-size: 28px; color: #1e4fa0; margin: 0 0 12px 0; }
  h3 { font-size: 24px; color: #3b82f6; margin: 0 0 10px 0; }
  code { font-size: 18px; background: #f3f4f6; padding: 1px 4px; border-radius: 4px; }
  table { font-size: 16px; }
  blockquote { border-left: 4px solid #3b82f6; padding-left: 15px; font-style: italic; color: #4b5563; margin: 10px 0; font-size: 18px; }
  ul { margin: 10px 0; padding-left: 25px; }
  li { margin-bottom: 5px; line-height: 1.3; }
  pre { font-size: 15px; padding: 20px; margin: 15px 0; background: #1e1e1e !important; border-radius: 8px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1); }
  pre code { background: transparent !important; color: #d4d4d4; font-size: 15px; }
  .columns { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
---

<!-- _class: lead -->

# Jour 3 — Introduction à Kubernetes

### M2 DevOps · Ansible & Kubernetes
**ForEach Academy** · Formateur : Fabrice Claeys

---

## Programme du Jour 3

| # | Horaire | Contenu |
|---|---------|---------|
| 1 | 08h30 – 09h00 | Du conteneur unique à l'orchestration |
| 2 | 09h00 – 10h00 | Architecture Kubernetes |
| 3 | 10h00 – 10h30 | Modèle déclaratif & réconciliation |
| 4 | 10h30 – 11h00 | k3d — cluster local, kubectl |
| 5 | 11h00 – 12h30 | Ressources : Pod, Deployment, Service |
| 6 | 13h30 – 14h30 | ConfigMap, Ingress, workflow complet |
| 7 | 14h30 – 15h00 | Démo live |
| 8 | 15h00 – 17h30 | **TP3** — TaskFlow sur Kubernetes |

---

<!-- _class: lead -->

## Partie 1 — Du conteneur unique à l'orchestration

---

## Rappel — Ce que Docker nous apporte

- **Isolation** : chaque service dans son propre conteneur
- **Reproductibilité** : même image = même comportement partout
- **Portabilité** : fonctionne sur dev, CI, prod sans friction
- **Légèreté** : démarrage en secondes vs. minutes pour une VM

> On maîtrise maintenant le cycle image → conteneur. Mais en production, ça ne suffit pas.

---

## Les limites de `docker run` en production

<div class="columns">

<div>

**Résilience**
- Un conteneur crashe → il reste arrêté
- Pas de redémarrage automatique fiable

**Scaling**
- Lancer 10 instances à la main ?
- Équilibrage de charge manuel

</div>

<div>

**Déploiements**
- Mise à jour sans interruption de service ?
- Rollback en cas de problème ?

**Réseau & découverte**
- IP d'un conteneur change à chaque redémarrage
- Comment les services se trouvent-ils ?

</div>

</div>

---

## Le besoin : un orchestrateur

> Un orchestrateur gère automatiquement le cycle de vie de **plusieurs conteneurs** sur **plusieurs machines**, garantissant l'état souhaité en permanence.

**Ce qu'on attend :**
- Démarrer / redémarrer les conteneurs automatiquement
- Répartir la charge entre instances
- Mettre à jour sans coupure (rolling update)
- Exposer les services via un réseau stable
- Gérer la configuration et les secrets

---

<!-- _class: lead -->

## Partie 2 — Qu'est-ce que Kubernetes ?

---

## Kubernetes en une phrase

> **Kubernetes** (K8s) est un système open-source d'**orchestration de conteneurs** qui automatise le déploiement, le scaling et la gestion des applications conteneurisées.

**Principes fondamentaux :**
- **Déclaratif** : vous décrivez *ce que vous voulez*, K8s fait *en sorte que ça soit vrai*
- **Auto-réparation** : un Pod mort est recréé automatiquement
- **Scaling** : horizontal, manuel ou automatique (HPA)
- **Rolling updates** : zéro downtime par défaut
- **Extensible** : CRD, opérateurs, plugins réseau…

---

## Historique & écosystème

**Origines**
- Né chez Google (inspiré de **Borg**, système interne depuis 2003)
- Open-sourcé en **2014**, donné à la **CNCF** en 2016
- Aujourd'hui : projet le plus actif de la CNCF

**Adoption**
- Standard de facto pour l'orchestration en production
- Support natif : AWS (EKS), GCP (GKE), Azure (AKS), OVH, Scaleway…
- Toutes les grandes entreprises tech l'utilisent

---

<!-- _class: lead -->

## Partie 3 — Architecture Kubernetes

---

## Vue d'ensemble du cluster

```
┌─────────────────────────────────────────────────────┐
│                    CLUSTER K8s                       │
│                                                      │
│  ┌──────────────────────────┐                        │
│  │      CONTROL PLANE       │                        │
│  │  kube-apiserver          │                        │
│  │  etcd                    │                        │
│  │  kube-scheduler          │                        │
│  │  kube-controller-manager │                        │
│  └──────────────────────────┘                        │
│                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │  WORKER  1  │  │  WORKER  2  │  │  WORKER  N  │  │
│  │  kubelet    │  │  kubelet    │  │  kubelet    │  │
│  │  kube-proxy │  │  kube-proxy │  │  kube-proxy │  │
│  │  runtime    │  │  runtime    │  │  runtime    │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────┘
```

---

## Le Control Plane

| Composant | Rôle |
|-----------|------|
| **kube-apiserver** | Point d'entrée unique (REST API). Tout passe par lui. |
| **etcd** | Base de données clé-valeur distribuée. Source de vérité du cluster. |
| **kube-scheduler** | Décide sur quel nœud placer un nouveau Pod. |
| **kube-controller-manager** | Boucles de contrôle : ReplicaSet, Node, Endpoint… |

> Le Control Plane ne fait **jamais** tourner vos workloads directement.

---

## Les Worker Nodes

| Composant | Rôle |
|-----------|------|
| **kubelet** | Agent sur chaque nœud. Reçoit les ordres du Control Plane, crée les conteneurs. |
| **kube-proxy** | Gère les règles réseau (iptables/IPVS). Permet l'accès aux Services. |
| **Container runtime** | Exécute vraiment les conteneurs (containerd, CRI-O). |

**En résumé :**
- Control Plane = cerveau
- Worker Node = bras

---

<!-- _class: lead -->

## Partie 4 — Le modèle déclaratif

---

## État désiré vs état réel

```
   Vous écrivez un manifest YAML
           │
           ▼
   kubectl apply -f deploy.yaml
           │
           ▼
   kube-apiserver stocke dans etcd
           │
           ▼
   Controller observe l'écart :
     Désiré : 3 replicas
     Réel   : 1 replica  ← écart !
           │
           ▼
   Scheduler place 2 nouveaux Pods
           │
           ▼
   kubelet crée les conteneurs
           │
           ▼
   Réel = Désiré ✓
```

---

## La boucle de réconciliation

> Kubernetes surveille **en permanence** l'état réel et le compare à l'état désiré. Tout écart est corrigé automatiquement.

**Exemples concrets :**
- Un Pod crashe → recréé automatiquement
- Un nœud tombe → Pods replanifiés sur un autre nœud
- Vous changez le nombre de replicas → K8s ajuste

**Ce que ça implique pour vous :**
- Ne jamais modifier l'état directement sur les nœuds
- Toujours passer par `kubectl apply` sur vos manifests
- Le YAML est votre source de vérité → versionner dans Git

---

<!-- _class: lead -->

## Partie 5 — Cluster local avec k3d

---

## Distributions locales K8s

| Outil | Description | Usage |
|-------|-------------|-------|
| **minikube** | VM ou Docker, officiel K8s | Polyvalent, lourd |
| **kind** | K8s in Docker, orienté CI | Tests automatisés |
| **k3s** | K8s allégé (Rancher/SUSE) | Edge, IoT, prod légère |
| **k3d** | k3s **dans Docker** | Développement local |

**Pourquoi k3d dans cette formation ?**
- S'appuie sur Docker que vous maîtrisez déjà
- Cluster créé en **< 30 secondes**
- Léger, multi-clusters possible
- Traefik Ingress Controller inclus par défaut

---

## Installation — k3d et kubectl

```bash
# Installer k3d (Linux/macOS)
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Vérifier k3d
k3d version

# Installer kubectl (Linux)
curl -LO "https://dl.k8s.io/release/$(curl -L -s \
  https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Vérifier kubectl
kubectl version --client
```

---

## Créer et gérer un cluster k3d

```bash
# Créer un cluster nommé "dev"
k3d cluster create dev

# Lister les clusters
k3d cluster list

# Arrêter / démarrer
k3d cluster stop dev
k3d cluster start dev

# Supprimer
k3d cluster delete dev

# Vérifier les nœuds du cluster
kubectl get nodes
```

---

<!-- _class: lead -->

## Partie 6 — kubectl : votre outil quotidien

---

## Configuration kubectl

```bash
# Le fichier de configuration (~/.kube/config)
kubectl config view

# Lister les contextes disponibles
kubectl config get-contexts

# Changer de contexte (changer de cluster)
kubectl config use-context k3d-dev

# Vérifier le contexte actif
kubectl config current-context
```

> k3d configure automatiquement `~/.kube/config` lors de la création du cluster.

---

## Commandes kubectl essentielles

```bash
# Lister des ressources
kubectl get pods
kubectl get pods -n kube-system      # dans un namespace spécifique
kubectl get all -n monapp            # toutes les ressources

# Détails d'une ressource
kubectl describe pod mon-pod

# Créer/mettre à jour depuis un fichier
kubectl apply -f manifest.yaml
kubectl apply -f k8s/                # tout un dossier

# Supprimer
kubectl delete -f manifest.yaml
kubectl delete pod mon-pod

# Logs et exécution
kubectl logs mon-pod
kubectl exec -it mon-pod -- /bin/sh
```

---

<!-- _class: lead -->

## Partie 7 — Les ressources Kubernetes

---

## Namespaces — isolation logique

> Un **Namespace** est un espace de noms virtuel qui isole les ressources au sein d'un même cluster.

```bash
# Namespaces par défaut
kubectl get namespaces
# default, kube-system, kube-public, kube-node-lease
```

**Manifest Namespace :**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: taskflow
```

```bash
kubectl apply -f namespace.yaml
kubectl get ns
```

---

## Pod — la plus petite unité

> Un **Pod** est un groupe d'un ou plusieurs conteneurs partageant le même réseau et le même stockage. C'est l'unité déployable minimale de K8s.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: taskflow-pod
  namespace: taskflow
spec:
  containers:
    - name: taskflow
      image: taskflow:1.0.0
      ports:
        - containerPort: 80
```

**Pourquoi ne pas créer des Pods directement ?**
- Un Pod est **éphémère** : s'il meurt, il n'est pas recréé
- On utilise toujours un **Deployment** (ou autre contrôleur)

---

## ReplicaSet — maintien du nombre d'instances

> Un **ReplicaSet** garantit qu'un nombre précis de Pods identiques tourne en permanence.

- Surveille les Pods via les **labels**
- Recrée un Pod si l'un d'eux disparaît
- **Rarement utilisé directement** : géré par le Deployment

```
ReplicaSet (replicas: 3)
  ├── Pod taskflow-abc12
  ├── Pod taskflow-def34
  └── Pod taskflow-ghi56
```

---

## Deployment — la ressource de référence

> Un **Deployment** gère des ReplicaSets et permet les mises à jour déclaratives (rolling update) et les rollbacks.

**Ce qu'il apporte en plus du ReplicaSet :**
- Historique des révisions
- Rolling update sans downtime
- Rollback en une commande

---

## Manifest Deployment — TaskFlow

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: taskflow
  namespace: taskflow
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
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: taskflow-config
```

---

## Rolling update & rollback

```bash
# Mettre à jour l'image d'un déploiement
kubectl set image deployment/taskflow taskflow=taskflow:2.0.0 -n taskflow

# Suivre le rollout
kubectl rollout status deployment/taskflow -n taskflow

# Voir l'historique
kubectl rollout history deployment/taskflow -n taskflow

# Rollback à la révision précédente
kubectl rollout undo deployment/taskflow -n taskflow
```

---

## Service — adresse stable pour vos Pods

> Les Pods ont des IPs éphémères. Un **Service** fournit une adresse stable (ClusterIP) et fait du load balancing vers les Pods correspondants.

**Types de Service :**

| Type | Accès | Usage |
|------|-------|-------|
| **ClusterIP** | Interne au cluster uniquement | Communication inter-services |
| **NodePort** | Port fixe sur chaque nœud | Dev/test, accès direct |
| **LoadBalancer** | IP externe (cloud) | Production cloud |

---

## Manifest Service ClusterIP

```yaml
apiVersion: v1
kind: Service
metadata:
  name: taskflow
  namespace: taskflow
spec:
  selector:
    app: taskflow       # cible les Pods avec ce label
  ports:
    - protocol: TCP
      port: 80          # port du Service
      targetPort: 80    # port du conteneur
  type: ClusterIP
```

```bash
kubectl apply -f service.yaml
kubectl get svc -n taskflow
```

---

## Labels & Selectors — le ciment de K8s

> Les **labels** sont des paires clé/valeur attachées aux ressources. Les **selectors** permettent de filtrer et de relier les ressources entre elles.

```yaml
# Pod avec un label
metadata:
  labels:
    app: taskflow
    version: "1.0.0"
    env: production

# Service qui cible ces Pods
spec:
  selector:
    app: taskflow       # doit correspondre exactement
```

**Règle d'or :** le `selector` du Service doit matcher les `labels` du Pod template du Deployment.

---

## ConfigMap — configuration non sensible

> Un **ConfigMap** stocke des données de configuration (variables d'env, fichiers de config) séparément de l'image.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: taskflow-config
  namespace: taskflow
data:
  APP_ENV: "production"
  APP_PORT: "80"
  LOG_LEVEL: "info"
```

```yaml
# Dans le Deployment, envFrom charge toutes les clés comme variables d'env
envFrom:
  - configMapRef:
      name: taskflow-config
```

> **Secret** = même principe pour les données sensibles (J5).

---

## Ingress — exposer en HTTP(S)

> Un **Ingress** définit des règles de routage HTTP vers des Services internes. Il nécessite un **Ingress Controller** (Traefik fourni par k3d).

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: taskflow
  namespace: taskflow
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

---

## Ingress — accès depuis la machine locale

```bash
# Vérifier que le contrôleur Traefik est actif
kubectl get pods -n kube-system | grep traefik

# Lister les Ingress
kubectl get ingress -n taskflow

# Avec k3d, le port 80 est exposé sur localhost
# Ajouter dans /etc/hosts si nécessaire :
# 127.0.0.1  taskflow.localhost

curl http://taskflow.localhost
```

> k3d expose automatiquement le port 80 du Traefik Ingress Controller sur `localhost`.

---

## Workflow déclaratif complet

```bash
# Structure recommandée
k8s/
├── namespace.yaml
├── configmap.yaml
├── deployment.yaml
├── service.yaml
└── ingress.yaml

# Appliquer tout le dossier en une commande
kubectl apply -f k8s/

# Vérifier l'état
kubectl get all -n taskflow

# Détailler un Pod
kubectl describe pod -l app=taskflow -n taskflow

# Voir les logs
kubectl logs -l app=taskflow -n taskflow
```

---

<!-- _class: lead -->

## Partie 8 — Démo live

### Cluster k3d → Deploy TaskFlow → Accès navigateur

---

## Démo — étapes

```bash
# 1. Créer le cluster k3d avec exposition du port 80
k3d cluster create demo \
  --port "80:80@loadbalancer" \
  --port "443:443@loadbalancer"

# 2. Vérifier les nœuds
kubectl get nodes

# 3. Appliquer les manifests
kubectl apply -f k8s/

# 4. Suivre le démarrage des Pods
kubectl get pods -n taskflow -w

# 5. Port-forward pour tester sans Ingress
kubectl port-forward svc/taskflow 8080:80 -n taskflow

# 6. Ouvrir http://localhost:8080
```

---

## Démo — vérifications attendues

```bash
# Pods : 2 Running
kubectl get pods -n taskflow
# NAME                        READY   STATUS    RESTARTS   AGE
# taskflow-7d9f8b6c4-kx2p9   1/1     Running   0          30s
# taskflow-7d9f8b6c4-mw7tn   1/1     Running   0          30s

# Service ClusterIP créé
kubectl get svc -n taskflow
# NAME       TYPE        CLUSTER-IP     PORT(S)   AGE
# taskflow   ClusterIP   10.43.12.34    80/TCP    45s

# Ingress configuré
kubectl get ingress -n taskflow
# NAME       CLASS     HOSTS                ADDRESS     PORTS
# taskflow   traefik   taskflow.localhost   127.0.0.1   80
```

---

<!-- _class: lead -->

## TP3 — Déployer TaskFlow sur Kubernetes

### Objectif : du Dockerfile au cluster k3d

---

## TP3 — Vue d'ensemble

**Ce que vous allez faire :**

1. Écrire un **Dockerfile multi-stage** pour TaskFlow (build + `nginx:alpine`)
2. Builder l'image `taskflow:1.0.0`
3. Créer un **cluster k3d** avec port 80 exposé
4. **Importer** l'image locale dans k3d (`k3d image import`)
5. Écrire les **5 manifests** YAML dans `k8s/`
6. Déployer avec `kubectl apply -f k8s/`
7. Vérifier **2 Pods Running** + accès `http://taskflow.localhost`

---

## TP3 — Étape 1 : Dockerfile multi-stage

```dockerfile
# Stage 1 : build de l'application
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2 : serveur nginx léger
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

```bash
# Builder l'image
docker build -t taskflow:1.0.0 .

# Vérifier
docker images | grep taskflow
```

---

## TP3 — Étape 2 : Cluster k3d + import image

```bash
# Créer le cluster avec Traefik sur le port 80
k3d cluster create taskflow-dev \
  --port "80:80@loadbalancer" \
  --port "443:443@loadbalancer"

# Vérifier le cluster
kubectl get nodes
# NAME                          STATUS   ROLES
# k3d-taskflow-dev-server-0    Ready    control-plane,master

# Importer l'image locale dans k3d
# (sans ça, k3d ne trouve pas l'image sur le DockerHub)
k3d image import taskflow:1.0.0 -c taskflow-dev

# Vérifier l'import
docker exec k3d-taskflow-dev-server-0 crictl images | grep taskflow
```

---

## TP3 — Étape 3 : Les manifests YAML

**Créer le dossier `k8s/` à la racine du projet :**

```
k8s/
├── namespace.yaml      ← Namespace "taskflow"
├── configmap.yaml      ← APP_ENV, LOG_LEVEL
├── deployment.yaml     ← 2 replicas, image taskflow:1.0.0
├── service.yaml        ← ClusterIP port 80
└── ingress.yaml        ← host: taskflow.localhost
```

**Points d'attention :**
- `imagePullPolicy: IfNotPresent` dans le Deployment (image locale !)
- Labels cohérents entre Deployment, Service et Ingress
- Namespace `taskflow` dans chaque manifest

---

## TP3 — imagePullPolicy IfNotPresent

```yaml
# Dans le Deployment — IMPORTANT avec une image locale
spec:
  template:
    spec:
      containers:
        - name: taskflow
          image: taskflow:1.0.0
          imagePullPolicy: IfNotPresent    # utilise l'image locale importée
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: taskflow-config
```

> Avec `imagePullPolicy: IfNotPresent`, K8s utilise l'image locale importée via `k3d image import` et ne tente pas de la puller depuis Docker Hub (ce qui échouerait avec `ErrImagePull`).

---

## TP3 — Étape 4 : Déployer et vérifier

```bash
# Appliquer tous les manifests
kubectl apply -f k8s/

# Suivre le démarrage
kubectl get pods -n taskflow -w

# Critères de réussite
kubectl get all -n taskflow
# deployment.apps/taskflow   2/2     2            2
# replicaset.apps/taskflow-xxx   2         2         2
# pod/taskflow-xxx-yyy        1/1     Running

# Tester l'accès
curl http://taskflow.localhost
# ou ouvrir dans le navigateur
```

---

## TP3 — Commandes de debug

```bash
# Un Pod est en erreur ?
kubectl describe pod <nom-du-pod> -n taskflow
kubectl logs <nom-du-pod> -n taskflow

# Voir les events du namespace
kubectl get events -n taskflow --sort-by='.lastTimestamp'

# Vérifier la ConfigMap
kubectl get configmap taskflow-config -n taskflow -o yaml

# Vérifier le Service
kubectl get endpoints -n taskflow

# Vérifier l'Ingress
kubectl describe ingress taskflow -n taskflow
```

---

<!-- _class: lead -->

## Récapitulatif du Jour 3

---

## Ce que vous avez appris aujourd'hui

**Concepts :**
- Orchestration : pourquoi K8s répond aux limites de Docker seul
- Architecture : Control Plane (apiserver, etcd, scheduler) + Worker nodes (kubelet)
- Modèle déclaratif : état désiré → boucle de réconciliation

**Ressources K8s :**
- **Namespace** — isolation logique
- **Pod** → **Deployment** — unité de déploiement avec rolling update
- **Service** (ClusterIP) — adresse stable et load balancing
- **ConfigMap** — configuration externalisée
- **Ingress** — routage HTTP avec Traefik

**Outils :**
- `k3d` : cluster local sur Docker
- `kubectl` : apply, get, describe, logs, exec, rollout

---

## Les concepts clés à retenir

> "Vous décrivez **ce que vous voulez**. Kubernetes fait en sorte que ce soit **toujours vrai**."

**Règles d'or :**
1. Tout passe par `kubectl apply -f` — jamais de modifications manuelles
2. Versionnez vos manifests dans Git
3. `imagePullPolicy: IfNotPresent` pour les images locales en k3d
4. Labels cohérents entre Deployment, Service et Ingress
5. Un Namespace par application/environnement

**Demain (Jour 4) :** Persistance des données (PersistentVolume, PVC), Secrets, et déploiement de la stack complète TaskFlow avec base de données.

---

## Questions ?

<br>

**Fabrice Claeys**
Formateur DevOps — ForEach Academy

- GitHub : `github.com/fclaeys`
- Email : `claeys.fabrice@gmail.com`
- Slack de la formation : canal `#m2-devops`

<br>

> Les manifests du TP3 et les slides sont disponibles dans le dépôt Git de la formation.

---

<!-- _class: lead -->

# Bonne chance pour le TP3 !

### k3d cluster create → kubectl apply → 2 pods Running
