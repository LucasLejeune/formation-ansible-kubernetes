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

# Jour 5 — Bonnes pratiques & Cas d'utilisation avancés

**M2 DevOps — Formation Ansible & Kubernetes**
ForEach Academy | Formateur : Fabrice Claeys

> Dernier jour — QCM final en fin de journée !

---

## Programme du jour

| Horaire | Contenu |
|---------|---------|
| 09h00 – 09h30 | Rappel J4 & le problème des secrets |
| 09h30 – 10h30 | Ansible Vault : chiffrement des données sensibles |
| 10h30 – 11h15 | Kubernetes Secrets : théorie et manifests |
| 11h15 – 12h00 | Combiner Vault + K8s Secret via Ansible |
| **12h00 – 13h00** | **Pause déjeuner** |
| 13h00 – 13h45 | Probes & Resource Limits |
| 13h45 – 14h30 | Bonnes pratiques Ansible & Kubernetes |
| 14h30 – 15h00 | Intégration CI/CD & étude de cas TaskFlow |
| 15h00 – 16h30 | **TP5 — Déploiement complet et sécurisé** |
| 16h30 – 17h30 | **QCM final + Bilan de formation** |

---

<!-- _class: lead -->

# Le problème des secrets

---

## Ne jamais committer de secrets en clair

Le réflexe dangereux — trouver une variable et la coller directement dans le YAML :

```yaml
# playbooks/vars/secrets.yml  ← dans git !
db_password: "MonMotDePasse123!"
api_key: "sk-proj-aBcDeFgHiJkL..."
jwt_secret: "super_secret_jwt"
```

```bash
git add playbooks/vars/secrets.yml
git commit -m "ajout config BDD"   # CATASTROPHE
git push                            # public ou interne → fuite
```

