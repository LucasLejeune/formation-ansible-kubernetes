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
# Jour 1 — Introduction à Ansible

**DevOps Ansible & Kubernetes**
M2 — ForEach Academy

Formateur : Fabrice Claeys

---

## Programme du Jour 1

| Créneau | Contenu |
|---------|---------|
| 09h00 – 09h30 | Présentation de la semaine & objectifs |
| 09h30 – 10h30 | Pourquoi automatiser ? Infrastructure as Code |
| 10h30 – 12h30 | Ansible : architecture, inventaire, modules, playbooks |
| **12h30 – 14h00** | **Pause déjeuner** |
| 14h00 – 15h00 | Démo guidée : ad-hoc + premier playbook |
| 15h00 – 17h30 | **TP1** : Provisionner 2 VMs Multipass avec Ansible |

---

## Objectifs de la semaine

- Maîtriser Ansible pour provisionner et configurer des serveurs
- Comprendre l'orchestration de conteneurs avec Kubernetes (k3d)
- Déployer une application complète (**TaskFlow**) de A à Z

> **TaskFlow** : application Vanilla JS + Vite, servie via nginx:alpine — le fil rouge de toute la formation.

---

<!-- _class: lead -->
# Pourquoi automatiser ?

---

## Le problème du déploiement manuel

Imaginons 10 serveurs à configurer à la main :

- Connexion SSH sur chaque machine
- Mêmes commandes répétées… ou pas tout à fait les mêmes
- Un `apt-get upgrade` oublié ici, un pare-feu mal configuré là
- La nuit du déploiement : stress, copier-coller, fatigue

> **Résultat** : des environnements divergents, des bugs inexplicables en production, et des nuits blanches.

---

## Infrastructure as Code (IaC)

**Principe** : décrire l'infrastructure dans des fichiers texte versionnés.

