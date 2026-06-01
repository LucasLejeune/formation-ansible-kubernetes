# Cheatsheet Kubernetes & k3d — M2 DevOps

> ForEach Academy — Formateur : Fabrice Claeys

---

## 1. k3d — Clusters locaux

### 1.1 Gestion de clusters

```bash
# Créer un cluster avec exposition du port 80
k3d cluster create taskflow --port "8080:80@loadbalancer"

# Créer avec plusieurs workers
k3d cluster create taskflow \
  --port "8080:80@loadbalancer" \
  --servers 1 \
  --agents 2

# Créer avec un kubeconfig dédié
k3d cluster create taskflow --kubeconfig-update-default

# Lister les clusters
k3d cluster list

# Démarrer / Arrêter
k3d cluster start taskflow
k3d cluster stop taskflow

# Supprimer
k3d cluster delete taskflow

# Informations détaillées
k3d cluster get taskflow
```

### 1.2 Importer une image locale dans k3d

```bash
# Importer une image Docker locale dans le cluster k3d
# (évite de pusher sur un registry pour le lab)
k3d image import taskflow:1.0.0 -c taskflow

# Vérifier que l'image est disponible dans le cluster
kubectl run test --image=taskflow:1.0.0 --image-pull-policy=Never --restart=Never
kubectl describe pod test | grep -A5 Events
kubectl delete pod test
```

> k3d utilise Docker Desktop comme runtime. L'image doit être présente dans Docker avant l'import k3d.

### 1.3 Nœuds et contexte

```bash
# Lister les nœuds k3d
k3d node list

# Obtenir le kubeconfig du cluster
k3d kubeconfig get taskflow

# Fusionner dans ~/.kube/config
k3d kubeconfig merge taskflow --kubeconfig-merge-default
```

---

## 2. kubectl — Configuration et contextes

```bash
# Voir la configuration complète
kubectl config view

# Lister les contextes disponibles
kubectl config get-contexts

# Contexte courant
kubectl config current-context

# Changer de contexte
kubectl config use-context k3d-taskflow

# Définir le namespace par défaut d'un contexte
kubectl config set-context --current --namespace=taskflow

# Vérifier la connexion au cluster
kubectl cluster-info

# Vérifier les droits (RBAC)
kubectl auth can-i create deployments --namespace=taskflow
```

---

## 3. kubectl — Commandes essentielles

### 3.1 get / describe

```bash
# Syntaxe générale
kubectl get <ressource> [-n <namespace>] [<nom>] [options]

# Exemples
kubectl get nodes
kubectl get pods -n taskflow
kubectl get pods -A                     # tous namespaces
kubectl get all -n taskflow             # pods, services, deployments...
kubectl get pods -o wide                # avec IP et nœud
kubectl get pods -o yaml                # manifeste complet en YAML
kubectl get pods -o json | jq .         # JSON + jq
kubectl get pods --watch                # mode temps réel
kubectl get pods -l app=taskflow        # filtre par label

# describe : détails + events
kubectl describe pod <nom> -n taskflow
kubectl describe deployment taskflow -n taskflow
kubectl describe service taskflow-svc -n taskflow
kubectl describe node k3d-taskflow-server-0
```

### 3.2 apply / delete

```bash
# Appliquer un manifeste (créer ou mettre à jour)
kubectl apply -f deployment.yml
kubectl apply -f manifests/            # dossier entier
kubectl apply -k ./kustomize/          # kustomize

# Supprimer
kubectl delete -f deployment.yml
kubectl delete pod <nom> -n taskflow
kubectl delete deployment taskflow -n taskflow
kubectl delete namespace taskflow      # supprime tout dans le namespace

# Forcer la suppression d'un pod bloqué
kubectl delete pod <nom> --grace-period=0 --force -n taskflow
```

### 3.3 Logs

```bash
# Logs d'un pod
kubectl logs <pod> -n taskflow
kubectl logs <pod> -n taskflow -c <container>   # multi-containers
kubectl logs <pod> --previous                    # container précédent (crash)
kubectl logs -f <pod>                            # mode follow (tail -f)
kubectl logs -f <pod> --tail=100                 # 100 dernières lignes
kubectl logs -l app=taskflow --all-containers    # tous les pods matchant le label
```

