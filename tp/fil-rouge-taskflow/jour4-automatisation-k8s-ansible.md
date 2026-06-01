# TP Jour 4 : Automatisation Kubernetes avec Ansible

> **Durée** : ~2h | **Objectif** : Piloter le déploiement Kubernetes depuis Ansible en utilisant la collection `kubernetes.core`, écrire un template Jinja2 pour le Deployment, créer le playbook `k8s-deploy.yml`, prouver l'idempotence et démontrer le scaling déclaratif.

---

## Prérequis

- TP Jour 3 terminé : le cluster k3d `taskflow` est créé et l'image `taskflow:1.0.0` est importée
- Collection `kubernetes.core` installée (déjà dans `requirements.yml`)
- La librairie Python `kubernetes` doit être installée sur le nœud de contrôle

Vérifications :

```bash
# Vérifier le cluster
k3d cluster list
kubectl get nodes

# Installer la dépendance Python (si ce n'est pas déjà fait)
pip install kubernetes
# ou : pip3 install kubernetes

# Vérifier l'installation
python3 -c "import kubernetes; print(kubernetes.__version__)"
```

> La collection `kubernetes.core` utilise en interne la librairie Python `kubernetes` pour communiquer avec l'API server. Sans elle, toutes les tâches `kubernetes.core.k8s` échoueront.

---

## Étape 1 : Créer le fichier de variables `k8s.yml` (15 min)

### 1.1 Créer le répertoire et le fichier

```bash
mkdir -p ansible/playbooks/vars
```

Créez `ansible/playbooks/vars/k8s.yml` :

```yaml
---
# Variables du déploiement Kubernetes piloté par Ansible (J4/J5)
k8s_namespace: taskflow
k8s_kubeconfig: "{{ lookup('env', 'KUBECONFIG') | default('~/.kube/config', true) }}"

taskflow_image: taskflow:1.0.0
taskflow_replicas: 2
taskflow_host: taskflow.localhost

# Ressources (J5 — bonnes pratiques)
taskflow_resources:
  requests:
    cpu: 50m
    memory: 32Mi
  limits:
    cpu: 200m
    memory: 128Mi

# Config non sensible
taskflow_config:
  APP_ENV: production
  APP_TITLE: "TaskFlow - Lab Kubernetes"

# Secret (J5) — en production, chiffré avec Ansible Vault (voir secrets.yml)
taskflow_secret:
  API_TOKEN: "{{ vault_taskflow_api_token | default('dev-token-please-change') }}"
```

> La variable `k8s_kubeconfig` lit d'abord la variable d'environnement `KUBECONFIG` ; si elle est vide, elle utilise `~/.kube/config`. k3d configure automatiquement ce fichier lors de la création du cluster.

---

## Étape 2 : Créer le template Jinja2 du Deployment (25 min)

### 2.1 Créer le répertoire et le template

```bash
mkdir -p ansible/playbooks/templates/k8s
```

Créez `ansible/playbooks/templates/k8s/deployment.yaml.j2` :

```jinja2
apiVersion: apps/v1
kind: Deployment
metadata:
  name: taskflow
  namespace: {{ k8s_namespace }}
  labels:
    app: taskflow
spec:
  replicas: {{ taskflow_replicas }}
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
          image: {{ taskflow_image }}
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: taskflow-config
            - secretRef:
                name: taskflow-secret
          resources:
            requests:
              cpu: {{ taskflow_resources.requests.cpu }}
              memory: {{ taskflow_resources.requests.memory }}
            limits:
              cpu: {{ taskflow_resources.limits.cpu }}
              memory: {{ taskflow_resources.limits.memory }}
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 3
            periodSeconds: 5
```

> Ce template inclut déjà les `resources` et les probes `livenessProbe`/`readinessProbe`. Ils sont le standard de production pour tout Deployment Kubernetes. Le Jour 5 y revient en détail.

---

## Étape 3 : Écrire le playbook `k8s-deploy.yml` (40 min)

### 3.1 Créer `ansible/playbooks/k8s-deploy.yml`

