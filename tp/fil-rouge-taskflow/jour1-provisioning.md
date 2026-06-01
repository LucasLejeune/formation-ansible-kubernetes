# TP Jour 1 : Provisioning de l'infrastructure

> **Durée** : ~2h | **Objectif** : Provisionner deux VMs Multipass avec Ansible, configurer l'inventaire, écrire un playbook idempotent de mise en place (paquets, utilisateur de déploiement, pare-feu UFW).

---

## Prérequis

- Ansible >= 2.14 installé sur votre nœud de contrôle (WSL2 Ubuntu, macOS ou Linux natif)
- Multipass installé et fonctionnel
- Docker installé (nécessaire pour k3d, utilisé à partir du Jour 3)
- Starter copié dans votre répertoire de travail

```bash
cp -r tp/fil-rouge-taskflow/starter/ ~/taskflow-lab
cd ~/taskflow-lab
```

Consultez [`../../ressources/setup-lab.md`](../../ressources/setup-lab.md) si l'un de ces outils n'est pas encore installé.

---

## Étape 1 : Créer les VMs Multipass (15 min)

> **Raccourci (et alternative sans Multipass).** Le dépôt fournit un wrapper qui crée les 2 VMs
> et injecte la clé SSH en une commande : `./ressources/lab/lab-up.sh` (auto-détecte Multipass ;
> bascule sur **Incus** si Multipass est absent, ex. sous NixOS). Voir `ressources/setup-lab.md`
> §5 bis/5 ter. Les étapes manuelles ci-dessous restent la référence pédagogique.

### 1.1 Lancer les deux VMs

```bash
multipass launch --name taskflow-web1 --cpus 1 --memory 512M --disk 5G
multipass launch --name taskflow-web2 --cpus 1 --memory 512M --disk 5G
```

### 1.2 Vérifier leur état et noter les IP

```bash
multipass list
```

**Résultat attendu :**

```
Name             State    IPv4            Image
taskflow-web1    Running  192.168.64.11   Ubuntu 22.04 LTS
taskflow-web2    Running  192.168.64.12   Ubuntu 22.04 LTS
```

> Les adresses IP varient selon votre machine. Retenez-les pour l'étape suivante.

---

## Étape 2 : Générer et injecter la clé SSH (15 min)

### 2.1 Générer une clé SSH dédiée au lab

```bash
ssh-keygen -t ed25519 -f ~/.ssh/taskflow_lab -N "" -C "taskflow-lab"
```

### 2.2 Copier la clé publique dans les deux VMs

```bash
multipass transfer ~/.ssh/taskflow_lab.pub taskflow-web1:/tmp/taskflow_lab.pub
multipass exec taskflow-web1 -- bash -c "mkdir -p ~/.ssh && cat /tmp/taskflow_lab.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

multipass transfer ~/.ssh/taskflow_lab.pub taskflow-web2:/tmp/taskflow_lab.pub
multipass exec taskflow-web2 -- bash -c "mkdir -p ~/.ssh && cat /tmp/taskflow_lab.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

### 2.3 Tester la connexion SSH manuelle

```bash
ssh -i ~/.ssh/taskflow_lab ubuntu@192.168.64.11 "hostname"
ssh -i ~/.ssh/taskflow_lab ubuntu@192.168.64.12 "hostname"
```

**Résultat attendu :** `taskflow-web1` puis `taskflow-web2` s'affichent sans mot de passe.

---

## Étape 3 : Configurer Ansible (20 min)

### 3.1 Vérifier le fichier `ansible.cfg`

Le fichier `ansible/ansible.cfg` est déjà présent dans le starter. Vérifiez son contenu :

```ini
[defaults]
inventory = inventory/hosts.ini
host_key_checking = False
roles_path = roles
retry_files_enabled = False
stdout_callback = yaml
interpreter_python = auto_silent