### 3.4 exec / shell

```bash
# Exécuter une commande dans un pod
kubectl exec -it <pod> -n taskflow -- bash
kubectl exec -it <pod> -n taskflow -- /bin/sh    # si pas de bash
kubectl exec <pod> -- cat /etc/nginx/nginx.conf

# Copier des fichiers
kubectl cp <pod>:/etc/nginx/nginx.conf ./nginx.conf
kubectl cp ./index.html <pod>:/usr/share/nginx/html/
```

### 3.5 Déploiements — gestion des rollouts

```bash
# Statut du rollout
kubectl rollout status deployment/taskflow -n taskflow

# Historique des révisions
kubectl rollout history deployment/taskflow -n taskflow

# Revenir en arrière (révision précédente)
kubectl rollout undo deployment/taskflow -n taskflow

# Revenir à une révision spécifique
kubectl rollout undo deployment/taskflow --to-revision=2 -n taskflow

# Forcer le redémarrage des pods (sans changer l'image)
kubectl rollout restart deployment/taskflow -n taskflow

# Mettre en pause / reprendre un rollout
kubectl rollout pause deployment/taskflow
kubectl rollout resume deployment/taskflow
```

### 3.6 Scaling

```bash
# Scaler manuellement
kubectl scale deployment taskflow --replicas=3 -n taskflow

# Autoscaling (HPA)
kubectl autoscale deployment taskflow --min=2 --max=5 --cpu-percent=80

# Vérifier le HPA
kubectl get hpa -n taskflow
```

### 3.7 Port-forward

```bash
# Exposer un pod localement
kubectl port-forward pod/<pod> 8888:80 -n taskflow

# Exposer un service
kubectl port-forward service/taskflow-svc 8888:80 -n taskflow

# En arrière-plan
kubectl port-forward service/taskflow-svc 8888:80 -n taskflow &
```

---

## 4. Objets Kubernetes — Manifestes minimaux

### 4.1 Namespace

```yaml
# namespace.yml
apiVersion: v1
kind: Namespace
metadata:
  name: taskflow
  labels:
    env: lab
```

```bash
kubectl apply -f namespace.yml
kubectl get namespaces
```

### 4.2 Pod

```yaml
# pod.yml
apiVersion: v1
kind: Pod
metadata:
  name: taskflow-pod
  namespace: taskflow
  labels:
    app: taskflow
    version: "1.0.0"
spec:
  containers:
    - name: taskflow
      image: taskflow:1.0.0
      imagePullPolicy: IfNotPresent    # image importée via k3d image import
      ports:
        - containerPort: 80
      resources:
        requests:
          memory: "64Mi"
          cpu: "100m"
        limits:
          memory: "128Mi"
          cpu: "250m"
```

> Un Pod seul n'est pas redémarré en cas de crash. Utiliser un Deployment en pratique.

### 4.3 Deployment

```yaml
# deployment.yml
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
      app: taskflow          # doit correspondre aux labels du template
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    metadata:
      labels:
        app: taskflow        # labels des pods créés
        version: "1.0.0"
    spec:
      containers:
        - name: taskflow
          image: taskflow:1.0.0
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
          env:
            - name: APP_ENV
              value: "production"
          envFrom:
            - configMapRef:
                name: taskflow-config
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "500m"
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 15
            periodSeconds: 20
```

### 4.4 Service ClusterIP

```yaml
# service-clusterip.yml
apiVersion: v1
kind: Service
metadata:
  name: taskflow-svc
  namespace: taskflow
spec:
  type: ClusterIP          # accessible uniquement dans le cluster
  selector:
    app: taskflow          # cible les pods avec ce label
  ports:
    - name: http
      protocol: TCP
      port: 80             # port du service (dans le cluster)
      targetPort: 80       # port du container
```

### 4.5 Service NodePort

