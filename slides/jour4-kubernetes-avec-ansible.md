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

# Jour 4 — Gestion des clusters Kubernetes avec Ansible

**M2 DevOps — Formation Ansible & Kubernetes**
ForEach Academy | Formateur : Fabrice Claeys

---

## Programme du jour

| Horaire | Contenu |
|---------|---------|
| 09h00 – 09h30 | Rappel J3 & motivations : pourquoi Ansible pour K8s |
| 09h30 – 10h15 | Approches IaC pour Kubernetes |
| 10h15 – 11h00 | La collection `kubernetes.core` |
| 11h00 – 11h45 | Connexion au cluster, module `k8s` |
| 11h45 – 12h30 | Variabilisation & templates Jinja2 |
| **12h30 – 13h30** | **Pause déjeuner** |
| 13h30 – 14h15 | `k8s_info`, attente de conditions, boucles |
| 14h15 – 15h00 | Playbook complet `k8s-deploy.yml` & démo |
| 15h00 – 17h30 | **TP4 — Réécrire le déploiement J3 avec Ansible** |

---

## Rappel Jour 3 — Ce que l'on a fait manuellement

Au Jour 3, on a déployé l'application **taskflow** sur Kubernetes avec `kubectl apply` :

```bash
kubectl create namespace taskflow
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
```

Cela fonctionne. Mais…

- Chaque opérateur répète les mêmes commandes à la main
- Si on oublie une ressource, le déploiement est partiel
- Les valeurs (image, replicas, host) sont codées en dur dans les YAML
- Pas d'orchestration avec le reste de l'infra

---

## Les limites du `kubectl apply` manuel

**Pas reproductible** : l'ordre d'application, les oublis, les variantes entre environnements

**Pas d'idempotence centralisée** : on ne sait pas facilement si le cluster est dans l'état voulu sans inspecter chaque ressource

**Secrets et variables éparpillés** : les valeurs sensibles apparaissent dans les fichiers YAML versionné

**Pas d'orchestration** : impossible de chaîner "provisionne la VM" → "configure le cluster" → "déploie l'app" dans le même outil

> **Solution : piloter Kubernetes depuis Ansible**

---

## Pourquoi Ansible pour Kubernetes ?

<div class="columns">
<div>

**Ce qu'Ansible apporte**

- Un seul outil pour toute la chaîne d'infra
- Idempotence déclarative (`state: present`)
- Variabilisation centralisée (`vars/`, `group_vars/`)
- Templates Jinja2 pour les manifests
- Gestion des secrets via Vault
- Playbooks réutilisables entre environnements

</div>
<div>

**Cas d'usage typiques**

- Provisionner des VMs **ET** déployer des apps K8s dans le même playbook
- Déployer sur plusieurs clusters en séquence
- Paramétrer staging vs production via inventaire
- Intégrer K8s dans un pipeline de configuration globale

</div>
</div>

---

## Les approches IaC pour Kubernetes

| Outil | Usage principal | Points forts | Limites |
|-------|-----------------|--------------|---------|
| `kubectl apply` | Application manuelle | Simple, direct | Non reproductible, pas d'orchestration |
| **Helm** | Packages K8s | Templating puissant, registres | Courbe d'apprentissage, K8s only |
| **Kustomize** | Overlays YAML | Natif kubectl, pas de template | Logique limitée |
| **Ansible** (`kubernetes.core`) | Orchestration globale | Un outil pour tout, Vault, Jinja2 | Nécessite Python/Ansible |

**Quand choisir Ansible ?**
Quand le déploiement K8s fait partie d'une orchestration plus large : provisioning de machines, configuration OS, déploiement applicatif — **un seul playbook, une seule source de vérité**.

---

<!-- _class: lead -->

# La collection `kubernetes.core`

---

## Installation de la collection

La collection `kubernetes.core` est maintenue par Red Hat / Ansible.

```bash
# Installer la collection
ansible-galaxy collection install kubernetes.core

# Dépendance Python obligatoire (sur le control node)
pip install kubernetes
```