[privilege_escalation]
become = False
```

> `host_key_checking = False` évite les confirmations SSH lors du premier accès aux VMs.

### 3.2 Renseigner l'inventaire `ansible/inventory/hosts.ini`

Remplacez les IP par celles relevées à l'étape 1 :

```ini
# Inventaire statique TaskFlow
# Les VMs sont créées avec Multipass (voir ressources/setup-lab.md)
# Récupérer les IP : multipass list

[web]
taskflow-web1 ansible_host=192.168.64.11
taskflow-web2 ansible_host=192.168.64.12

[web:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/taskflow_lab

# Le control node lui-même, pour piloter Kubernetes (kubectl/k3d local)
[k8s_control]
localhost ansible_connection=local
```

### 3.3 Créer les variables de groupe

Créez le dossier `ansible/inventory/group_vars/` s'il n'existe pas :

```bash
mkdir -p ansible/inventory/group_vars
```

Créez `ansible/inventory/group_vars/all.yml` :

```yaml
---
# Variables communes à tous les hôtes
deploy_user: deploy
timezone: Europe/Paris

# Paquets de base installés au provisioning (J1)
base_packages:
  - curl
  - git
  - vim
  - ufw
  - htop
```

Créez `ansible/inventory/group_vars/web.yml` :

```yaml
---
# Variables du groupe web (serveurs hébergeant TaskFlow en statique, J2)
app_name: taskflow
app_web_root: /var/www/taskflow
app_server_name: taskflow.local
app_http_port: 80

# Construit localement avant déploiement (voir playbooks/deploy-app.yml)
app_dist_local: "{{ playbook_dir }}/../dist"
```

### 3.4 Installer les collections Ansible

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

**Résultat attendu :**

```
Starting galaxy collection install process
Process install dependency map
Starting collection install process
Installing 'community.general:X.Y.Z' to '...'
Installing 'ansible.posix:X.Y.Z' to '...'
Installing 'kubernetes.core:X.Y.Z' to '...'
```

---

## Étape 4 : Tester la connectivité Ansible (10 min)

### 4.1 Ping des hôtes du groupe web

Depuis le dossier `ansible/` :

```bash
ansible web -m ping
```

**Résultat attendu :**

```yaml
taskflow-web1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
taskflow-web2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### 4.2 Récupérer des faits ad hoc

```bash
ansible web -m ansible.builtin.setup -a "filter=ansible_distribution*"
```

---

## Étape 5 : Écrire et exécuter le playbook de provisioning (40 min)

### 5.1 Compléter `ansible/playbooks/provision.yml`

Le starter contient un squelette. Complétez-le pour obtenir :

```yaml
---
# =============================================================================
# TP Jour 1 — Provisioning de l'infrastructure
# Configuration de base, idempotente, des serveurs web TaskFlow.
# Exécution : ansible-playbook playbooks/provision.yml
# =============================================================================
- name: Provisionner les serveurs web TaskFlow
  hosts: web
  become: true
  gather_facts: true

  tasks:
    - name: Mettre à jour le cache APT (valide 1h)
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600

    - name: Installer les paquets de base
      ansible.builtin.apt:
        name: "{{ base_packages }}"
        state: present

    - name: Définir le fuseau horaire
      community.general.timezone:
        name: "{{ timezone }}"

    - name: Créer l'utilisateur de déploiement
      ansible.builtin.user:
        name: "{{ deploy_user }}"
        shell: /bin/bash
        groups: sudo
        append: true
        state: present

    - name: Autoriser SSH dans le pare-feu (UFW)
      community.general.ufw:
        rule: allow
        name: OpenSSH

    - name: Autoriser le trafic HTTP
      community.general.ufw:
        rule: allow
        port: "80"
        proto: tcp

    - name: Activer UFW
      community.general.ufw:
        state: enabled
        policy: deny
        direction: incoming

  post_tasks:
    - name: Afficher un récapitulatif
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} provisionné ({{ ansible_distribution }} {{ ansible_distribution_version }})"
```

### 5.2 Premier lancement

Depuis le dossier `ansible/` :

```bash
ansible-playbook playbooks/provision.yml
```

**Résultat attendu (premier lancement — des `changed` sont normaux) :**

```
PLAY [Provisionner les serveurs web TaskFlow] **********************************

TASK [Gathering Facts] *********************************************************
ok: [taskflow-web1]
ok: [taskflow-web2]

TASK [Mettre à jour le cache APT (valide 1h)] **********************************
changed: [taskflow-web1]
changed: [taskflow-web2]

...

PLAY RECAP *********************************************************************
taskflow-web1              : ok=8    changed=5    unreachable=0    failed=0
taskflow-web2              : ok=8    changed=5    unreachable=0    failed=0
```

### 5.3 Vérifier l'idempotence (second lancement)

```bash
ansible-playbook playbooks/provision.yml
```

**Résultat attendu (second lancement) :**

```
PLAY RECAP *********************************************************************
taskflow-web1              : ok=8    changed=0    unreachable=0    failed=0
taskflow-web2              : ok=8    changed=0    unreachable=0    failed=0
```

> Un playbook idempotent ne modifie rien lors d'une deuxième exécution sur un état déjà convergé. `changed=0` est le signe que toutes les tâches sont idempotentes.

---

## Checklist de validation

- [ ] Les VMs `taskflow-web1` et `taskflow-web2` sont en état `Running` dans `multipass list`
- [ ] La connexion SSH manuelle avec `~/.ssh/taskflow_lab` fonctionne sur les deux VMs
- [ ] `ansible/inventory/hosts.ini` contient les bonnes IP dans le groupe `[web]`
- [ ] `ansible web -m ping` retourne `SUCCESS` pour les deux hôtes
- [ ] `ansible-galaxy collection install -r requirements.yml` s'est terminé sans erreur
- [ ] Le premier lancement de `provision.yml` se termine sans `failed`
- [ ] Le second lancement de `provision.yml` retourne `changed=0` pour les deux hôtes
- [ ] L'utilisateur `deploy` existe sur les VMs (`ansible web -m command -a "id deploy"`)
- [ ] UFW est actif sur les VMs (`ansible web -m command -a "ufw status" --become`)

---

## Erreurs courantes

**`UNREACHABLE! => SSH Error: Permission denied`**
La clé SSH n'a pas été correctement copiée dans la VM. Vérifiez que `~/.ssh/taskflow_lab.pub` a bien été ajoutée à `~/.ssh/authorized_keys` de l'utilisateur `ubuntu` sur la VM concernée.

**`FAILED! => No package matching 'ufw' is available`**
Le cache APT n'a pas été mis à jour. Assurez-vous que la tâche `Mettre à jour le cache APT` est bien présente **avant** la tâche d'installation des paquets.

**`FAILED! => community.general is not installed`**
Vous n'avez pas lancé `ansible-galaxy collection install -r requirements.yml`, ou vous êtes dans le mauvais répertoire. Relancez la commande depuis `ansible/`.

**`ansible_ssh_private_key_file` ignoré — demande de mot de passe**
Vérifiez que la ligne `ansible_ssh_private_key_file=~/.ssh/taskflow_lab` est bien présente dans la section `[web:vars]` de `hosts.ini`, et que le chemin est correct.

---

## Ressources

- [Documentation Ansible — module `ansible.builtin.apt`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html)
- [Documentation Ansible — module `community.general.ufw`](https://docs.ansible.com/ansible/latest/collections/community/general/ufw_module.html)
- [Documentation Ansible — module `ansible.builtin.user`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/user_module.html)
- [Documentation Ansible — Inventaire statique](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html)
- [Documentation Multipass](https://multipass.run/docs)

---

**Prochain TP** : [Jour 2 — Déploiement par rôle](./jour2-deploiement-role.md)