```yaml
# service-nodeport.yml
apiVersion: v1
kind: Service
metadata:
  name: taskflow-nodeport
  namespace: taskflow
spec:
  type: NodePort
  selector:
    app: taskflow
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30080      # port exposé sur les nœuds (30000-32767)
```

### 4.6 ConfigMap

```yaml
# configmap.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: taskflow-config
  namespace: taskflow
data:
  APP_ENV: "production"
  APP_PORT: "80"
  LOG_LEVEL: "info"
  nginx.conf: |
    server {
        listen 80;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
```

```bash
# Créer depuis un fichier
kubectl create configmap taskflow-config --from-file=nginx.conf -n taskflow

# Créer depuis des valeurs littérales
kubectl create configmap taskflow-env \
  --from-literal=APP_ENV=production \
  --from-literal=APP_PORT=80 \
  -n taskflow
```

### 4.7 Secret

```yaml
# secret.yml
apiVersion: v1
kind: Secret
metadata:
  name: taskflow-secret
  namespace: taskflow
type: Opaque
data:
  db_password: bW9uTW90RGVQYXNzZQ==    # base64 : echo -n 'monMotDePasse' | base64
  api_key: c2VjcmV0a2V5MTIz
```

```bash
# Créer depuis des valeurs littérales (encodage base64 automatique)
kubectl create secret generic taskflow-secret \
  --from-literal=db_password=monMotDePasse \
  --from-literal=api_key=secretkey123 \
  -n taskflow

# Utiliser dans un Deployment
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: taskflow-secret
        key: db_password
```

### 4.8 Ingress

```yaml
# ingress.yml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: taskflow-ingress
  namespace: taskflow
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host: taskflow.local              # ajouter dans /etc/hosts si test local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: taskflow-svc
                port:
                  number: 80
```

> k3d expose le port 80 du loadbalancer sur le port 8080 de la machine hôte (selon la commande `k3d cluster create taskflow --port "8080:80@loadbalancer"`).

---

## 5. Labels et sélecteurs

```bash
# Ajouter un label
kubectl label pod <pod> env=lab -n taskflow

# Supprimer un label
kubectl label pod <pod> env- -n taskflow

# Filtrer par label
kubectl get pods -l app=taskflow -n taskflow
kubectl get pods -l "app=taskflow,version=1.0.0"
kubectl get pods -l "env in (lab,staging)"
kubectl get pods -l "env notin (production)"
```

Dans les manifestes :

```yaml
# selector : définit quels pods sont gérés par le Deployment/Service
selector:
  matchLabels:
    app: taskflow
  matchExpressions:
    - key: version
      operator: In
      values: ["1.0.0", "1.1.0"]
```

---

## 6. Débogage d'un pod

### 6.1 Workflow de diagnostic

```bash
# 1. Voir l'état général
kubectl get pods -n taskflow

# 2. Détails et events
kubectl describe pod <pod> -n taskflow

# 3. Logs du container
kubectl logs <pod> -n taskflow

# 4. Logs du container précédent (si redémarré)
kubectl logs <pod> --previous -n taskflow

# 5. Shell interactif
kubectl exec -it <pod> -n taskflow -- bash

# 6. Pod de debug éphémère
kubectl debug -it <pod> --image=busybox:1.35 --target=taskflow -n taskflow
```

### 6.2 Erreurs courantes

| Statut / Erreur | Cause probable | Solution |
|---|---|---|
| `ErrImagePull` | Image introuvable ou registry inaccessible | Vérifier le nom d'image ; pour k3d : `k3d image import <image> -c <cluster>` |
| `ImagePullBackOff` | Echec répété du pull | Idem + vérifier `imagePullPolicy: IfNotPresent` et `k3d image import` si image locale |
| `CrashLoopBackOff` | Le container crashe au démarrage | `kubectl logs <pod> --previous` pour voir l'erreur |
| `OOMKilled` | Dépassement de la limite mémoire | Augmenter `resources.limits.memory` |
| `Pending` | Pas de nœud disponible | `kubectl describe pod` → vérifier les events (scheduling) |
| `ContainerCreating` | Attente de la création du container | `kubectl describe pod` → events (volume, image) |
| `Error` | Erreur générique | `kubectl describe pod` + `kubectl logs` |
| `Completed` | Container terminé normalement | Normal pour un Job |
| `Terminating` (bloqué) | Finalizer ou volume non libéré | `kubectl delete pod --grace-period=0 --force` |