Vérifier l'installation :

```bash
ansible-galaxy collection list | grep kubernetes
# kubernetes.core   2.4.x
```

> La collection s'exécute sur le **control node** (votre machine ou le runner CI). Elle dialogue avec l'API K8s via le kubeconfig.

---

## Les modules clés de kubernetes.core

| Module | Rôle |
|--------|------|
| `kubernetes.core.k8s` | Créer / modifier / supprimer une ressource K8s (namespace, pod, deployment, service…) |
| `kubernetes.core.k8s_info` | Lire l'état d'une ou plusieurs ressources |
| `kubernetes.core.k8s_scale` | Modifier le nombre de replicas d'un Deployment ou StatefulSet |
| `kubernetes.core.helm` | Installer / mettre à jour un chart Helm |
| `kubernetes.core.k8s_exec` | Exécuter une commande dans un pod |

Nous utiliserons principalement `k8s` et `k8s_info` dans le TP4.

---

## Connexion au cluster — le kubeconfig

Ansible se connecte au cluster Kubernetes via le fichier **kubeconfig**, exactement comme `kubectl`.

**Trois façons de le spécifier :**

```yaml
# Option 1 — paramètre explicite dans la tâche
- kubernetes.core.k8s:
    kubeconfig: /home/user/.kube/config

# Option 2 — variable d'environnement (lu par le module Python)
# export KUBECONFIG=/home/user/.kube/config

# Option 3 — défaut : ~/.kube/config (rien à spécifier)
- kubernetes.core.k8s:
    state: present
    definition: { ... }
```

**Important** : les tâches `kubernetes.core` s'exécutent **localement** sur le control node.

```yaml
- hosts: localhost
  connection: local
  gather_facts: false
```

---

## Le module `k8s` — paramètres essentiels

```yaml
- name: Appliquer une ressource Kubernetes
  kubernetes.core.k8s:
    state: present          # present | absent | patched | replaced
    kubeconfig: ~/.kube/config   # optionnel si défaut
    definition:             # manifest inline (dict YAML)
      apiVersion: v1
      kind: Namespace
      metadata:
        name: taskflow
    # -- alternatives à definition --
    src: k8s/service.yaml           # fichier YAML statique
    template: k8s/deployment.yaml.j2  # template Jinja2 (résolu par Ansible)
```

**Idempotence native** : si la ressource existe déjà avec le même spec, Ansible retourne `ok` sans rien modifier.

---

## Premier exemple — Créer un Namespace

```yaml
---
- name: Déployer taskflow sur Kubernetes
  hosts: localhost
  connection: local
  gather_facts: false

  tasks:
    - name: Créer le namespace taskflow
      kubernetes.core.k8s:
        state: present
        definition:
          apiVersion: v1
          kind: Namespace
          metadata:
            name: taskflow
            labels:
              app: taskflow
              env: production
```

Relancer le playbook → `ok` (idempotent, le namespace existe déjà).

---

## Appliquer une ConfigMap inline

```yaml
- name: Appliquer la ConfigMap de configuration
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: taskflow-config
        namespace: "{{ taskflow_namespace }}"
      data:
        APP_ENV: "{{ taskflow_env }}"
        LOG_LEVEL: "{{ taskflow_log_level }}"
        DATABASE_URL: "{{ taskflow_db_url }}"
```

Les valeurs `{{ ... }}` sont résolues par Ansible **avant** d'envoyer le manifest à l'API Kubernetes — Jinja2 côté Ansible, pas côté K8s.

---

## Variabiliser — `vars/k8s.yml`

Centraliser toutes les valeurs dans un fichier de variables :

```yaml
# vars/k8s.yml
taskflow_namespace: taskflow
taskflow_image: taskflow:1.0.0
taskflow_replicas: 2
taskflow_port: 3000
taskflow_host: taskflow.localhost

taskflow_env: production
taskflow_log_level: info
taskflow_db_url: "postgresql://db:5432/taskflow"

taskflow_resources_requests_cpu: "100m"
taskflow_resources_requests_memory: "128Mi"
taskflow_resources_limits_cpu: "500m"
taskflow_resources_limits_memory: "256Mi"
```

