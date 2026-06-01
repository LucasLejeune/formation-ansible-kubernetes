# Cheatsheet Ansible — M2 DevOps

> ForEach Academy — Formateur : Fabrice Claeys

---

## 1. Installation

| Méthode | Commande |
|---|---|
| pipx (recommandé) | `pipx install ansible` |
| apt (Ubuntu PPA) | `sudo add-apt-repository ppa:ansible/ansible && sudo apt install ansible` |
| pip | `pip install ansible` |
| Vérifier | `ansible --version` |

---

## 2. Structure de projet recommandée

```
mon-projet/
├── ansible.cfg             # Configuration Ansible du projet
├── inventory/
│   ├── hosts.ini           # Inventaire INI
│   └── group_vars/
│       ├── all.yml         # Variables pour tous les groupes
│       └── web.yml         # Variables pour le groupe [web]
├── requirements.yml        # Collections et rôles Galaxy
├── site.yml                # Playbook principal (point d'entrée)
├── playbooks/
│   ├── deploy.yml
│   └── configure.yml
└── roles/
    └── taskflow/
        ├── tasks/main.yml
        ├── handlers/main.yml
        ├── templates/
        ├── files/
        ├── vars/main.yml
        ├── defaults/main.yml
        └── meta/main.yml
```

---

## 3. ansible.cfg

```ini
[defaults]
inventory          = inventory/hosts.ini
remote_user        = ubuntu
private_key_file   = ~/.ssh/taskflow_lab
host_key_checking  = False
retry_files_enabled = False
stdout_callback    = yaml
collections_path   = ~/.ansible/collections

[privilege_escalation]
become             = True
become_method      = sudo
become_user        = root
```

> Le fichier `ansible.cfg` est cherché dans l'ordre : `ANSIBLE_CONFIG` env, `./ansible.cfg`, `~/.ansible.cfg`, `/etc/ansible/ansible.cfg`.

---

## 4. Inventaire

### 4.1 Format INI

```ini
# inventory/hosts.ini

[web]
taskflow-web1 ansible_host=172.22.135.10
taskflow-web2 ansible_host=172.22.135.11

[k8s_control]
localhost ansible_connection=local

[lab:children]
web
k8s_control

[web:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/taskflow_lab
ansible_python_interpreter=/usr/bin/python3
```

### 4.2 Variables de groupe (group_vars)

```yaml
# inventory/group_vars/web.yml
app_port: 80
app_image: "taskflow:1.0.0"
nginx_worker_processes: auto
```

```yaml
# inventory/group_vars/all.yml
env: lab
log_level: info
```

### 4.3 Variables d'hôte (host_vars)

```yaml
# inventory/host_vars/taskflow-web1.yml
role: primary
```

---

## 5. Commandes ad-hoc

```bash
# Syntaxe générale
ansible <pattern> -i <inventaire> -m <module> -a "<arguments>"
```

| Objectif | Commande |
|---|---|
| Tester la connectivité | `ansible web -m ansible.builtin.ping` |
| Installer un paquet | `ansible web -m ansible.builtin.apt -a "name=nginx state=present" -b` |
| Copier un fichier | `ansible web -m ansible.builtin.copy -a "src=./index.html dest=/var/www/html/index.html"` |
| Gérer un service | `ansible web -m ansible.builtin.service -a "name=nginx state=started enabled=yes" -b` |
| Collecter les facts | `ansible web -m ansible.builtin.setup` |
| Filtrer les facts | `ansible web -m ansible.builtin.setup -a "filter=ansible_os_family"` |
| Exécuter une commande | `ansible web -m ansible.builtin.command -a "uptime"` |
| Shell avec pipes | `ansible web -m ansible.builtin.shell -a "df -h | grep sda"` |
| Redémarrer les hôtes | `ansible web -m ansible.builtin.reboot -b` |

---

## 6. ansible-playbook — Options courantes

```bash
ansible-playbook site.yml [OPTIONS]
```