**Conséquences réelles :**
- Tokens AWS / clés API exposés sur GitHub = factures astronomiques
- Mot de passe BDD de prod accessible à tous les contributeurs
- Impossible de "dé-committer" proprement (l'historique git conserve tout)

> **Règle d'or : aucun secret en clair ne doit entrer dans git**

---

## Les solutions disponibles

| Outil | Contexte | Principe |
|-------|----------|----------|
| **Ansible Vault** | Ansible | Chiffre les fichiers YAML AES-256 |
| **Kubernetes Secrets** | K8s | Stocke les données sensibles en base64 |
| **HashiCorp Vault** | Multi-outils | Coffre-fort centralisé (hors scope J5) |
| **SOPS** | GitOps | Chiffrement par fichier, compatible git |
| **Sealed Secrets** | K8s/GitOps | Secrets chiffrés commitables |

Pour notre formation : **Ansible Vault** cote Ansible + **Kubernetes Secrets** cote cluster.

---

<!-- _class: lead -->

# Ansible Vault

---

## Ansible Vault — Principe

Ansible Vault chiffre les fichiers YAML (ou des variables individuelles) avec **AES-256**.

Le fichier chiffré **est commitable** : sans la clé, son contenu est illisible.

```bash
# Structure recommandee
playbooks/
  vars/
    main.yml        # Variables publiques (dans git, en clair)
    secrets.yml     # Variables sensibles (dans git, chiffré)
```

**Workflow :**
1. Créer / éditer le fichier chiffré avec `ansible-vault`
2. Le committer tel quel (opaque, sûr)
3. Fournir le mot de passe au moment de l'exécution du playbook

> Le mot de passe Vault lui-même ne doit JAMAIS être commité

---

## Commandes Ansible Vault

```bash
# Creer un nouveau fichier chiffre
ansible-vault create playbooks/vars/secrets.yml

# Chiffrer un fichier existant en clair
ansible-vault encrypt playbooks/vars/secrets.yml

# Editer un fichier chiffre (ouvre l'editeur par defaut)
ansible-vault edit playbooks/vars/secrets.yml

# Afficher le contenu sans modifier
ansible-vault view playbooks/vars/secrets.yml

# Dechiffrer (retour en clair — a eviter sauf debug local)
ansible-vault decrypt playbooks/vars/secrets.yml

# Changer le mot de passe de chiffrement
ansible-vault rekey playbooks/vars/secrets.yml
```

---

## Contenu type de secrets.yml

Avant chiffrement, le fichier ressemble à :

```yaml
# playbooks/vars/secrets.yml (AVANT ansible-vault encrypt)
vault_db_password: "MonMotDePasse123!"
vault_api_key: "sk-proj-aBcDeFgHiJkL..."
vault_jwt_secret: "super_secret_jwt_32chars_minimum"
vault_taskflow_secret: "taskflow-prod-secret-2025"
```

**Convention `vault_*` :** préfixer les variables Vault permet de les distinguer des variables publiques.

Dans `playbooks/vars/main.yml` (en clair) :
```yaml
# Variables publiques qui pointent vers les variables vaultees
db_password: "{{ vault_db_password }}"
api_key: "{{ vault_api_key }}"
jwt_secret: "{{ vault_jwt_secret }}"
taskflow_secret: "{{ vault_taskflow_secret }}"
```

---

## Exécuter un playbook avec Vault

```bash
# Saisie interactive du mot de passe
ansible-playbook playbooks/k8s-deploy.yml --ask-vault-pass

# Fichier contenant le mot de passe (permissions 600 !)
echo "MonMotDePasseVault" > ~/.vault_pass
chmod 600 ~/.vault_pass
ansible-playbook playbooks/k8s-deploy.yml \
  --vault-password-file ~/.vault_pass

# Via variable d'environnement (CI/CD)
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass
ansible-playbook playbooks/k8s-deploy.yml
```

**Pour le TP5** — inclure les deux fichiers de variables dans le playbook :
```yaml
vars_files:
  - vars/main.yml
  - vars/secrets.yml   # chiffre par Vault
```

---

<!-- _class: lead -->

# Kubernetes Secrets

---

## ConfigMap vs Secret

| Critère | ConfigMap | Secret |
|---------|-----------|--------|
| Contenu | Config non sensible | Données sensibles |
| Stockage | Clair dans etcd | Base64 dans etcd* |
| Usage | ENV, volumes, args | Mots de passe, tokens, TLS |
| `kubectl get` | Contenu visible | Contenu masqué par défaut |
| Type | — | `Opaque`, `kubernetes.io/tls`… |

**\* Attention :** base64 n'est PAS du chiffrement — c'est de l'encodage.

> Un Secret Kubernetes n'est pas chiffré par défaut. La sécurité repose sur **encryption at rest** (config etcd) et le **RBAC**.

---

## Créer un Secret — stringData vs data

```yaml
# Avec stringData : valeurs en clair, Kubernetes encode en base64
apiVersion: v1
kind: Secret
metadata:
  name: taskflow-secret
  namespace: taskflow
type: Opaque
stringData:
  db_password: "MonMotDePasse123!"
  jwt_secret: "super_secret_jwt_32chars_minimum"
```

```yaml
# Avec data : valeurs deja encodees en base64
apiVersion: v1
kind: Secret
metadata:
  name: taskflow-secret
  namespace: taskflow
type: Opaque
data:
  db_password: "TW9uTW90RGVQYXNzZTEyMyE="   # echo -n "MonMotDePasse123!" | base64
  jwt_secret: "c3VwZXJfc2VjcmV0X2p3dF8zMmNoYXJzX21pbmltdW0="
```

---

## Encoder / Décoder en base64

```bash
# Encoder une valeur (option -n : sans retour a la ligne !)
echo -n "MonMotDePasse123!" | base64
# => TW9uTW90RGVQYXNzZTEyMyE=

# Decoder
echo "TW9uTW90RGVQYXNzZTEyMyE=" | base64 --decode
# => MonMotDePasse123!

# Verifier ce que contient un Secret dans le cluster
kubectl get secret taskflow-secret -n taskflow -o jsonpath='{.data.db_password}' | base64 --decode
```

**Pourquoi `stringData` est preferable :**
- Lisible dans le manifest (pas besoin d'encoder manuellement)
- Kubernetes encode automatiquement lors de l'application
- Moins d'erreurs humaines (oubli du `-n` = base64 avec saut de ligne = valeur corrompue)

---

## Injecter un Secret dans un Pod

```yaml
spec:
  containers:
    - name: taskflow
      image: taskflow:latest
      # Option 1 : toutes les cles du Secret en variables d'environnement
      envFrom:
        - secretRef:
            name: taskflow-secret
      # Option 2 : une cle specifique
      env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: taskflow-secret
              key: db_password
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: taskflow-secret
              key: jwt_secret
```

---

## RBAC et encryption at rest

**RBAC (Role-Based Access Control)** — limiter qui peut lire les Secrets :

```yaml
# Donner acces en lecture aux Secrets uniquement au ServiceAccount de l'app
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: taskflow
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]         # lecture seule, pas list ni watch
    resourceNames: ["taskflow-secret"]   # uniquement CE secret
```

**Encryption at rest :** configurer l'API server K8s pour chiffrer etcd (`EncryptionConfiguration`). Hors scope J5, mais à connaître pour la prod.

> Principe du moindre privilège : chaque pod ne voit que les secrets dont il a besoin.

---

<!-- _class: lead -->

# Combiner Ansible Vault + Kubernetes Secrets

---

## Le meilleur des deux mondes

**Problème :** si on met les valeurs sensibles en clair dans le manifest K8s Secret et qu'on le committe → fuite.

**Solution :** Ansible récupère les secrets depuis Vault et crée le Secret K8s dynamiquement, **sans jamais écrire les valeurs en clair sur disque ni dans git**.

```
Vault (chiffré dans git)
       │
       ▼
ansible-playbook (déchiffre en mémoire)
       │
       ▼
kubernetes.core.k8s → crée/met à jour le Secret dans le cluster
       │
       ▼
Pod taskflow monte les variables d'environnement
```

---

## Tâche Ansible — Créer le Secret K8s depuis Vault

Dans `playbooks/k8s-deploy.yml`, après avoir chargé `vars/secrets.yml` (chiffré) :

```yaml
- name: Creer le Secret Kubernetes pour TaskFlow
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: v1
      kind: Secret
      metadata:
        name: taskflow-secret
        namespace: "{{ k8s_namespace }}"
      type: Opaque
      stringData:
        db_password: "{{ vault_db_password }}"
        jwt_secret: "{{ vault_jwt_secret }}"
        taskflow_secret: "{{ vault_taskflow_secret }}"
  no_log: true   # IMPORTANT : ne pas afficher les valeurs dans les logs Ansible
```

> `no_log: true` est indispensable pour les tâches qui manipulent des secrets.

---

<!-- _class: lead -->

# Probes & Resource Limits

---

## Pourquoi des probes ?

Sans probe, Kubernetes envoie du trafic vers un pod **dès qu'il est démarré**, même si l'application n'est pas encore prête.

**Trois types de probes :**

| Probe | Rôle | Action si échec |
|-------|------|----------------|
| `startupProbe` | L'app a-t-elle fini de démarrer ? | Redémarre le pod |
| `livenessProbe` | L'app est-elle vivante ? | Redémarre le pod |
| `readinessProbe` | L'app peut-elle recevoir du trafic ? | Retire le pod des endpoints |

**Règle pratique :**
- `livenessProbe` : vérifier que l'app ne s'est pas bloquée
- `readinessProbe` : vérifier que l'app est prête à servir des requêtes

---

## Manifest — Probes httpGet

```yaml
spec:
  containers:
    - name: taskflow
      image: taskflow:1.0.0
      ports:
        - containerPort: 3000
      livenessProbe:
        httpGet:
          path: /health
          port: 3000
        initialDelaySeconds: 15   # attendre 15s avant le 1er check
        periodSeconds: 20         # verifier toutes les 20s
        failureThreshold: 3       # 3 echecs consecutifs -> restart
      readinessProbe:
        httpGet:
          path: /health
          port: 3000
        initialDelaySeconds: 5    # plus court : des que l'app repond
        periodSeconds: 10
        successThreshold: 1
```

---

## Resource Requests & Limits

**Requests** : ce que le pod **demande** au scheduler pour être placé sur un nœud.
**Limits** : le **maximum** que le pod peut consommer.

```yaml
spec:
  containers:
    - name: taskflow
      image: taskflow:1.0.0
      resources:
        requests:
          memory: "64Mi"    # garanti : 64 Mo de RAM
          cpu: "100m"       # garanti : 0.1 vCPU
        limits:
          memory: "256Mi"   # maximum : 256 Mo (OOMKill si depassé)
          cpu: "500m"       # maximum : 0.5 vCPU (throttle si depassé)
```

**Pourquoi c'est important :**
- Sans `limits`, un pod buggé peut saturer tout le nœud
- Sans `requests`, le scheduler ne peut pas planifier intelligemment
- Avec `requests == limits` → QoS **Guaranteed** (priorité max en cas de pression mémoire)

---

## Classes de QoS Kubernetes

| QoS Class | Condition | Eviction priority |
|-----------|-----------|------------------|
| **Guaranteed** | requests == limits pour tous les conteneurs | Evicté en dernier |
| **Burstable** | requests < limits (ou partiel) | Evicté en second |
| **BestEffort** | Ni requests ni limits | Evicté en premier |

```bash
# Verifier la QoS d'un pod
kubectl get pod taskflow-xxx -n taskflow -o jsonpath='{.status.qosClass}'
```

> Pour la prod : **Guaranteed** ou **Burstable** — jamais BestEffort.

---

<!-- _class: lead -->

# Bonnes pratiques Ansible

---

## Structure de projet Ansible

```
ansible-project/
├── ansible.cfg              # Configuration (inventory, roles_path…)
├── inventory/
│   ├── production/
│   │   ├── hosts.yml        # Inventaire prod
│   │   └── group_vars/
│   └── staging/
│       └── hosts.yml        # Inventaire staging
├── playbooks/
│   ├── site.yml             # Playbook principal
│   ├── k8s-deploy.yml       # Playbook K8s
│   └── vars/
│       ├── main.yml         # Variables publiques
│       └── secrets.yml      # Variables chiffrées (Vault)
└── roles/
    └── taskflow/
        ├── tasks/main.yml
        ├── templates/
        └── defaults/main.yml
```

---

## Bonnes pratiques — Tâches et playbooks

**Nommer toutes les tâches :**
```yaml
# Mauvais
- ansible.builtin.apt:
    name: nginx
    state: present

# Bien
- name: Installer nginx (serveur web)
  ansible.builtin.apt:
    name: nginx
    state: present
```

**Utiliser les FQCN (Fully Qualified Collection Names) :**
```yaml
# Eviter
- copy:
    src: foo
    dest: /tmp/foo

# Preferer
- ansible.builtin.copy:
    src: foo
    dest: /tmp/foo
```

---

## Bonnes pratiques — Check mode et tags

**Check mode (`--check`) :** simule l'exécution sans modifier le système.
```bash
ansible-playbook playbooks/k8s-deploy.yml --check --diff
# --diff affiche les changements qui seraient appliques
```

**Tags :** exécuter une partie du playbook.
```yaml
- name: Creer le Secret Kubernetes
  kubernetes.core.k8s:
    ...
  tags:
    - secrets
    - k8s

- name: Appliquer le Deployment
  kubernetes.core.k8s:
    ...
  tags:
    - deploy
    - k8s
```
```bash
ansible-playbook playbooks/k8s-deploy.yml --tags secrets
ansible-playbook playbooks/k8s-deploy.yml --skip-tags secrets
```

---

## ansible-lint — Linter pour Ansible

`ansible-lint` analyse vos playbooks et rôles pour détecter les problèmes courants.

```bash
# Installation
pip install ansible-lint

# Lancer sur un playbook
ansible-lint playbooks/k8s-deploy.yml

# Lancer sur tout le projet
ansible-lint
```

**Exemple de sortie :**
```
WARNING  Listing 3 violation(s) that are fatal:
yaml[truthy]: Use "true" or "false" (boolean) instead of "yes"
name[casing]: All names should start with an uppercase letter
no-free-form: Avoid using "command" in free-form style
```

**Corriger :** remplacer `yes`/`no` par `true`/`false`, majuscule sur les noms de tâches, utiliser les FQCN.

---

## Idempotence — Le principe fondamental

Un playbook Ansible doit pouvoir être exécuté **plusieurs fois** avec le même résultat.

```yaml
# NON idempotent : echoue a la 2e execution
- name: Creer le fichier de config
  ansible.builtin.command: touch /etc/myapp/config.conf

# Idempotent : cree uniquement si absent
- name: S assurer que le fichier de config existe
  ansible.builtin.file:
    path: /etc/myapp/config.conf
    state: touch
    mode: "0644"
```

**Verification :**
```bash
# Executer 2x : le second run doit afficher "changed=0"
ansible-playbook playbooks/k8s-deploy.yml
ansible-playbook playbooks/k8s-deploy.yml
# => PLAY RECAP ... changed=0  unreachable=0  failed=0
```

---

<!-- _class: lead -->

# Bonnes pratiques Kubernetes

---

## Labels cohérents et namespaces

**Labels recommandés (standard Kubernetes) :**
```yaml
metadata:
  labels:
    app.kubernetes.io/name: taskflow
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: taskflow-app
    app.kubernetes.io/managed-by: ansible
```

**Namespaces :** isoler les environnements et les équipes.
```bash
kubectl create namespace taskflow-prod
kubectl create namespace taskflow-staging
# Chaque namespace a ses propres RBAC, LimitRanges, NetworkPolicies
```

**Ne jamais utiliser `latest` en production :**
```yaml
# Mauvais : image non reproductible
image: taskflow:latest

# Bien : version fixée, reproductible
image: registry.example.com/taskflow:1.0.0
```

---

## Checklist production Kubernetes

**Securite :**
- [ ] `runAsNonRoot: true` dans le securityContext
- [ ] RBAC : ServiceAccount dédié par application
- [ ] Secrets via `secretRef`, jamais en variable d'env en clair
- [ ] Image taguée avec SHA ou version sémantique

**Fiabilite :**
- [ ] `livenessProbe` et `readinessProbe` configurées
- [ ] `resources.requests` et `resources.limits` définis
- [ ] `replicas >= 2` en production (haute disponibilité)
- [ ] `PodDisruptionBudget` pour les mises à jour sans coupure

**Observabilite :**
- [ ] Labels cohérents sur toutes les ressources
- [ ] Logs structurés (JSON) vers stdout/stderr
- [ ] Métriques exposées (Prometheus)

---

<!-- _class: lead -->

# Intégration DevOps — CI/CD avec Ansible & Kubernetes

---

## Le pipeline complet (rappel cours CI)

```
Développeur  →  git push
                    │
                    ▼
         ┌─── GitHub Actions ───────────────────┐
         │                                       │
         │  1. Tests unitaires (npm test)        │
         │  2. Build image Docker                │
         │  3. Push vers registry                │
         │  4. ansible-playbook k8s-deploy.yml   │
         │       └── crée Secret K8s (Vault)     │
         │       └── applique Deployment/Service │
         │       └── vérifie readinessProbe      │
         └───────────────────────────────────────┘
                    │
                    ▼
         Cluster Kubernetes (staging/prod)
```

---

## Extrait de pipeline GitHub Actions

```yaml
# .github/workflows/deploy.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build et push image Docker
        run: |
          docker build -t $REGISTRY/taskflow:${{ github.sha }} .
          docker push $REGISTRY/taskflow:${{ github.sha }}

      - name: Deployer avec Ansible
        env:
          ANSIBLE_VAULT_PASSWORD: ${{ secrets.VAULT_PASSWORD }}
          KUBECONFIG_CONTENT: ${{ secrets.KUBECONFIG }}
        run: |
          echo "$KUBECONFIG_CONTENT" > /tmp/kubeconfig
          echo "$ANSIBLE_VAULT_PASSWORD" > /tmp/.vault_pass
          ansible-playbook playbooks/k8s-deploy.yml \
            --vault-password-file /tmp/.vault_pass \
            -e "image_tag=${{ github.sha }}"
```

---

## GitOps — La notion à connaître

**GitOps** = git est la **source de vérité** de l'état du cluster.

Au lieu de pousser (`push`) les changements vers le cluster, un opérateur **tire** (`pull`) les changements depuis git.

```
git push  →  ArgoCD / Flux détecte le changement
                         │
                         ▼
              Compare l'état git vs état cluster
                         │
                         ▼
              Applique les différences (reconcile loop)
```

**Outils GitOps populaires :**
- **ArgoCD** : interface graphique, multi-cluster
- **Flux CD** : natif Kubernetes, CLI

> GitOps n'est pas au programme J5, mais c'est la suite naturelle de ce que vous construisez.

---

<!-- _class: lead -->

# Etude de cas — La chaîne complète TaskFlow

---

## 5 jours pour une infra complète

| Jour | Ce qu'on a construit | Outil principal |
|------|---------------------|-----------------|
| J1 | Provision VM, installation Docker | Ansible (modules `apt`, `service`) |
| J2 | Rôle réutilisable `taskflow`, templates Jinja2 | Ansible Roles |
| J3 | Conteneur Docker + ressources Kubernetes | Docker, kubectl, YAML K8s |
| J4 | Playbook `k8s-deploy.yml` pilote K8s | `kubernetes.core` |
| J5 | Vault + Secrets + Probes + Limits + lint | Ansible Vault, K8s Secrets |

**Résultat :** un seul `ansible-playbook` qui orchestre tout, de façon reproductible et sécurisée.

---

## La chaîne orchestrée par Ansible

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

```yaml
# playbooks/site.yml
- name: Provisionner l environnement
  import_playbook: provision.yml    # J1 : installer Docker, k3s

- name: Configurer l application
  import_playbook: configure.yml    # J2 : role taskflow, config

- name: Deployer sur Kubernetes
  import_playbook: k8s-deploy.yml   # J4-J5 : Secret Vault, Deployment,
                                    #         Service, Ingress, probes
```

**Un seul point d'entrée. Idempotent. Sécurisé. Versionné.**

---

<!-- _class: lead -->

# Démo — Tout assembler

---

## Scénario de démo

**Etape 1 — Chiffrer les secrets :**
```bash
ansible-vault encrypt playbooks/vars/secrets.yml
# → entrer le mot de passe Vault
# → le fichier est maintenant chiffré AES-256
```

**Etape 2 — Vérifier avec ansible-lint :**
```bash
ansible-lint playbooks/k8s-deploy.yml
# → corriger les avertissements (truthy, casing, FQCN)
```

**Etape 3 — Déployer :**
```bash
ansible-playbook playbooks/k8s-deploy.yml --ask-vault-pass
```

**Etape 4 — Vérifier les probes :**
```bash
kubectl describe pod -l app=taskflow -n taskflow
# → chercher "Liveness:" et "Readiness:" dans la sortie
kubectl get endpoints -n taskflow
# → les pods "Ready" apparaissent dans les endpoints
```

---

<!-- _class: lead -->

# TP5 — Déploiement complet et sécurisé de TaskFlow

---

## Objectifs du TP5

**Partie 1 — Ansible Vault (30 min)**
- [ ] Créer `playbooks/vars/secrets.yml` avec les variables sensibles
- [ ] Chiffrer le fichier avec `ansible-vault encrypt`
- [ ] Mettre à jour `playbooks/vars/main.yml` avec le pattern `vault_*`
- [ ] Exécuter le playbook avec `--ask-vault-pass` et vérifier

**Partie 2 — Kubernetes Secret via Ansible (30 min)**
- [ ] Ajouter une tâche dans `k8s-deploy.yml` qui crée `taskflow-secret`
- [ ] Utiliser `stringData` avec les variables Vault
- [ ] Ajouter `no_log: true` sur la tâche

**Partie 3 — Probes & Resource Limits (30 min)**
- [ ] Ajouter `livenessProbe` et `readinessProbe` sur le Deployment
- [ ] Définir `resources.requests` et `resources.limits`
- [ ] Vérifier avec `kubectl describe pod`

---

## TP5 — Suite et fin

**Partie 4 — Qualité et idempotence (30 min)**
- [ ] Passer `ansible-lint` et corriger tous les avertissements
- [ ] Exécuter le playbook **deux fois** → le second run doit afficher `changed=0`
- [ ] Tester le `--check --diff` avant d'appliquer

**Critères de validation :**
```bash
# 1. L'app est accessible
curl http://taskflow.local

# 2. Les probes sont configurees
kubectl describe pod -l app=taskflow -n taskflow | grep -A5 "Liveness\|Readiness"

# 3. Le Secret existe (sans voir son contenu)
kubectl get secret taskflow-secret -n taskflow

# 4. Idempotence
ansible-playbook playbooks/k8s-deploy.yml --ask-vault-pass
# => changed=0
```

---

<!-- _class: lead -->

# QCM Final & Bilan de formation

---

## QCM Final — Ce qui est évalué

**20 questions, 30 minutes**

Les thèmes couverts :

| Thème | Slides / Jour |
|-------|--------------|
| Inventaire, modules, handlers | J1 |
| Rôles, templates Jinja2, galaxy | J2 |
| Docker, Kubernetes (Pod, Deployment, Service) | J3 |
| kubernetes.core, k8s_info, conditions | J4 |
| Vault, Secrets, Probes, Limits, ansible-lint | J5 |

**Format :** QCM en ligne (lien partagé) — réponse unique ou multiple selon la question.

> Durée : 30 min — les résultats sont immédiatement disponibles.

---

## Bilan — 5 jours de formation

**Ce que vous savez maintenant :**

- Automatiser le provisionnement d'infrastructure avec **Ansible**
- Structurer des playbooks maintenables en **rôles réutilisables**
- Conteneuriser des applications avec **Docker** et les déployer sur **Kubernetes**
- Piloter un cluster Kubernetes depuis Ansible avec **`kubernetes.core`**
- Sécuriser les déploiements avec **Ansible Vault** et **Kubernetes Secrets**
- Garantir la fiabilité avec les **probes** et les **resource limits**
- Intégrer tout cela dans un **pipeline CI/CD**

**Le fil rouge TaskFlow** : une application Node.js de zéro à un déploiement sécurisé, reproductible et automatisé.

---

## Pour aller plus loin

**Ansible :**
- AWX / Ansible Automation Platform (UI web, RBAC, scheduling)
- Ansible Navigator + Execution Environments
- Test de rôles avec **Molecule**

**Kubernetes :**
- **Helm** : gestionnaire de packages K8s
- **ArgoCD / Flux** : GitOps
- **Kustomize** : surcharge de manifests sans templating
- **Prometheus + Grafana** : monitoring
- **cert-manager** : gestion des certificats TLS

**Certifications :**
- Red Hat Certified Engineer (RHCE) — Ansible
- Certified Kubernetes Administrator (CKA)
- Certified Kubernetes Application Developer (CKAD)

---

## Merci !

**Formation M2 DevOps — Ansible & Kubernetes**
ForEach Academy

---

Formateur : **Fabrice Claeys**
Contact : [fabrice.claeys@foreach.be](mailto:fabrice.claeys@foreach.be)

---

*Vos retours sont précieux — n'hésitez pas à remplir le formulaire d'évaluation.*

**Bonne continuation dans vos projets DevOps !**