Changer d'environnement = changer de fichier vars (ou passer `--extra-vars`).

---

## Templatiser un Deployment — `templates/k8s/deployment.yaml.j2`

```jinja
apiVersion: apps/v1
kind: Deployment
metadata:
  name: taskflow
  namespace: {{ taskflow_namespace }}
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
          ports:
            - containerPort: {{ taskflow_port }}
          resources:
            requests:
              cpu: {{ taskflow_resources_requests_cpu }}
              memory: {{ taskflow_resources_requests_memory }}
```

---

## Appliquer le Deployment depuis le template

```yaml
- name: Appliquer le Deployment (depuis template Jinja2)
  kubernetes.core.k8s:
    state: present
    template: templates/k8s/deployment.yaml.j2
```

Ansible résout le template Jinja2, puis envoie le YAML final à l'API K8s.

**Avantages** :

- Le manifest reste lisible (YAML standard)
- Les variables viennent d'Ansible (vars, group_vars, Vault)
- On peut générer plusieurs ressources similaires avec `loop`

---

## Appliquer le Service et l'Ingress

```yaml
- name: Appliquer le Service
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: v1
      kind: Service
      metadata:
        name: taskflow
        namespace: "{{ taskflow_namespace }}"
      spec:
        selector:
          app: taskflow
        ports:
          - port: 80
            targetPort: "{{ taskflow_port }}"

- name: Appliquer l'Ingress
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      metadata:
        name: taskflow
        namespace: "{{ taskflow_namespace }}"
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
```

---

## Le module `k8s_info` — interroger l'état du cluster

```yaml
- name: Récupérer l'état du Deployment
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    name: taskflow
    namespace: "{{ taskflow_namespace }}"
  register: deploy_info

- name: Afficher le nombre de replicas disponibles
  ansible.builtin.debug:
    msg: "Replicas disponibles : {{ deploy_info.resources[0].status.availableReplicas }}"
```

On enregistre le résultat dans une variable pour l'exploiter ensuite dans des conditions ou assertions.

---

## Attendre qu'un Deployment soit disponible

```yaml
- name: Attendre que le Deployment taskflow soit Available
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: taskflow
        namespace: "{{ taskflow_namespace }}"
  wait: true
  wait_condition:
    type: Available
    status: "True"
  wait_timeout: 120
```

`wait: true` + `wait_condition` : Ansible interroge l'API K8s jusqu'à ce que la condition soit vraie ou que le timeout soit atteint.

---

## Boucles et déploiement de plusieurs ressources

Déployer plusieurs ConfigMaps ou plusieurs namespaces en une seule tâche :

```yaml
- name: Créer plusieurs namespaces
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: v1
      kind: Namespace
      metadata:
        name: "{{ item }}"
  loop:
    - taskflow
    - monitoring
    - ingress-nginx
```

Pour des ressources complexes différentes, on peut aussi utiliser `loop` avec `template` et `lookup('template', item)` pour générer chaque manifest dynamiquement.

---

## Helm via Ansible (aperçu)

La collection `kubernetes.core` inclut aussi un module pour Helm :

```yaml
- name: Installer / mettre à jour un chart Helm
  kubernetes.core.helm:
    name: my-release
    chart_ref: ingress-nginx/ingress-nginx
    release_namespace: ingress-nginx
    create_namespace: true
    values:
      controller:
        replicaCount: 2
```

**Quand l'utiliser ?**
Quand une application tierce (cert-manager, ingress-nginx, prometheus) est packagée en chart Helm — on garde Ansible comme orchestrateur global tout en bénéficiant des charts existants.

---

## Structure du playbook complet

```
playbooks/
  k8s-deploy.yml        ← le playbook principal
vars/
  k8s.yml               ← toutes les variables K8s
templates/
  k8s/
    deployment.yaml.j2  ← template Jinja2 du Deployment
```

