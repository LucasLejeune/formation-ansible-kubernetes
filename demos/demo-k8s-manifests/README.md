# Démo 3 — Kubernetes : Manifests déclaratifs avec k3d

## Objectif pédagogique

Comprendre l'approche **déclarative** de Kubernetes : on décrit l'état désiré dans des fichiers YAML, et le cluster réconcilie continuellement l'état réel vers cet état cible. Illustrer le cycle complet : création de cluster, déploiement, scaling, idempotence, accès réseau, et nettoyage.

## Prérequis

| Outil | Version minimale | Vérification |
|-------|-----------------|--------------|
| Docker | 20+ | `docker version` |
| k3d | 5+ | `k3d version` |
| kubectl | 1.27+ | `kubectl version --client` |

```bash
# Installation de k3d (si absent)
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Installation de kubectl (si absent)
# macOS
brew install kubectl
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/
```

## Structure de la démo

```
demo-k8s-manifests/
├── README.md
├── demo.sh
└── manifests/
    ├── namespace.yaml     # Namespace "demo"
    ├── deployment.yaml    # Deployment nginx:alpine — 2 réplicas
    └── service.yaml       # Service ClusterIP
```

## Lancement

```bash
chmod +x demo.sh
./demo.sh
```

Ou étape par étape :

```bash
# Créer le cluster
k3d cluster create demo --port "8088:80@loadbalancer"

# Appliquer les manifests
kubectl apply -f manifests/

# Observer
kubectl get all -n demo
kubectl rollout status deployment/webserver -n demo

# Scaler
kubectl scale deployment/webserver --replicas=4 -n demo

# Ré-appliquer (idempotence déclarative — retour à 2 réplicas)
kubectl apply -f manifests/
kubectl rollout status deployment/webserver -n demo

# Accès temporaire
kubectl port-forward svc/webserver 9090:80 -n demo
# Dans un autre terminal : curl http://localhost:9090

# Nettoyage
k3d cluster delete demo
```

## Déroulé pas-à-pas

### Étape 1 : Création du cluster k3d

k3d est un wrapper qui fait tourner k3s (Kubernetes allégé) dans des conteneurs Docker.

```bash
k3d cluster create demo --port "8088:80@loadbalancer"
```

- `demo` : nom du cluster
- `--port "8088:80@loadbalancer"` : mappe le port 8088 de la machine hôte sur le port 80 du loadbalancer du cluster

k3d met automatiquement à jour le `~/.kube/config` pour pointer sur le nouveau cluster.

### Étape 2 : Application des manifests

```bash
kubectl apply -f manifests/
```

Kubernetes applique les 3 fichiers YAML dans l'ordre (namespace d'abord, car les autres en dépendent). Les objets créés :

| Objet | Fichier | Rôle |
|-------|---------|------|
| Namespace `demo` | namespace.yaml | Isolation logique |
| Deployment `webserver` | deployment.yaml | Gestion des pods |
| Service `webserver` | service.yaml | Accès réseau stable |

### Étape 3 : Surveillance du rollout

```bash
kubectl rollout status deployment/webserver -n demo
```

Attend que tous les pods soient en état `Ready` (readinessProbe verte). Bloque jusqu'à succès ou timeout.

### Étape 4 : Scaling

```bash
kubectl scale deployment/webserver --replicas=4 -n demo
```

Commande impérative de scaling. On peut aussi modifier `replicas: 4` dans `deployment.yaml` et relancer `kubectl apply`.

### Étape 5 : Idempotence déclarative

Relancer `kubectl apply -f manifests/` avec `replicas: 2` ramène à 2 pods. Kubernetes supprime les 2 pods en excès. C'est la **réconciliation** : l'état réel est continuellement aligné sur l'état déclaré.

### Étape 6 : Accès via port-forward

```bash
kubectl port-forward svc/webserver 9090:80 -n demo
```

Crée un tunnel temporaire depuis `localhost:9090` vers le Service ClusterIP. Utile en dev/debug. En production, on utilise :
- **Ingress** : reverse proxy HTTP(S) avec routage par domaine/chemin
- **Service NodePort** : expose sur un port fixe de chaque nœud
- **Service LoadBalancer** : provisionne un LB externe (cloud)

## Points pédagogiques à souligner

### Déclaratif vs Impératif

| Approche | Exemple | Avantage |
|----------|---------|---------|
| Impérative | `kubectl run nginx --image=nginx` | Rapide pour tester |
| Déclarative | `kubectl apply -f deployment.yaml` | Versionnable, reproductible, idempotent |

En production, on utilise **toujours** l'approche déclarative (fichiers YAML en git).

### Réconciliation continue

Le **controller loop** Kubernetes :
1. Observe l'état réel (pods en cours d'exécution)
2. Compare avec l'état désiré (replicas: 2 dans le Deployment)
3. Agit si différence (crée ou supprime des pods)

Ce loop tourne **en permanence**. Si un pod plante, Kubernetes en recrée automatiquement un — sans intervention humaine.

### Structure d'un manifest

Tout manifest Kubernetes contient 4 champs de base :
```yaml
apiVersion: apps/v1     # Version de l'API K8s
kind: Deployment        # Type d'objet
metadata:               # Identité (nom, namespace, labels)
  name: webserver
  namespace: demo
spec:                   # État désiré — varie selon le kind
  replicas: 2
```

### Labels et selectors

Les labels permettent de lier les objets entre eux :
- Le **Service** sélectionne les pods via `selector: app: webserver`
- Le **Deployment** gère les pods avec `matchLabels: app: webserver`
- Les pods reçoivent le label `app: webserver` dans leur template

## Résultat attendu

```
$ kubectl get all -n demo
NAME                             READY   STATUS    RESTARTS   AGE
pod/webserver-xxx-yyy            1/1     Running   0          1m
pod/webserver-xxx-zzz            1/1     Running   0          1m

NAME                TYPE        CLUSTER-IP     PORT(S)   AGE
service/webserver   ClusterIP   10.43.x.x      80/TCP    1m

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/webserver   2/2     2            2           1m

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/webserver-xxx          2         2         2       1m
```

## Nettoyage

```bash
k3d cluster delete demo
```

Supprime le cluster et tous les conteneurs Docker associés.