### 6.3 Inspecter les events du namespace

```bash
# Tous les events du namespace (triés par timestamp)
kubectl get events -n taskflow --sort-by='.metadata.creationTimestamp'

# Events d'un pod spécifique
kubectl get events -n taskflow --field-selector involvedObject.name=<pod>

# Events de type Warning uniquement
kubectl get events -n taskflow --field-selector type=Warning
```

### 6.4 Vérification réseau dans un pod

```bash
# Depuis un pod, tester la résolution DNS interne
kubectl exec -it <pod> -n taskflow -- nslookup taskflow-svc

# Tester la connectivité HTTP vers le service
kubectl exec -it <pod> -n taskflow -- wget -qO- http://taskflow-svc

# Depuis un pod de debug
kubectl run debug --image=curlimages/curl:latest --restart=Never -it --rm -- \
  curl http://taskflow-svc.taskflow.svc.cluster.local
```

---

## 7. kubernetes.core — Module Ansible

### 7.1 Prérequis

```bash
# Dans WSL2 / nœud de contrôle Ansible
pip install kubernetes

# Collection Ansible
ansible-galaxy collection install kubernetes.core
```

### 7.2 Module `kubernetes.core.k8s`

```yaml
# Appliquer un manifeste inline
- name: Créer le namespace taskflow
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: v1
      kind: Namespace
      metadata:
        name: taskflow

# Appliquer depuis un fichier
- name: Déployer l'application
  kubernetes.core.k8s:
    state: present
    src: /tmp/deployment.yml

# Appliquer depuis un template Jinja2
- name: Déployer depuis template
  kubernetes.core.k8s:
    state: present
    template: templates/deployment.yml.j2

# Supprimer une ressource
- name: Supprimer le deployment
  kubernetes.core.k8s:
    state: absent
    api_version: apps/v1
    kind: Deployment
    name: taskflow
    namespace: taskflow

# Attendre que le déploiement soit prêt
- name: Déployer et attendre
  kubernetes.core.k8s:
    state: present
    definition: "{{ lookup('file', 'deployment.yml') | from_yaml }}"
    wait: true
    wait_condition:
      type: Available
      status: "True"
    wait_timeout: 120
```

Paramètres clés de `kubernetes.core.k8s` :

| Paramètre | Description |
|---|---|
| `state` | `present` (créer/màj), `absent` (supprimer), `patched` |
| `definition` | Manifeste YAML inline (dict Python) |
| `src` | Chemin vers un fichier YAML |
| `template` | Chemin vers un template Jinja2 |
| `namespace` | Namespace cible |
| `api_version` | Version d'API Kubernetes |
| `kind` | Type de ressource |
| `name` | Nom de la ressource |
| `wait` | Attendre que la ressource soit prête |
| `wait_timeout` | Timeout en secondes (défaut: 120) |
| `force` | Forcer le remplacement si conflit |
| `apply` | Utiliser `kubectl apply` (réconciliation) |
| `kubeconfig` | Chemin vers le kubeconfig (défaut: `~/.kube/config`) |
| `context` | Contexte kubectl à utiliser |

### 7.3 Module `kubernetes.core.k8s_info`

```yaml
# Récupérer des infos sur des ressources
- name: Récupérer les pods taskflow
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Pod
    namespace: taskflow
    label_selectors:
      - "app=taskflow"
  register: taskflow_pods

# Afficher le résultat
- name: Afficher les pods
  ansible.builtin.debug:
    msg: "Pod : {{ item.metadata.name }} — Status : {{ item.status.phase }}"
  loop: "{{ taskflow_pods.resources }}"

# Récupérer un déploiement spécifique
- name: Vérifier le deployment
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    name: taskflow
    namespace: taskflow
  register: taskflow_deployment

# Utiliser dans une condition
- name: Déployer seulement si absent
  kubernetes.core.k8s:
    state: present
    src: deployment.yml
  when: taskflow_deployment.resources | length == 0
```