---

## `playbooks/k8s-deploy.yml` — vue d'ensemble

```yaml
---
- name: Déployer taskflow sur Kubernetes
  hosts: localhost
  connection: local
  gather_facts: false

  vars_files:
    - ../vars/k8s.yml

  tasks:
    - name: "1/6 — Créer le namespace"
      kubernetes.core.k8s:
        state: present
        definition:
          apiVersion: v1
          kind: Namespace
          metadata:
            name: "{{ taskflow_namespace }}"

    - name: "2/6 — Appliquer la ConfigMap"
      kubernetes.core.k8s:
        state: present
        definition: "{{ lookup('template', '../templates/k8s/configmap.yaml.j2') | from_yaml }}"

    - name: "3/6 — Appliquer le Deployment"
      kubernetes.core.k8s:
        state: present
        template: ../templates/k8s/deployment.yaml.j2
```

---

## `playbooks/k8s-deploy.yml` — suite

```yaml
    - name: "4/6 — Appliquer le Service"
      kubernetes.core.k8s:
        state: present
        definition:
          apiVersion: v1
          kind: Service
          metadata:
            name: taskflow
            namespace: "{{ taskflow_namespace }}"
          spec:
            selector:
              app: taskflow
            ports:
              - port: 80
                targetPort: "{{ taskflow_port }}"

    - name: "5/6 — Appliquer l'Ingress"
      kubernetes.core.k8s:
        state: present
        definition:
          apiVersion: networking.k8s.io/v1
          kind: Ingress
          metadata:
            name: taskflow
            namespace: "{{ taskflow_namespace }}"
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

    - name: "6/6 — Attendre la disponibilité du Deployment"
      kubernetes.core.k8s:
        state: present
        definition:
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: taskflow
            namespace: "{{ taskflow_namespace }}"
      wait: true
      wait_condition:
        type: Available
        status: "True"
      wait_timeout: 120
```

---

## Idempotence — le vrai test

**Premier run** (cluster vide) :

```
TASK [1/6 — Créer le namespace]     changed
TASK [2/6 — Appliquer la ConfigMap] changed
TASK [3/6 — Appliquer le Deployment] changed
TASK [4/6 — Appliquer le Service]   changed
TASK [5/6 — Appliquer l'Ingress]    changed
TASK [6/6 — Attendre la disponibilité] ok

PLAY RECAP: changed=5  ok=1  failed=0
```

**Deuxième run** (sans modification) :

```
TASK [1/6 — Créer le namespace]      ok
TASK [2/6 — Appliquer la ConfigMap]  ok
TASK [3/6 — Appliquer le Deployment] ok
TASK [4/6 — Appliquer le Service]    ok
TASK [5/6 — Appliquer l'Ingress]     ok
TASK [6/6 — Attendre la disponibilité] ok

PLAY RECAP: changed=0  ok=6  failed=0
```

> **`changed=0`** : l'infra est déjà dans l'état voulu, Ansible ne touche à rien.

---

<!-- _class: lead -->

# Démo live

`ansible-playbook playbooks/k8s-deploy.yml`

---

## Ce que l'on observe dans la démo

**Lancement du playbook :**

```bash
ansible-playbook playbooks/k8s-deploy.yml
```

**Vérification après déploiement :**

```bash
kubectl get all -n taskflow
kubectl get ingress -n taskflow
curl http://taskflow.localhost
```

**Test de l'idempotence :**

```bash
# Relancer sans rien changer
ansible-playbook playbooks/k8s-deploy.yml
# => PLAY RECAP : changed=0
```

**Scaler via variable :**

```bash
ansible-playbook playbooks/k8s-deploy.yml \
  --extra-vars "taskflow_replicas=4"
# => Deployment : changed=1 (replicas mis à jour)
```

---

<!-- _class: lead -->

# TP4 — Réécrire le déploiement J3 avec Ansible

**Durée : 2h30**

---

## TP4 — Objectifs pédagogiques

A la fin de ce TP, vous serez capables de :