| Option | Effet |
|---|---|
| `-i inventory/hosts.ini` | Spécifier l'inventaire |
| `--check` | Mode simulation (dry-run) — aucun changement réel |
| `--diff` | Afficher le diff des fichiers modifiés |
| `--check --diff` | Simulation + diff (idéal avant prod) |
| `--tags deploy` | N'exécuter que les tâches avec le tag `deploy` |
| `--skip-tags debug` | Sauter les tâches avec le tag `debug` |
| `--limit web1` | N'exécuter que sur l'hôte ou groupe `web1` |
| `--limit web:!taskflow-web2` | Groupe web sauf web2 |
| `-K` / `--ask-become-pass` | Demander le mot de passe sudo |
| `--ask-vault-pass` | Demander le mot de passe Vault |
| `--vault-password-file .vault_pass` | Lire le mot de passe Vault depuis un fichier |
| `-e "version=1.2"` | Passer une variable en ligne de commande |
| `-v / -vv / -vvv` | Niveaux de verbosité croissants |
| `--syntax-check` | Vérifier la syntaxe du playbook |
| `--list-tasks` | Lister les tâches sans les exécuter |
| `--list-hosts` | Lister les hôtes ciblés |
| `--start-at-task "Nom"` | Démarrer à une tâche spécifique |

---

## 7. Modules courants (FQCN)

### 7.1 Gestion de paquets

```yaml
# Installer un paquet
- name: Installer nginx
  ansible.builtin.apt:
    name: nginx
    state: present
    update_cache: yes

# Plusieurs paquets
- name: Installer les dépendances
  ansible.builtin.apt:
    name:
      - curl
      - vim
      - git
    state: present

# Supprimer
- name: Supprimer apache2
  ansible.builtin.apt:
    name: apache2
    state: absent
    purge: yes
```

### 7.2 Gestion des utilisateurs

```yaml
- name: Créer l'utilisateur deploy
  ansible.builtin.user:
    name: deploy
    shell: /bin/bash
    groups: sudo
    append: yes
    create_home: yes
    state: present
```

### 7.3 Copie de fichiers

```yaml
# Copier un fichier local
- name: Déployer la config nginx
  ansible.builtin.copy:
    src: files/nginx.conf
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: "0644"
  notify: Reload nginx

# Copier un contenu inline
- name: Créer un fichier de config
  ansible.builtin.copy:
    content: |
      APP_ENV=production
      APP_PORT=80
    dest: /etc/app/config
    mode: "0600"
```

### 7.4 Templates Jinja2

```yaml
- name: Déployer la config depuis template
  ansible.builtin.template:
    src: templates/nginx.conf.j2
    dest: /etc/nginx/sites-available/taskflow
    owner: root
    mode: "0644"
  notify: Reload nginx
```

### 7.5 Gestion de fichiers et répertoires

```yaml
# Créer un répertoire
- name: Créer le répertoire de l'app
  ansible.builtin.file:
    path: /opt/taskflow
    state: directory
    owner: ubuntu
    group: ubuntu
    mode: "0755"

# Créer un lien symbolique
- name: Activer le vhost nginx
  ansible.builtin.file:
    src: /etc/nginx/sites-available/taskflow
    dest: /etc/nginx/sites-enabled/taskflow
    state: link

# Supprimer un fichier
- name: Supprimer le vhost default
  ansible.builtin.file:
    path: /etc/nginx/sites-enabled/default
    state: absent
```

### 7.6 Gestion des services

```yaml
- name: Démarrer et activer nginx
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: yes

# Redémarrer
- name: Redémarrer nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
```

### 7.7 Debug

```yaml
# Afficher une variable
- name: Afficher l'IP de l'hôte
  ansible.builtin.debug:
    msg: "IP : {{ ansible_default_ipv4.address }}"

# Afficher une variable brute
- name: Inspecter une variable
  ansible.builtin.debug:
    var: app_image

# Avec niveau de verbosité
- name: Debug détaillé
  ansible.builtin.debug:
    msg: "{{ inventory_hostname }} — {{ ansible_os_family }}"
    verbosity: 2   # n'apparaît qu'avec -vv
```