### 7.4 Module `kubernetes.core.k8s_scale`

```yaml
# Scaler un deployment
- name: Scaler taskflow à 3 réplicas
  kubernetes.core.k8s_scale:
    api_version: apps/v1
    kind: Deployment
    name: taskflow
    namespace: taskflow
    replicas: 3
    wait: true
    wait_timeout: 60

# Scaler à zéro (arrêt sans suppression)
- name: Arrêter l'application
  kubernetes.core.k8s_scale:
    api_version: apps/v1
    kind: Deployment
    name: taskflow
    namespace: taskflow
    replicas: 0
```

### 7.5 Workflow complet — playbook de déploiement k8s

```yaml
# playbooks/deploy-k8s.yml
---
- hosts: k8s_control
  gather_facts: false
  vars:
    kubeconfig_path: "~/.kube/config"
    app_namespace: taskflow
    app_image: "taskflow:1.0.0"
    app_replicas: 2

  tasks:
    - name: Créer le namespace
      kubernetes.core.k8s:
        state: present
        kubeconfig: "{{ kubeconfig_path }}"
        definition:
          apiVersion: v1
          kind: Namespace
          metadata:
            name: "{{ app_namespace }}"

    - name: Créer le ConfigMap
      kubernetes.core.k8s:
        state: present
        kubeconfig: "{{ kubeconfig_path }}"
        namespace: "{{ app_namespace }}"
        template: templates/configmap.yml.j2

    - name: Déployer l'application
      kubernetes.core.k8s:
        state: present
        kubeconfig: "{{ kubeconfig_path }}"
        namespace: "{{ app_namespace }}"
        template: templates/deployment.yml.j2
        wait: true
        wait_condition:
          type: Available
          status: "True"
        wait_timeout: 120

    - name: Créer le service
      kubernetes.core.k8s:
        state: present
        kubeconfig: "{{ kubeconfig_path }}"
        namespace: "{{ app_namespace }}"
        template: templates/service.yml.j2

    - name: Vérifier les pods déployés
      kubernetes.core.k8s_info:
        kubeconfig: "{{ kubeconfig_path }}"
        api_version: v1
        kind: Pod
        namespace: "{{ app_namespace }}"
        label_selectors:
          - "app=taskflow"
      register: pods

    - name: Afficher le statut des pods
      ansible.builtin.debug:
        msg: "{{ item.metadata.name }} : {{ item.status.phase }}"
      loop: "{{ pods.resources }}"
```

---

## 8. Référence rapide

### kubectl — Aliases utiles

```bash
# Ajouter dans ~/.bashrc ou ~/.zshrc
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgd='kubectl get deployments'
alias kgs='kubectl get services'
alias kga='kubectl get all'
alias kdp='kubectl describe pod'
alias klogs='kubectl logs'
alias kns='kubectl config set-context --current --namespace'
```

### Ressources et abréviations

| Ressource | Abréviation |
|---|---|
| `pods` | `po` |
| `services` | `svc` |
| `deployments` | `deploy` |
| `replicasets` | `rs` |
| `namespaces` | `ns` |
| `configmaps` | `cm` |
| `secrets` | `secret` |
| `ingresses` | `ing` |
| `nodes` | `no` |
| `persistentvolumeclaims` | `pvc` |
| `horizontalpodautoscalers` | `hpa` |

### Format de sortie kubectl

```bash
kubectl get pods -o wide          # colonnes supplémentaires
kubectl get pod <nom> -o yaml     # manifeste YAML complet
kubectl get pod <nom> -o json     # manifeste JSON
kubectl get pods -o jsonpath='{.items[*].metadata.name}'   # jsonpath
kubectl get pods --no-headers -o custom-columns=\
  NAME:.metadata.name,\
  STATUS:.status.phase,\
  IP:.status.podIP              # colonnes personnalisées
```