```yaml
---
# =============================================================================
# TP Jour 4/5 — Déploiement de TaskFlow sur Kubernetes piloté par Ansible
# Utilise la collection kubernetes.core (idempotent).
# Prérequis : cluster k3d actif, collection installée
#   ansible-galaxy collection install kubernetes.core
#   pip install kubernetes
# Exécution : ansible-playbook playbooks/k8s-deploy.yml --ask-vault-pass
# =============================================================================
- name: Déployer TaskFlow sur Kubernetes
  hosts: k8s_control
  gather_facts: false

  vars_files:
    - vars/k8s.yml
    # secrets.yml est chiffré avec Ansible Vault (J5)
    - vars/secrets.yml

  tasks:
    - name: Créer le namespace
      kubernetes.core.k8s:
        kubeconfig: "{{ k8s_kubeconfig }}"
        state: present
        definition:
          apiVersion: v1
          kind: Namespace
          metadata:
            name: "{{ k8s_namespace }}"
            labels:
              app: taskflow
              env: lab

    - name: Appliquer la ConfigMap
      kubernetes.core.k8s:
        kubeconfig: "{{ k8s_kubeconfig }}"
        state: present
        namespace: "{{ k8s_namespace }}"
        definition:
          apiVersion: v1
          kind: ConfigMap
          metadata:
            name: taskflow-config
          data: "{{ taskflow_config }}"

    - name: Appliquer le Secret (valeurs issues du Vault)
      kubernetes.core.k8s:
        kubeconfig: "{{ k8s_kubeconfig }}"
        state: present
        namespace: "{{ k8s_namespace }}"
        definition:
          apiVersion: v1
          kind: Secret
          metadata:
            name: taskflow-secret
          type: Opaque
          stringData: "{{ taskflow_secret }}"
      no_log: true

    - name: Appliquer le Deployment (template Jinja2)
      kubernetes.core.k8s:
        kubeconfig: "{{ k8s_kubeconfig }}"
        state: present
        namespace: "{{ k8s_namespace }}"
        template: k8s/deployment.yaml.j2

    - name: Appliquer le Service
      kubernetes.core.k8s:
        kubeconfig: "{{ k8s_kubeconfig }}"
        state: present
        namespace: "{{ k8s_namespace }}"
        definition:
          apiVersion: v1
          kind: Service
          metadata:
            name: taskflow
          spec:
            type: ClusterIP
            selector:
              app: taskflow
            ports:
              - name: http
                port: 80
                targetPort: 80

    - name: Appliquer l'Ingress
      kubernetes.core.k8s:
        kubeconfig: "{{ k8s_kubeconfig }}"
        state: present
        namespace: "{{ k8s_namespace }}"
        definition:
          apiVersion: networking.k8s.io/v1
          kind: Ingress
          metadata:
            name: taskflow
          spec:
            rules:
              - host: "{{ taskflow_host }}"
                http:
                  paths:
                    - path: /
                      pathType: Prefix
                      backend:
                        service:
                          name: taskflow
                          port:
                            number: 80

    - name: Attendre que le déploiement soit disponible
      kubernetes.core.k8s_info:
        kubeconfig: "{{ k8s_kubeconfig }}"
        kind: Deployment
        name: taskflow
        namespace: "{{ k8s_namespace }}"
        wait: true
        wait_condition:
          type: Available
          status: "True"
        wait_timeout: 120
```

> `no_log: true` sur la tâche Secret empêche Ansible d'afficher les valeurs en clair dans les logs de sortie. C'est une bonne pratique de sécurité obligatoire pour toute ressource contenant des données sensibles.

---

## Étape 4 : Créer `secrets.yml` (temporairement en clair) (5 min)

Pour l'instant, créez `ansible/playbooks/vars/secrets.yml` en clair. Le chiffrement est l'objet du Jour 5.

```bash
cat > ansible/playbooks/vars/secrets.yml << 'EOF'
---
vault_taskflow_api_token: "s3cr3t-token-de-demonstration"
EOF
```

---

## Étape 5 : Déployer et valider (20 min)

### 5.1 Premier déploiement

Depuis le dossier `ansible/` :

```bash
ansible-playbook playbooks/k8s-deploy.yml
```