### 7.8 Modifier une ligne dans un fichier

```yaml
- name: Activer le module nginx
  ansible.builtin.lineinfile:
    path: /etc/nginx/nginx.conf
    regexp: "^#?worker_processes"
    line: "worker_processes auto;"
    state: present
  notify: Reload nginx

# Blocinfile pour un bloc multi-lignes
- name: Ajouter un bloc de config
  ansible.builtin.blockinfile:
    path: /etc/hosts
    block: |
      172.22.135.10 taskflow-web1
      172.22.135.11 taskflow-web2
    marker: "# {mark} ANSIBLE MANAGED BLOCK"
```

### 7.9 Exécution de commandes

```yaml
# command : pas de shell, plus sûr
- name: Vérifier la version de Python
  ansible.builtin.command: python3 --version
  register: python_version
  changed_when: false

# shell : avec pipes, redirections
- name: Compter les connexions actives
  ansible.builtin.shell: ss -tn | grep ESTABLISHED | wc -l
  register: conn_count
  changed_when: false
```

---

## 8. Variables et précédence

Ordre de précédence (du plus faible au plus fort) :

| Priorité | Source |
|---|---|
| 1 (la plus faible) | `role/defaults/main.yml` |
| 2 | `inventory/group_vars/all` |
| 3 | `inventory/group_vars/<groupe>` |
| 4 | `inventory/host_vars/<hôte>` |
| 5 | `role/vars/main.yml` |
| 6 | `vars:` dans le playbook |
| 7 | `register:` (résultats de tâches) |
| 8 | `-e` / `--extra-vars` (la plus forte) |

```yaml
# Définir des variables dans un playbook
- hosts: web
  vars:
    app_version: "1.0.0"
    app_dir: /opt/taskflow
  vars_files:
    - vars/secrets.yml
```

---

## 9. Facts

```bash
# Lister tous les facts d'un hôte
ansible taskflow-web1 -m ansible.builtin.setup

# Filtrer
ansible web -m ansible.builtin.setup -a "filter=ansible_distribution*"
```

Facts courants :

| Fact | Valeur exemple |
|---|---|
| `ansible_hostname` | `taskflow-web1` |
| `ansible_fqdn` | `taskflow-web1.local` |
| `ansible_os_family` | `Debian` |
| `ansible_distribution` | `Ubuntu` |
| `ansible_distribution_version` | `22.04` |
| `ansible_default_ipv4.address` | `172.22.135.10` |
| `ansible_memtotal_mb` | `976` |
| `ansible_processor_vcpus` | `1` |
| `ansible_python_version` | `3.10.12` |

```yaml
# Désactiver la collecte des facts (gain de vitesse)
- hosts: web
  gather_facts: false

# Fact personnalisé (local à la machine)
# Déposer un fichier /etc/ansible/facts.d/app.fact (format INI ou JSON)
# Accessible via : ansible_local.app.<section>.<key>
```

---

## 10. Handlers

```yaml
# tasks/main.yml
- name: Copier la config nginx
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Reload nginx         # déclenche le handler si changed

# handlers/main.yml
- name: Reload nginx
  ansible.builtin.service:
    name: nginx
    state: reloaded

- name: Restart nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
```

> Les handlers ne s'exécutent qu'une fois, à la fin du play, même si notifiés plusieurs fois. Utiliser `meta: flush_handlers` pour les forcer immédiatement.

---

## 11. Templates Jinja2

### 11.1 Syntaxe de base

```jinja2
{# Commentaire #}

{# Variable #}
{{ variable }}
{{ ansible_hostname }}
{{ app_port | default(80) }}

{# Condition #}
{% if env == "production" %}
worker_processes {{ ansible_processor_vcpus * 2 }};
{% else %}
worker_processes 1;
{% endif %}

{# Boucle #}
{% for server in groups['web'] %}
    server {{ hostvars[server]['ansible_default_ipv4']['address'] }}:{{ app_port }};
{% endfor %}
```