- Le fichier **est** la source de vérité
- Versionné dans Git → historique, reverts, code review
- Reproductible : même playbook = même résultat
- Documenté par construction (le code décrit ce qu'il fait)

```bash
# Au lieu de faire ça à la main sur 10 serveurs :
ssh user@server1 "apt-get install -y nginx && systemctl enable nginx"
ssh user@server2 "apt-get install -y nginx && systemctl enable nginx"
# ...

# On écrit une fois :
ansible-playbook playbooks/provision.yml
```

---

## Idempotence : le concept clé

> **Idempotence** : exécuter une opération une ou dix fois produit le même résultat.

Un bon outil d'automatisation doit être idempotent :

- Lancer le playbook 2 fois ne casse rien
- Ansible signale `ok` (rien changé) ou `changed` (modification effectuée)
- Jamais de "déjà installé, erreur !" — Ansible vérifie l'état actuel

```
TASK [Installer nginx] **********************
ok: [web1]    ← déjà présent, rien à faire
changed: [web2] ← vient d'être installé
```

---

<!-- _class: lead -->
# Qu'est-ce qu'Ansible ?

---

## Ansible en quelques mots

- **Agentless** : aucun agent à installer sur les machines cibles
- **Push** : le nœud de contrôle pousse la configuration via SSH
- **YAML** : les playbooks sont lisibles par tous (ops, devs, managers)
- **Open source** : licence GPL, communauté très active (Ansible Galaxy)
- **Batteries incluses** : des milliers de modules prêts à l'emploi

---

## Ansible vs les autres outils

| Outil | Type | Agent ? | Langage | Usage principal |
|-------|------|---------|---------|-----------------|
| **Ansible** | Push | Non (SSH) | YAML | Config management, déploiement |
| Puppet | Pull | Oui | DSL Ruby | Config management |
| Chef | Pull | Oui | Ruby | Config management |
| Terraform | Push | Non (API) | HCL | Provisionnement infra (IaaS) |
| SaltStack | Push/Pull | Optionnel | YAML/Jinja | Config management |

> Ansible et Terraform sont complémentaires : Terraform crée les VMs, Ansible les configure.

---

<!-- _class: lead -->
# Architecture Ansible

---

## Les composants d'Ansible

```
┌─────────────────────────────────────────────┐
│           NŒUD DE CONTRÔLE                  │
│   (votre WSL2 / macOS / Linux)              │
│                                             │
│  ansible  ansible-playbook  ansible-galaxy  │
└──────────────┬──────────────────────────────┘
               │  SSH (port 22)
       ┌───────┴────────┐
       ▼                ▼
┌────────────┐   ┌────────────┐
│   web1     │   │   web2     │
│ (Multipass)│   │ (Multipass)│
│ Ubuntu 22  │   │ Ubuntu 22  │
│ PAS d'agent│   │ PAS d'agent│
└────────────┘   └────────────┘
```

---

## Nœud de contrôle vs nœuds gérés

| | Nœud de contrôle | Nœuds gérés |
|--|-----------------|-------------|
| **Rôle** | Lance les playbooks | Reçoivent la configuration |
| **Ansible installé ?** | Oui | Non |
| **Prérequis** | Python 3 + Ansible | Python 3 + SSH |
| **Dans notre lab** | WSL2 Ubuntu / macOS | VMs Multipass |
| **Communication** | Initie la connexion SSH | Répondent aux commandes |

> Python est utilisé par Ansible pour exécuter les modules à distance. Il est présent par défaut sur Ubuntu 22.04.

---

<!-- _class: lead -->
# Installation d'Ansible

---

## Installation sur Linux / WSL2

**Méthode recommandée (pipx)**

```bash
# Installer pipx si nécessaire
sudo apt update && sudo apt install -y pipx python3
pipx ensurepath

# Installer Ansible
pipx install --include-deps ansible

# Vérifier
ansible --version
```

**Méthode alternative (apt)**

```bash
sudo apt update
sudo apt install -y ansible
ansible --version
```

---

## Installation sur macOS

```bash
# Via Homebrew (recommandé)
brew install ansible

# Ou via pip3
pip3 install ansible

# Vérifier l'installation
ansible --version
ansible-playbook --version
```

---

## Sous Windows : WSL2 obligatoire

Ansible ne tourne **pas nativement sous Windows**.

```
Windows 10/11
└── WSL2 (Ubuntu 22.04)
    └── ansible (installé ici)
        └── SSH → VMs Multipass
```

**Activer WSL2 :**
```powershell
# Dans PowerShell (admin)
wsl --install -d Ubuntu-22.04
wsl --set-default-version 2
```

Ensuite, ouvrir Ubuntu et suivre les étapes Linux.

---

## Vérifier l'installation

```bash
ansible --version
# ansible [core 2.17.x]
#   config file = /etc/ansible/ansible.cfg
#   python version = 3.12.x
#   jinja version = 3.1.x

# Tester la connexion locale
ansible localhost -m ansible.builtin.ping
# localhost | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

---

<!-- _class: lead -->
# L'inventaire Ansible

---

## Qu'est-ce qu'un inventaire ?

L'inventaire liste les machines que vous gérez.

- Fichier INI ou YAML
- Organisé en **groupes** (`[web]`, `[db]`, `[all]`)
- Variables par hôte ou par groupe
- Statique (fichier) ou dynamique (script/plugin)

> C'est la première chose à écrire avant tout playbook.

---

## Inventaire au format INI

```ini
# inventory/hosts.ini

[web]
web1 ansible_host=192.168.64.10
web2 ansible_host=192.168.64.11

[db]
db1 ansible_host=192.168.64.20

[web:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

---

## Inventaire au format YAML

```yaml
# inventory/hosts.yml
all:
  children:
    web:
      hosts:
        web1:
          ansible_host: 192.168.64.10
        web2:
          ansible_host: 192.168.64.11
      vars:
        ansible_user: ubuntu
        ansible_ssh_private_key_file: ~/.ssh/id_rsa
    db:
      hosts:
        db1:
          ansible_host: 192.168.64.20
```

---

## Variables d'inventaire essentielles

| Variable | Description | Exemple |
|----------|-------------|---------|
| `ansible_host` | IP ou FQDN de la machine | `192.168.64.10` |
| `ansible_user` | Utilisateur SSH | `ubuntu` |
| `ansible_port` | Port SSH (défaut: 22) | `2222` |
| `ansible_ssh_private_key_file` | Clé privée SSH | `~/.ssh/id_rsa` |
| `ansible_become` | Activer sudo | `true` |
| `ansible_python_interpreter` | Python à utiliser | `/usr/bin/python3` |

---

<!-- _class: lead -->
# Commandes ad-hoc

---

## Qu'est-ce qu'une commande ad-hoc ?

Une commande ad-hoc = un module Ansible **sans playbook**.

Utile pour :
- Tester la connectivité
- Exécuter une tâche ponctuelle
- Explorer les facts d'un hôte
- Dépanner rapidement

Syntaxe : `ansible <cible> -m <module> -a "<arguments>"`

---

## Exemples de commandes ad-hoc

```bash
# Tester la connectivité de tous les hôtes
ansible all -m ansible.builtin.ping

# Récupérer des infos sur les hôtes web
ansible web -m ansible.builtin.setup

# Installer git sur le groupe web (avec sudo)
ansible web -m ansible.builtin.apt \
  -a "name=git state=present" \
  --become

# Redémarrer nginx sur web1
ansible web1 -m ansible.builtin.service \
  -a "name=nginx state=restarted" \
  --become

# Exécuter une commande shell
ansible web -m ansible.builtin.command -a "uptime"
```

---

## Module ping vs module command

```bash
# ping : teste que Python + SSH fonctionnent (PAS un ping ICMP)
ansible all -m ansible.builtin.ping
# web1 | SUCCESS => {"ping": "pong"}

# command : exécute une commande (sans shell, sûr)
ansible web -m ansible.builtin.command -a "df -h"

# shell : exécute via /bin/sh (pipes, redirections possibles)
ansible web -m ansible.builtin.shell -a "df -h | grep /dev/sda"
```

> **Bonne pratique** : préférer `command` à `shell`. N'utiliser `shell` que si vous avez besoin de pipes ou de redirections.

---

<!-- _class: lead -->
# Les Facts Ansible

---

## Qu'est-ce que les facts ?

Les **facts** sont des informations collectées automatiquement sur les hôtes gérés.

Ansible les récupère via le module `setup` au début de chaque play.

```bash
# Voir tous les facts d'un hôte
ansible web1 -m ansible.builtin.setup

# Filtrer les facts
ansible web1 -m ansible.builtin.setup -a "filter=ansible_distribution*"
```

---

## Exemples de facts utiles

```bash
ansible web1 -m ansible.builtin.setup \
  -a "filter=ansible_distribution,ansible_os_family,ansible_memtotal_mb"
```

```json
{
  "ansible_distribution": "Ubuntu",
  "ansible_distribution_version": "22.04",
  "ansible_os_family": "Debian",
  "ansible_memtotal_mb": 1987,
  "ansible_default_ipv4": {
    "address": "192.168.64.10"
  },
  "ansible_hostname": "web1"
}
```

---

## Utiliser les facts dans un playbook

```yaml
- name: Afficher des infos système
  hosts: web
  tasks:
    - name: Afficher la distribution
      ansible.builtin.debug:
        msg: >
          Hôte {{ inventory_hostname }} tourne sur
          {{ ansible_distribution }} {{ ansible_distribution_version }}
          avec {{ ansible_memtotal_mb }} Mo de RAM

    - name: Tâche uniquement sur Ubuntu
      ansible.builtin.apt:
        name: htop
        state: present
      when: ansible_os_family == "Debian"
      become: true
```

---

<!-- _class: lead -->
# Idempotence en pratique

---

## Les états possibles d'une tâche

```
PLAY [Configurer les serveurs web] ****

TASK [Installer nginx] **********
changed: [web1]   ← nginx vient d'être installé
ok: [web2]        ← nginx était déjà installé

TASK [Démarrer nginx] ***********
ok: [web1]        ← déjà démarré
ok: [web2]        ← déjà démarré

PLAY RECAP **********************
web1 : ok=2  changed=1  unreachable=0  failed=0
web2 : ok=2  changed=0  unreachable=0  failed=0
```

> Au **2e lancement** sans changement : tout en `ok`, `changed=0` sur tous les hôtes.

---

## Pourquoi l'idempotence est centrale

- **Sécurité** : relancer après un crash ne casse pas le système
- **CI/CD** : pipeline de déploiement rejouable
- **Audit** : `changed=0` confirme que l'état est conforme
- **Convergence** : chaque run rapproche l'état réel de l'état désiré

```yaml
# Module apt : idempotent
- ansible.builtin.apt:
    name: nginx
    state: present   # "nginx doit être présent"
    # Ansible vérifie si nginx est installé, n'installe que si nécessaire
```

> Éviter `ansible.builtin.command` / `shell` pour les opérations qui ont un module dédié : ces modules ne sont pas idempotents.

---

<!-- _class: lead -->
# Les Playbooks Ansible

---

## Structure d'un playbook

```yaml
---
# Un playbook = une liste de plays
- name: Configurer les serveurs web    # Nom du play
  hosts: web                           # Groupe cible
  become: true                         # sudo activé
  gather_facts: true                   # Collecter les facts

  tasks:                               # Liste des tâches
    - name: Mettre à jour le cache apt
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600

    - name: Installer nginx
      ansible.builtin.apt:
        name: nginx
        state: present
```

---

## Exécuter un playbook

```bash
# Lancer le playbook
ansible-playbook playbooks/provision.yml

# Avec un inventaire explicite
ansible-playbook -i inventory/hosts.ini playbooks/provision.yml

# Mode dry-run (voir ce qui changerait sans appliquer)
ansible-playbook playbooks/provision.yml --check

# Verbosité accrue (debug)
ansible-playbook playbooks/provision.yml -v   # ou -vv, -vvv

# Cibler un groupe ou un hôte spécifique
ansible-playbook playbooks/provision.yml --limit web1
```

---

## Un playbook complet : exemple

```yaml
---
- name: Provisionner les serveurs web
  hosts: web
  become: true
  gather_facts: true

  tasks:
    - name: Mettre à jour le cache apt
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600

    - name: Installer les paquets de base
      ansible.builtin.apt:
        name:
          - curl
          - git
          - vim
          - htop
        state: present

    - name: S'assurer que SSH est démarré
      ansible.builtin.service:
        name: ssh
        state: started
        enabled: true
```

---

<!-- _class: lead -->
# Les Modules Ansible

---

## Modules de base à connaître

| Module | Rôle |
|--------|------|
| `ansible.builtin.apt` | Gestion des paquets Debian/Ubuntu |
| `ansible.builtin.user` | Gestion des utilisateurs Linux |
| `ansible.builtin.copy` | Copier un fichier vers les hôtes |
| `ansible.builtin.file` | Permissions, liens, dossiers |
| `ansible.builtin.service` | Démarrer/arrêter/activer un service |
| `ansible.builtin.template` | Copier un template Jinja2 |
| `ansible.builtin.debug` | Afficher un message ou une variable |
| `community.general.ufw` | Gérer le pare-feu UFW |

---

## Exemples de modules essentiels

```yaml
# Créer un utilisateur système
- ansible.builtin.user:
    name: deploy
    shell: /bin/bash
    groups: sudo
    append: true
    create_home: true

# Copier un fichier de config
- ansible.builtin.copy:
    src: files/nginx.conf
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
  notify: Reload nginx
```

---

## Module file et service

```yaml
# Créer un répertoire
- ansible.builtin.file:
    path: /var/www/taskflow
    state: directory
    owner: deploy
    group: deploy
    mode: '0755'

# Gérer un service
- ansible.builtin.service:
    name: nginx
    state: started
    enabled: true   # démarrage automatique au boot

# Configurer UFW (pare-feu)
- community.general.ufw:
    rule: allow
    port: '80'
    proto: tcp
```

---

## FQCN : Fully Qualified Collection Name

```yaml
# Ancienne syntaxe (toujours valide mais déconseillée)
- apt:
    name: nginx

# FQCN recommandée depuis Ansible 2.10+
- ansible.builtin.apt:
    name: nginx

# Modules de collections communautaires
- community.general.ufw:
    rule: allow
    port: '22'
```

> Toujours utiliser les FQCN : évite les ambiguïtés si plusieurs collections fournissent un module du même nom.

---

<!-- _class: lead -->
# Configuration d'Ansible

---

## Le fichier ansible.cfg

Ansible cherche sa config dans cet ordre :
1. Variable `ANSIBLE_CONFIG`
2. `./ansible.cfg` (répertoire courant) ← **à privilégier**
3. `~/.ansible.cfg`
4. `/etc/ansible/ansible.cfg`

```ini
# ansible.cfg (à la racine du projet)
[defaults]
inventory       = inventory/hosts.ini
host_key_checking = False
roles_path      = roles
interpreter_python = auto_silent

[privilege_escalation]
become          = False
become_method   = sudo
```

---

## Pourquoi host_key_checking = False ?

Dans un lab avec des VMs éphémères Multipass :

```
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Cette question bloque les playbooks non interactifs.

```ini
# En lab uniquement (jamais en production !)
host_key_checking = False
```

> En production, gérer les clés SSH via `~/.ssh/known_hosts` ou un jump host.

---

<!-- _class: lead -->
# Démo

---

## Démo 1 : Commandes ad-hoc

```bash
# 1. Vérifier la connectivité
ansible all -m ansible.builtin.ping

# 2. Récupérer la mémoire disponible
ansible web -m ansible.builtin.setup \
  -a "filter=ansible_memtotal_mb"

# 3. Créer un répertoire temporaire
ansible web -m ansible.builtin.file \
  -a "path=/tmp/test_ansible state=directory" \
  --become
```

---

## Démo 2 : Premier playbook

```yaml
# playbooks/hello.yml
---
- name: Premier playbook Ansible
  hosts: web
  become: true
  gather_facts: true

  tasks:
    - name: Afficher un message de bienvenue
      ansible.builtin.debug:
        msg: "Bonjour depuis {{ inventory_hostname }} !"

    - name: Installer curl
      ansible.builtin.apt:
        name: curl
        state: present
        update_cache: true
```

```bash
ansible-playbook playbooks/hello.yml
```

---

## Démo 3 : Observer l'idempotence

```bash
# Premier lancement → changed
ansible-playbook playbooks/hello.yml
# PLAY RECAP
# web1 : ok=2  changed=1  failed=0
# web2 : ok=2  changed=1  failed=0

# Deuxième lancement → tout ok
ansible-playbook playbooks/hello.yml
# PLAY RECAP
# web1 : ok=2  changed=0  failed=0
# web2 : ok=2  changed=0  failed=0
```

> `changed=0` confirme l'idempotence : l'état est déjà conforme.

---

<!-- _class: lead -->
# TP 1 — Provisionnement de VMs avec Ansible

---

## Objectifs du TP1

À la fin du TP, vous aurez :

1. Créé 2 VMs Ubuntu via **Multipass** (`web1`, `web2`)
2. Récupéré les IPs et écrit un **inventaire** Ansible
3. Écrit `playbooks/provision.yml` pour configurer les VMs
4. Lancé le playbook **deux fois** et vérifié `changed=0` au second run

---

## Structure du projet

```
taskflow-infra/
├── ansible.cfg
├── inventory/
│   └── hosts.ini
└── playbooks/
    └── provision.yml
```

---

## Étape 1 : Créer les VMs Multipass

```bash
# Créer les VMs (Ubuntu 22.04, 1 CPU, 1 Go RAM, 5 Go disque)
multipass launch 22.04 --name web1 --cpus 1 --memory 1G --disk 5G
multipass launch 22.04 --name web2 --cpus 1 --memory 1G --disk 5G

# Vérifier qu'elles tournent
multipass list
# Name    State    IPv4             Image
# web1    Running  192.168.64.10    Ubuntu 22.04 LTS
# web2    Running  192.168.64.11    Ubuntu 22.04 LTS

# Récupérer les IPs (notez-les !)
multipass info web1 | grep IPv4
multipass info web2 | grep IPv4
```

---

## Étape 2 : Configurer l'accès SSH

```bash
# Multipass génère une clé SSH, la récupérer
# Sur Linux/WSL2 :
ls ~/.ssh/

# Si pas de clé, en générer une :
ssh-keygen -t ed25519 -C "ansible-lab" -f ~/.ssh/id_ansible

# Copier la clé publique dans chaque VM
multipass exec web1 -- bash -c \
  "mkdir -p ~/.ssh && echo '$(cat ~/.ssh/id_ansible.pub)' >> ~/.ssh/authorized_keys"
multipass exec web2 -- bash -c \
  "mkdir -p ~/.ssh && echo '$(cat ~/.ssh/id_ansible.pub)' >> ~/.ssh/authorized_keys"

# Tester la connexion SSH
ssh -i ~/.ssh/id_ansible ubuntu@192.168.64.10
```

---

## Étape 3 : Écrire l'inventaire

```ini
# inventory/hosts.ini
[web]
web1 ansible_host=192.168.64.10
web2 ansible_host=192.168.64.11

[web:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_ansible
ansible_python_interpreter=/usr/bin/python3
```

```ini
# ansible.cfg
[defaults]
inventory         = inventory/hosts.ini
host_key_checking = False

[privilege_escalation]
become        = False
become_method = sudo
```

---

## Étape 4 : Playbook provision.yml (partie 1)

```yaml
# playbooks/provision.yml
---
- name: Provisionnement de base des serveurs web
  hosts: web
  become: true
  gather_facts: true

  tasks:
    - name: Mettre à jour le cache APT
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600

    - name: Installer les paquets de base
      ansible.builtin.apt:
        name:
          - curl
          - git
          - vim
          - htop
          - ufw
        state: present
```

---

## Étape 4 : Playbook provision.yml (partie 2)

```yaml
    - name: Créer l'utilisateur deploy
      ansible.builtin.user:
        name: deploy
        shell: /bin/bash
        groups: sudo
        append: true
        create_home: true
        state: present

    - name: Autoriser deploy à utiliser sudo sans mot de passe
      ansible.builtin.copy:
        dest: /etc/sudoers.d/deploy
        content: "deploy ALL=(ALL) NOPASSWD:ALL\n"
        mode: '0440'
        validate: /usr/sbin/visudo -cf %s
```

---

## Étape 4 : Playbook provision.yml (partie 3)

```yaml
    - name: Configurer UFW - autoriser SSH
      community.general.ufw:
        rule: allow
        port: '22'
        proto: tcp

    - name: Configurer UFW - autoriser HTTP
      community.general.ufw:
        rule: allow
        port: '80'
        proto: tcp

    - name: Activer UFW
      community.general.ufw:
        state: enabled
        policy: deny
```

---

## Étape 5 : Lancer et vérifier l'idempotence

```bash
# Premier lancement (mode dry-run d'abord)
ansible-playbook playbooks/provision.yml --check

# Lancement réel
ansible-playbook playbooks/provision.yml

# Vérifier le résultat
# PLAY RECAP
# web1 : ok=8  changed=6  failed=0
# web2 : ok=8  changed=6  failed=0

# Deuxième lancement (doit afficher changed=0)
ansible-playbook playbooks/provision.yml
# PLAY RECAP
# web1 : ok=8  changed=0  failed=0
# web2 : ok=8  changed=0  failed=0
```

> `changed=0` au second run = votre playbook est idempotent !

---

## Critères de validation du TP1

- [ ] Les 2 VMs Multipass répondent à `ansible all -m ping`
- [ ] `provision.yml` contient au moins : apt update, paquets de base, user `deploy`, UFW
- [ ] Premier run : `changed > 0`, `failed=0`
- [ ] Deuxième run : `changed=0`, `failed=0` (idempotence vérifiée)
- [ ] L'utilisateur `deploy` existe sur les deux VMs
- [ ] UFW est actif avec les règles SSH et HTTP

```bash
# Vérification manuelle
ansible web -m ansible.builtin.command -a "id deploy" --become
ansible web -m ansible.builtin.command -a "ufw status" --become
```

---

<!-- _class: lead -->
# Récap du Jour 1

---

## Ce que vous avez appris aujourd'hui

**Concepts fondamentaux**
- Infrastructure as Code et idempotence
- Architecture Ansible : control node, managed nodes, SSH

**Outils & syntaxe**
- Installation d'Ansible (Linux, WSL2, macOS)
- Inventaire INI/YAML et variables d'hôte
- Commandes ad-hoc et module ping/setup

**Playbooks**
- Structure YAML d'un play (hosts, become, tasks)
- Modules FQCN : apt, user, copy, file, service, ufw
- Configuration `ansible.cfg`
- Idempotence : `ok` vs `changed`

---

## Pour aller plus loin

**Documentation officielle**
- https://docs.ansible.com — référence exhaustive des modules
- https://galaxy.ansible.com — roles et collections communautaires

**Demain — Jour 2**
- Variables et templates Jinja2
- Handlers et conditionnels
- Roles Ansible
- Déploiement de TaskFlow sur les VMs provisionnées

---

## Questions ?

Des questions sur le contenu de la journée ?

- Concepts vus ce matin ?
- Le TP1 ?
- L'environnement de lab ?

> N'hésitez pas — il n'y a pas de mauvaise question en formation.

---

<!-- _class: lead -->
# Merci pour cette première journée !

**Fabrice Claeys**
Formateur DevOps — ForEach Academy

📧 fabrice@foreach.academy

---
*Formation M2 ESTD — DevOps Ansible & Kubernetes — 35h / 5 jours*
*ForEach Academy — Tous droits réservés*