> Si le playbook vous demande un vault password, appuyez sur Entrée (le fichier n'est pas encore chiffré).

**Résultat attendu :**

```
PLAY [Déployer TaskFlow sur Kubernetes] ****************************************

TASK [Créer le namespace] ******************************************************
changed: [localhost]

TASK [Appliquer la ConfigMap] **************************************************
changed: [localhost]

TASK [Appliquer le Secret (valeurs issues du Vault)] ***************************
changed: [localhost]

TASK [Appliquer le Deployment (template Jinja2)] *******************************
changed: [localhost]

TASK [Appliquer le Service] ****************************************************
changed: [localhost]

TASK [Appliquer l'Ingress] *****************************************************
changed: [localhost]

TASK [Attendre que le déploiement soit disponible] *****************************
ok: [localhost]

PLAY RECAP *********************************************************************
localhost                  : ok=7    changed=6    unreachable=0    failed=0
```

### 5.2 Vérifier les pods

```bash
kubectl get pods -n taskflow
```

**Résultat attendu :** 2 pods en état `Running`.

### 5.3 Vérifier l'accès

```bash
curl http://taskflow.localhost:8080
```

### 5.4 Prouver l'idempotence

```bash
ansible-playbook playbooks/k8s-deploy.yml
```

**Résultat attendu :**

```
PLAY RECAP *********************************************************************
localhost                  : ok=7    changed=0    unreachable=0    failed=0
```

---

## Étape 6 : Démontrer le scaling déclaratif (10 min)

### 6.1 Modifier le nombre de replicas

Dans `ansible/playbooks/vars/k8s.yml`, changez :

```yaml
taskflow_replicas: 3
```

### 6.2 Relancer le playbook

```bash
ansible-playbook playbooks/k8s-deploy.yml
```

### 6.3 Vérifier

```bash
kubectl get pods -n taskflow
```

**Résultat attendu :** 3 pods en état `Running`.

### 6.4 Revenir à 2 replicas

Remettez `taskflow_replicas: 2` dans `k8s.yml` et relancez le playbook.

---

## Checklist de validation

- [ ] `pip install kubernetes` s'est terminé sans erreur
- [ ] `ansible/playbooks/vars/k8s.yml` existe avec les bonnes variables
- [ ] `ansible/playbooks/templates/k8s/deployment.yaml.j2` existe et contient les variables Jinja2
- [ ] `ansible/playbooks/k8s-deploy.yml` contient les 7 tâches (namespace, configmap, secret, deployment, service, ingress, wait)
- [ ] La tâche Secret contient bien `no_log: true`
- [ ] Le premier lancement de `k8s-deploy.yml` se termine avec `failed=0`
- [ ] `kubectl get pods -n taskflow` affiche 2 pods `Running`
- [ ] Le second lancement retourne `changed=0`
- [ ] Le scaling à 3 replicas fonctionne après modification de `taskflow_replicas`

---

## Erreurs courantes

**`FAILED! => ModuleNotFoundError: No module named 'kubernetes'`**
La librairie Python n'est pas installée dans l'environnement Python utilisé par Ansible. Installez-la avec `pip install kubernetes` (ou `pip3 install kubernetes`), en vous assurant d'utiliser le même Python qu'Ansible (`ansible --version` indique le chemin Python utilisé).

**`FAILED! => Unable to connect to the server: dial tcp: connection refused`**
Ansible ne peut pas joindre le cluster Kubernetes. Vérifiez que le cluster k3d est actif (`k3d cluster list`) et que le fichier kubeconfig est correctement configuré (`kubectl get nodes`).

**`FAILED! => Error from server (AlreadyExists)`**
Ce message ne devrait pas apparaître avec `state: present` qui est idempotent. S'il apparaît, vérifiez la version de la collection (`ansible-galaxy collection list kubernetes.core`).

**La tâche `Attendre que le déploiement soit disponible` timeout**
L'image n'est pas disponible dans le cluster. Relancez `k3d image import taskflow:1.0.0 -c taskflow` et vérifiez que `imagePullPolicy: IfNotPresent` est bien dans le template.

---

## Ressources

- [Documentation kubernetes.core.k8s](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/k8s_module.html)
- [Documentation kubernetes.core.k8s_info](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/k8s_info_module.html)
- [Kubernetes — Resource Management pour Pods](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Kubernetes — Liveness et Readiness Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)

---

**Prochain TP** : [Jour 5 — Secrets & Finalisation](./jour5-secrets-finalisation.md)
