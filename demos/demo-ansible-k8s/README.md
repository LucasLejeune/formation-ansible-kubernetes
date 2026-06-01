# Démo 4 — Ansible pilote Kubernetes avec `kubernetes.core`

## Objectif pédagogique

Montrer qu'Ansible peut piloter Kubernetes directement via l'API K8s, en utilisant la collection `kubernetes.core`. L'intérêt : un seul outil (Ansible) pour provisionner l'infrastructure ET déployer les applications. Démontrer l'idempotence Ansible sur des ressources Kubernetes.

## Prérequis

| Outil | Version minimale | Vérification |
|-------|-----------------|--------------|
| Python | 3.8+ | `python3 --version` |
| Ansible | 2.14+ | `ansible --version` |
| kubernetes (Python) | 26+ | `pip show kubernetes` |
| kubectl | 1.27+ | `kubectl version --client` |
| k3d | 5+ | `k3d version` |
| Docker | 20+ | `docker version` |

```bash
# Installer les dépendances Python
pip install kubernetes

# Installer la collection Ansible
ansible-galaxy collection install -r requirements.yml
```

## Structure de la démo

```
demo-ansible-k8s/
├── README.md
├── inventory.ini         # Localhost en connexion locale
├── requirements.yml      # Collection kubernetes.core
├── deploy.yml            # Playbook de déploiement K8s
├── cleanup.yml           # Playbook de nettoyage (state: absent)
└── demo.sh               # Script de démonstration
```

## Lancement

```bash
chmod +x demo.sh
./demo.sh
```

Ou étape par étape :

```bash
# 1. Installer la collection
ansible-galaxy collection install -r requirements.yml

# 2. S'assurer qu'un cluster K8s est accessible
kubectl cluster-info

# 3. Déployer (1ère fois — changed)
ansible-playbook -i inventory.ini deploy.yml

# 4. Vérifier avec kubectl
kubectl get all -n demo-ansible

# 5. Rejouer (idempotence — ok)
ansible-playbook -i inventory.ini deploy.yml

# 6. Modifier un paramètre
ansible-playbook -i inventory.ini deploy.yml -e "k8s_replicas=4"

# 7. Nettoyer
ansible-playbook -i inventory.ini cleanup.yml
```

## Déroulé pas-à-pas

### Étape 1 : Collection kubernetes.core

```bash
ansible-galaxy collection install -r requirements.yml
```

`kubernetes.core` est la collection officielle Red Hat/Ansible pour piloter Kubernetes. Elle contient notamment :

| Module | Rôle |
|--------|------|
| `kubernetes.core.k8s` | Créer/modifier/supprimer tout objet K8s |
| `kubernetes.core.k8s_info` | Requêter l'API K8s + attendre des conditions |
| `kubernetes.core.k8s_scale` | Scaler un Deployment/StatefulSet/ReplicaSet |
| `kubernetes.core.helm` | Déployer et gérer des charts Helm |
| `kubernetes.core.k8s_exec` | Exécuter une commande dans un pod |

### Étape 2 : Prérequis Python

```bash
pip install kubernetes
```

Le module `kubernetes.core.k8s` utilise la bibliothèque Python `kubernetes` pour appeler l'API Kubernetes. Cette bibliothèque doit être installée sur le **control node Ansible** (pas sur les cibles).

### Étape 3 : Structure du playbook `deploy.yml`

```yaml
- name: Demo
  hosts: all
  gather_facts: false   # Pas besoin des facts — on pilote K8s
  vars:
    k8s_namespace: "demo-ansible"
    k8s_replicas: 2
  tasks:
    - name: Créer le namespace
      kubernetes.core.k8s:
        state: present   # Créer si absent, mettre à jour si différent
        definition:      # Inline YAML = équivalent d'un manifest kubectl
          apiVersion: v1
          kind: Namespace
          ...
```