1. Installer la collection `kubernetes.core` et la dépendance Python `kubernetes`
2. Écrire un fichier `vars/k8s.yml` avec toutes les variables nécessaires
3. Créer le template `templates/k8s/deployment.yaml.j2`
4. Écrire le playbook `playbooks/k8s-deploy.yml` qui applique les 5 ressources K8s
5. Prouver l'idempotence en relançant le playbook sans modification (`changed=0`)
6. Scaler les replicas en passant une variable `--extra-vars`

---

## TP4 — Étape 1 : Prérequis

```bash
# Installer la collection
ansible-galaxy collection install kubernetes.core

# Installer la dépendance Python
pip install kubernetes

# Vérifier
ansible-galaxy collection list | grep kubernetes
python -c "import kubernetes; print(kubernetes.__version__)"
```

S'assurer que le cluster K8s (minikube / k3d) est démarré :

```bash
kubectl cluster-info
kubectl get nodes
```

---

## TP4 — Étape 2 : Structure à créer

```
playbooks/
  k8s-deploy.yml          ← à créer
vars/
  k8s.yml                 ← à créer
templates/
  k8s/
    deployment.yaml.j2    ← à créer
```

Valeurs cibles pour `vars/k8s.yml` :

| Variable | Valeur |
|----------|--------|
| `taskflow_namespace` | `taskflow` |
| `taskflow_image` | `taskflow:1.0.0` |
| `taskflow_replicas` | `2` |
| `taskflow_port` | `3000` |
| `taskflow_host` | `taskflow.localhost` |

---

## TP4 — Étape 3 : Le playbook

Écrire `playbooks/k8s-deploy.yml` avec les tâches dans cet ordre :

1. Créer le **Namespace** `taskflow`
2. Appliquer la **ConfigMap** `taskflow-config`
3. Appliquer le **Deployment** depuis le template `deployment.yaml.j2`
4. Appliquer le **Service** exposant le port 80 → 3000
5. Appliquer l'**Ingress** sur `taskflow.localhost`
6. **Attendre** que le Deployment soit `Available` (`wait: true`, timeout 120s)

> Toutes les ressources utilisent `state: present`

---

## TP4 — Étape 4 : Vérification & validation

**Déployer :**
```bash
ansible-playbook playbooks/k8s-deploy.yml
```

**Vérifier dans le cluster :**
```bash
kubectl get all -n taskflow
kubectl get ingress -n taskflow
curl http://taskflow.localhost
```

**Prouver l'idempotence :**
```bash
ansible-playbook playbooks/k8s-deploy.yml
# Attendu : changed=0
```

**Bonus — Scaler à 4 replicas :**
```bash
ansible-playbook playbooks/k8s-deploy.yml \
  --extra-vars "taskflow_replicas=4"
kubectl get deployment taskflow -n taskflow
# READY doit afficher 4/4
```

---

## Récapitulatif du Jour 4

**Ce que nous avons appris :**

- Pourquoi `kubectl apply` manuel montre ses limites et comment Ansible y répond
- Les différentes approches IaC pour K8s et quand choisir Ansible
- Installer et utiliser la collection `kubernetes.core`
- Le module `k8s` : `state`, `definition`, `src`, `template`
- La connexion au cluster via kubeconfig (`hosts: localhost`, `connection: local`)
- Variabiliser avec `vars/k8s.yml` et templatiser avec Jinja2
- `k8s_info` et l'attente de conditions (`wait`, `wait_condition`)
- Construire et valider un playbook complet et idempotent

**Ce que vous avez pratiqué en TP4 :**
Réécrire de A à Z le déploiement manuel du Jour 3 en un playbook Ansible réutilisable, variabilisé et idempotent.

---

<!-- _class: lead -->

# Questions ?

**Fabrice Claeys**
Formateur DevOps — ForEach Academy
fabrice.claeys@groupe-bao.fr

*Jour 5 : CI/CD avec Ansible — intégration dans un pipeline Woodpecker / GitLab CI*