### 11.2 Exemple : template nginx upstream

```jinja2
# {{ ansible_managed }}
upstream taskflow_backend {
{% for host in groups['web'] %}
    server {{ hostvars[host]['ansible_default_ipv4']['address'] }}:{{ app_port }};
{% endfor %}
}

server {
    listen 80;
    server_name {{ inventory_hostname }};

    location / {
        proxy_pass http://taskflow_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 11.3 Filtres Jinja2 courants

| Filtre | Exemple | Résultat |
|---|---|---|
| `default` | `{{ var \| default('none') }}` | valeur ou 'none' |
| `upper` | `{{ 'hello' \| upper }}` | `HELLO` |
| `lower` | `{{ env \| lower }}` | `production` |
| `trim` | `{{ ' hello ' \| trim }}` | `hello` |
| `replace` | `{{ 'a-b' \| replace('-','_') }}` | `a_b` |
| `int` | `{{ '8' \| int }}` | `8` |
| `string` | `{{ 80 \| string }}` | `'80'` |
| `join` | `{{ list \| join(',') }}` | `a,b,c` |
| `length` | `{{ list \| length }}` | `3` |
| `first` / `last` | `{{ list \| first }}` | premier élément |
| `sort` | `{{ list \| sort }}` | liste triée |
| `unique` | `{{ list \| unique }}` | sans doublons |
| `selectattr` | `{{ users \| selectattr('active') }}` | filtre objets |
| `to_json` | `{{ dict \| to_json }}` | JSON string |
| `from_json` | `{{ json_str \| from_json }}` | dict Python |
| `b64encode` | `{{ 'secret' \| b64encode }}` | base64 |
| `b64decode` | `{{ encoded \| b64decode }}` | texte clair |
| `password_hash` | `{{ 'pass' \| password_hash('sha512') }}` | hash SHA512 |

---

## 12. Conditions et boucles dans les playbooks

```yaml
# Condition when
- name: Installer nginx (Debian uniquement)
  ansible.builtin.apt:
    name: nginx
    state: present
  when: ansible_os_family == "Debian"

# Condition composée
- name: Déployer en prod uniquement
  ansible.builtin.template:
    src: prod.conf.j2
    dest: /etc/app/prod.conf
  when:
    - env == "production"
    - app_version is defined

# Boucle avec liste
- name: Créer les répertoires de l'app
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    mode: "0755"
  loop:
    - /opt/taskflow
    - /opt/taskflow/logs
    - /opt/taskflow/config

# Boucle avec dictionnaires
- name: Créer les utilisateurs
  ansible.builtin.user:
    name: "{{ item.name }}"
    shell: "{{ item.shell }}"
    state: present
  loop:
    - { name: deploy, shell: /bin/bash }
    - { name: monitor, shell: /bin/false }

# register + loop
- name: Vérifier les services
  ansible.builtin.service_facts:

- name: Afficher le statut nginx
  ansible.builtin.debug:
    msg: "nginx : {{ ansible_facts.services['nginx.service'].state }}"
  when: "'nginx.service' in ansible_facts.services"
```

---

## 13. Rôles

### 13.1 Créer un rôle avec ansible-galaxy

```bash
ansible-galaxy role init roles/taskflow
```

Structure générée :

```
roles/taskflow/
├── tasks/
│   └── main.yml       # Point d'entrée des tâches
├── handlers/
│   └── main.yml       # Handlers du rôle
├── templates/         # Templates Jinja2 (.j2)
├── files/             # Fichiers statiques
├── vars/
│   └── main.yml       # Variables du rôle (haute priorité)
├── defaults/
│   └── main.yml       # Valeurs par défaut (faible priorité)
├── meta/
│   └── main.yml       # Métadonnées + dépendances
└── README.md
```

### 13.2 Appeler un rôle dans un playbook

```yaml
# site.yml
---
- hosts: web
  become: true
  roles:
    - taskflow

# Avec variables surchargées
- hosts: web
  become: true
  roles:
    - role: taskflow
      vars:
        app_version: "2.0.0"