Le champ `definition` accepte directement du YAML Kubernetes, identique à ce qu'on passerait à `kubectl apply`. Mais Ansible ajoute :
- Variables Ansible dans la définition (`{{ k8s_replicas }}`)
- Conditions (`when:`), boucles (`loop:`), handlers
- Gestion des secrets via `ansible-vault`

### Étape 4 : Idempotence avec kubernetes.core

`kubernetes.core.k8s` avec `state: present` est équivalent à `kubectl apply` mais avec une granularité plus fine. Ansible :
1. Récupère l'objet existant via l'API K8s
2. Compare champ par champ avec la `definition` fournie
3. N'effectue un PATCH que si une différence est détectée

### Étape 5 : Attendre avec k8s_info

```yaml
- name: Attendre que le Deployment soit disponible
  kubernetes.core.k8s_info:
    kind: Deployment
    name: webserver
    namespace: demo-ansible
    wait: true
    wait_condition:
      type: Available
      status: "True"
    wait_timeout: 120
```

Équivalent à `kubectl rollout status` mais intégré dans le playbook. Le playbook ne continue que lorsque le Deployment est réellement disponible.

### Étape 6 : Nettoyage avec state: absent

```yaml
- name: Supprimer le namespace
  kubernetes.core.k8s:
    state: absent
    definition:
      apiVersion: v1
      kind: Namespace
      metadata:
        name: demo-ansible
```

- `state: absent` = équivalent de `kubectl delete`
- Idempotent : si la ressource n'existe pas, aucune erreur

## Points pédagogiques à souligner

### Pourquoi Ansible pour K8s ?

| Besoin | kubectl seul | Ansible + kubernetes.core |
|--------|-------------|--------------------------|
| Déployer des manifests | `kubectl apply -f` | `kubernetes.core.k8s` |
| Variables dynamiques | Helm / kustomize | Variables Ansible directement |
| Secrets chiffrés | K8s Secrets (base64) | `ansible-vault` + K8s Secrets |
| Provisionner VM + déployer | 2 outils | 1 seul outil |
| Logique conditionnelle | Script shell | `when:`, `block:`, `rescue:` |
| Attendre une condition | Script + boucle | `k8s_info` avec `wait` |

### Idempotence comparée

```
kubectl apply     → Server-Side Apply (SSA), gère les conflits de champs
ansible k8s       → Client-Side Apply, compare localement
```

Les deux sont idempotents. Ansible offre en plus la visibilité `changed` / `ok` dans le PLAY RECAP, ce qui facilite l'audit et le débogage.

### Flux typique d'un pipeline CD avec Ansible + K8s

```
1. ansible-playbook provision.yml     # Créer/configurer les nœuds K8s
2. ansible-playbook deploy.yml        # Déployer l'application
3. ansible-playbook smoke-tests.yml   # Vérifier le déploiement
4. ansible-playbook rollback.yml      # Rollback si nécessaire
```

## Résultat attendu

### Première exécution

```
PLAY RECAP *****
localhost : ok=7  changed=3  unreachable=0  failed=0
```
- `changed=3` : Namespace + Deployment + Service créés

### Deuxième exécution (idempotence)

```
PLAY RECAP *****
localhost : ok=7  changed=0  unreachable=0  failed=0
```
- `changed=0` : tout était déjà dans l'état désiré

### Avec `-e "k8s_replicas=4"`

```
PLAY RECAP *****
localhost : ok=7  changed=1  unreachable=0  failed=0
```
- `changed=1` : uniquement le Deployment mis à jour (replicas: 2 → 4)

### Après cleanup

```
PLAY RECAP *****
localhost : ok=2  changed=1  unreachable=0  failed=0
```
- `changed=1` : Namespace supprimé (et toutes ses ressources)

## Nettoyage manuel

```bash
# Via Ansible (recommandé — démontre state: absent)
ansible-playbook -i inventory.ini cleanup.yml

# Via kubectl
kubectl delete namespace demo-ansible

# Supprimer le cluster k3d si créé pour cette démo
k3d cluster delete demo-ansible-k8s
```