# include_role (dynamique)
- hosts: web
  tasks:
    - ansible.builtin.include_role:
        name: taskflow
      vars:
        app_port: 8080
```

### 13.3 meta/main.yml — dépendances

```yaml
galaxy_info:
  role_name: taskflow
  author: fabrice
  description: Déploie l'application TaskFlow
  license: MIT
  min_ansible_version: "2.15"
  platforms:
    - name: Ubuntu
      versions:
        - "22.04"

dependencies:
  - role: geerlingguy.docker
```

---

## 14. Collections

### 14.1 requirements.yml

```yaml
---
collections:
  - name: community.general
    version: ">=8.0.0"
  - name: ansible.posix
    version: ">=1.5.0"
  - name: kubernetes.core
    version: ">=3.0.0"

roles:
  - name: geerlingguy.docker
    version: "7.0.0"
```

### 14.2 Commandes

```bash
# Installer toutes les dépendances
ansible-galaxy collection install -r requirements.yml
ansible-galaxy role install -r requirements.yml

# Installer une collection spécifique
ansible-galaxy collection install community.general

# Lister les collections installées
ansible-galaxy collection list

# Mettre à jour
ansible-galaxy collection install -r requirements.yml --upgrade
```

---

## 15. Ansible Vault

```bash
# Créer un fichier chiffré
ansible-vault create vars/secrets.yml

# Chiffrer un fichier existant
ansible-vault encrypt vars/secrets.yml

# Editer un fichier chiffré
ansible-vault edit vars/secrets.yml

# Consulter sans modifier
ansible-vault view vars/secrets.yml

# Déchiffrer (en place)
ansible-vault decrypt vars/secrets.yml

# Chiffrer une valeur inline
ansible-vault encrypt_string 'monMotDePasse' --name 'db_password'
```

Utiliser dans un playbook :

```yaml
# vars/secrets.yml (chiffré avec Vault)
db_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  3038...

# Lancer le playbook avec le mot de passe Vault
ansible-playbook site.yml --ask-vault-pass

# Ou via fichier (ne pas committer ce fichier !)
echo "monMotDePasseVault" > .vault_pass
chmod 600 .vault_pass
ansible-playbook site.yml --vault-password-file .vault_pass
```

---

## 16. ansible-lint

```bash
# Installer
pip install ansible-lint

# Linter le projet courant
ansible-lint

# Linter un playbook spécifique
ansible-lint site.yml

# Afficher les règles disponibles
ansible-lint --list-rules

# Ignorer une règle
ansible-lint --exclude-rules no-free-form
```

Fichier de configuration `.ansible-lint` :

```yaml
---
skip_list:
  - yaml[line-length]
  - no-changed-when

warn_list:
  - command-instead-of-module
```

---

## 17. Patterns d'inventaire courants

| Pattern | Cible |
|---|---|
| `all` | Tous les hôtes |
| `web` | Groupe `web` |
| `web:k8s_control` | Union des 2 groupes |
| `web:&k8s_control` | Intersection des 2 groupes |
| `web:!taskflow-web2` | Groupe `web` sauf `taskflow-web2` |
| `taskflow-web1` | Hôte unique |
| `~taskflow-web[12]` | Regex |
| `web[0:1]` | 2 premiers hôtes du groupe |

---

## 18. Référence rapide

```bash
# Commandes d'inventaire
ansible-inventory -i inventory/ --list   # JSON complet
ansible-inventory -i inventory/ --graph  # Vue arborescente

# Tester la syntaxe d'un playbook
ansible-playbook site.yml --syntax-check

# Lister les tâches d'un playbook
ansible-playbook site.yml --list-tasks

# Lister les hôtes ciblés
ansible-playbook site.yml --list-hosts

# Exécuter avec élévation de privilèges
ansible-playbook site.yml -b -K

# Passer des variables extra
ansible-playbook site.yml -e "env=staging app_version=1.1.0"
ansible-playbook site.yml -e @vars/extra.yml
```
