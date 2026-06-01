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

# Jour 2
## Automatisation du déploiement avec Ansible

**M2 DevOps — Ansible & Kubernetes**
ForEach Academy — Fabrice Claeys

---

## Programme du jour

| Horaire | Contenu |
|---------|---------|
| 09h00 – 09h30 | Rappel Jour 1 & inventaires |
| 09h30 – 10h30 | Variables, précédence, facts |
| 10h30 – 11h30 | Templates Jinja2 |
| 11h30 – 12h00 | Handlers |
| 12h00 – 13h30 | Déjeuner |
| 13h30 – 14h30 | Rôles Ansible : structure & création |
| 14h30 – 15h00 | Rôle `taskflow` fil rouge |
| 15h00 – 15h30 | Stratégies de déploiement, Galaxy, Vault |
| 15h30 – 17h30 | **TP2 : déployer TaskFlow sur 2 VMs** |

---

## Rappel Jour 1 — Ce qu'on sait déjà

- **Inventaire** : liste des hôtes cibles
- **Playbook** : suite de *plays* décrivant l'état souhaité
- **Tâche** : appel à un module Ansible (`ansible.builtin.package`, `ansible.builtin.copy`…)
- **Idempotence** : relancer le même playbook n'a pas d'effet si l'état est déjà atteint

> "Ansible ne décrit pas *ce qu'il faut faire* mais *ce qui doit être vrai*."

**Retour d'état des tâches :**

| Couleur | Signification |
|---------|--------------|
| `ok` (vert) | rien à faire, état déjà conforme |
| `changed` (jaune) | changement appliqué |
| `failed` (rouge) | erreur |

---

## Inventaires statiques — Format INI

```ini
# inventories/production.ini

[web]
web01 ansible_host=192.168.10.11
web02 ansible_host=192.168.10.12

[db]
db01  ansible_host=192.168.10.21

[web:vars]
ansible_user=debian
ansible_python_interpreter=/usr/bin/python3

[production:children]
web
db
```

- `[groupe]` : déclare un groupe d'hôtes
- `[groupe:vars]` : variables partagées par le groupe
- `[meta:children]` : groupe de groupes

---

## Inventaires statiques — Format YAML

```yaml
# inventories/production.yml

all:
  children:
    web:
      hosts:
        web01:
          ansible_host: 192.168.10.11
        web02:
          ansible_host: 192.168.10.12
      vars:
        ansible_user: debian
    db:
      hosts:
        db01:
          ansible_host: 192.168.10.21
```

> Format YAML : plus verbeux mais plus lisible pour les grands inventaires.

---

## Inventaires dynamiques — Notion

**Problème** : en cloud ou en CI, les IPs changent.

**Solution** : scripts ou plugins qui *génèrent* l'inventaire à la volée.

```bash
# Exemple avec le plugin AWS EC2
ansible-inventory -i aws_ec2.yml --list
```

**Plugins courants :**

| Plugin | Cible |
|--------|-------|
| `amazon.aws.aws_ec2` | AWS EC2 |
| `azure.azcollection.azure_rm` | Azure VMs |
| `google.cloud.gcp_compute` | GCP Compute |
| `kubernetes.core.k8s` | Pods Kubernetes |

> Nous utiliserons des inventaires statiques en TP. Les inventaires dynamiques seront abordés en Jour 4.

---

## Variables — Précédence (du moins au plus prioritaire)

```
defaults/main.yml          ← valeur par défaut du rôle
group_vars/all.yml         ← toutes les machines
group_vars/web.yml         ← groupe web
host_vars/web01.yml        ← hôte spécifique
vars/main.yml              ← vars du rôle (priorité haute)
-e "clé=valeur"            ← extra-vars CLI (priorité maximale)
```

> **Règle pratique** : `defaults/` pour ce qui peut être surchargé, `vars/` pour ce qui est interne au rôle.

---

## Variables — Organisation des fichiers

```
inventories/
  production/
    group_vars/
      all.yml        # variables communes à tous
      web.yml        # variables du groupe web
    host_vars/
      web01.yml      # variables spécifiques à web01
```

```yaml
# group_vars/all.yml
app_name: taskflow
app_user: www-data
nginx_port: 80

# group_vars/web.yml
app_root: /var/www/taskflow
```

```bash
# Surcharge depuis la ligne de commande
ansible-playbook deploy-app.yml -e "nginx_port=8080"
```

---

## Variables — Exemples dans un playbook

```yaml
- name: Déployer TaskFlow
  hosts: web
  vars:
    app_version: "1.2.0"
  tasks:
    - name: Créer le répertoire de l'application
      ansible.builtin.file:
        path: "{{ app_root }}/{{ app_version }}"
        state: directory
        owner: "{{ app_user }}"
        mode: "0755"

    - name: Afficher la version
      ansible.builtin.debug:
        msg: "Déploiement de {{ app_name }} v{{ app_version }}"
```

---

## Facts Ansible

Les **facts** sont des variables automatiquement collectées sur chaque hôte au début d'un play.

```bash
# Lister tous les facts d'un hôte
ansible web01 -m ansible.builtin.setup

# Filtrer les facts réseau
ansible web01 -m ansible.builtin.setup -a "filter=ansible_default_ipv4"
```

**Facts courants :**

| Variable | Contenu |
|----------|---------|
| `ansible_hostname` | nom de la machine |
| `ansible_os_family` | `Debian`, `RedHat`… |
| `ansible_default_ipv4.address` | IP principale |
| `ansible_memtotal_mb` | RAM totale |

---

## Facts — `set_fact` et `register`

```yaml
- name: Calculer l'espace disque disponible
  ansible.builtin.command: df -BG / --output=avail
  register: disk_result

- name: Stocker l'espace disponible
  ansible.builtin.set_fact:
    disk_free_gb: "{{ disk_result.stdout_lines[1] | trim | replace('G','') }}"

- name: Vérifier l'espace avant déploiement
  ansible.builtin.assert:
    that:
      - disk_free_gb | int >= 2
    fail_msg: "Espace insuffisant : {{ disk_free_gb }}G disponibles (minimum 2G)"
```

- `register` : capture la sortie d'une tâche dans une variable
- `set_fact` : crée/modifie une variable pour la suite du play
- `when` : exécution conditionnelle

---

## `when` — Exécution conditionnelle

```yaml
- name: Installer nginx (Debian/Ubuntu)
  ansible.builtin.apt:
    name: nginx
    state: present
  when: ansible_os_family == "Debian"

- name: Installer nginx (RedHat/CentOS)
  ansible.builtin.dnf:
    name: nginx
    state: present
  when: ansible_os_family == "RedHat"

- name: Déployer uniquement si le build a réussi
  ansible.posix.synchronize:
    src: dist/
    dest: "{{ app_root }}/"
  when: build_result.rc == 0
```

---

## Templates Jinja2 — Principe

Le module `ansible.builtin.template` génère un fichier texte à partir d'un **modèle `.j2`** et de variables Ansible.

```yaml
- name: Déployer la configuration nginx
  ansible.builtin.template:
    src: templates/nginx-taskflow.conf.j2
    dest: /etc/nginx/sites-available/taskflow
    owner: root
    group: root
    mode: "0644"
  notify: Reload nginx
```

**Avantages :**
- un seul template pour tous les environnements
- les valeurs spécifiques viennent des variables
- traçabilité via `{{ ansible_managed }}`

---

## Templates Jinja2 — Syntaxe de base

```jinja
{# Commentaire Jinja2 — n'apparaît pas dans le fichier généré #}

# {{ ansible_managed }}

server {
    listen {{ nginx_port }};
    server_name {{ ansible_hostname }}.{{ domain }};

    root {{ app_root }};
    index index.html;

    {# Condition : activer gzip si demandé #}
    {% if enable_gzip | default(false) %}
    gzip on;
    gzip_types text/plain application/javascript text/css;
    {% endif %}
}
```

| Syntaxe | Usage |
|---------|-------|
| `{{ var }}` | afficher une variable |
| `{% if/for %}` | logique |
| `{# ... #}` | commentaire |

---

## Templates Jinja2 — Boucles et filtres

```jinja
# Upstream généré depuis une liste de serveurs
upstream taskflow_backend {
    {% for server in backend_servers %}
    server {{ server.ip }}:{{ server.port | default(8080) }};
    {% endfor %}
}

server {
    listen {{ nginx_port }};
    server_name {{ server_name | default(ansible_hostname) }};

    location / {
        root   {{ app_root }};
        try_files $uri $uri/ /index.html;
        add_header X-App-Version "{{ app_version | upper }}";
    }
}
```

**Filtres courants :** `| default(val)`, `| upper`, `| lower`, `| trim`, `| int`, `| join(',')`

---

## Template du fil rouge — `nginx-taskflow.conf.j2`

```jinja
# {{ ansible_managed }}
# Généré par Ansible — ne pas modifier manuellement

server {
    listen {{ taskflow_nginx_port | default(80) }};
    server_name {{ ansible_hostname }};

    root {{ taskflow_app_root }};
    index index.html;

    access_log /var/log/nginx/taskflow_access.log;
    error_log  /var/log/nginx/taskflow_error.log;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(js|css|png|ico|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

---

## Handlers — Principe

Un **handler** est une tâche spéciale déclenchée par `notify` et exécutée **une seule fois en fin de play**, même si plusieurs tâches l'ont notifié.

```yaml
tasks:
  - name: Déployer la configuration nginx
    ansible.builtin.template:
      src: nginx-taskflow.conf.j2
      dest: /etc/nginx/sites-available/taskflow
    notify: Reload nginx        # <-- déclencheur

  - name: Activer le site
    ansible.builtin.file:
      src: /etc/nginx/sites-available/taskflow
      dest: /etc/nginx/sites-enabled/taskflow
      state: link
    notify: Reload nginx        # <-- même handler, appelé une seule fois

handlers:
  - name: Reload nginx
    ansible.builtin.service:
      name: nginx
      state: reloaded
```

---

## Handlers — Points clés

- **Exécution différée** : le handler s'exécute après toutes les tâches du play
- **Idempotent** : si la tâche est `ok` (pas de changement), le handler n'est **pas** déclenché
- **Dédupliqué** : notifié 3 fois → exécuté 1 fois
- **Forcer l'exécution** : `ansible-playbook --force-handlers`

```yaml
# Forcer un flush des handlers en cours de play
- name: Flush handlers avant les tests
  ansible.builtin.meta: flush_handlers
```

> Les handlers sont parfaits pour : `reload nginx`, `restart service`, `clear cache`

---

## Rôles — Pourquoi ?

**Problème** : les playbooks grandissent et deviennent difficiles à maintenir.

**Solution** : les **rôles** encapsulent une unité logique de configuration.

**Avantages :**

| Critère | Sans rôle | Avec rôle |
|---------|-----------|-----------|
| Réutilisabilité | copier-coller | `roles: [mon_role]` |
| Partage | difficile | `ansible-galaxy` |
| Tests | monolithique | unitaire par rôle |
| Lisibilité | 500 lignes | playbook de 20 lignes |

> Un rôle = une responsabilité. Exemple : `nginx`, `postgresql`, `taskflow`.

---

## Rôles — Structure standard

```
roles/
  taskflow/
    tasks/
      main.yml        # point d'entrée des tâches
    handlers/
      main.yml        # handlers du rôle
    templates/
      nginx-taskflow.conf.j2
    defaults/
      main.yml        # variables avec valeur par défaut (surchargeables)
    vars/
      main.yml        # variables internes (non surchargeables)
    files/
      logo.png        # fichiers statiques
    meta/
      main.yml        # métadonnées (dépendances, auteur)
    README.md
```

---

## Rôles — Création avec ansible-galaxy

```bash
# Initialiser la structure d'un rôle
ansible-galaxy role init roles/taskflow

# Résultat
- Role roles/taskflow was created successfully
```

```bash
# Utiliser le rôle dans un playbook
# playbooks/deploy-app.yml
- name: Déployer TaskFlow
  hosts: web
  become: true
  roles:
    - role: taskflow
      vars:
        taskflow_nginx_port: 80
```

> `ansible-galaxy role init` crée automatiquement toute l'arborescence avec des fichiers vides documentés.

---

## Rôle `taskflow` — `defaults/main.yml`

```yaml
---
# defaults/main.yml — valeurs par défaut surchargeables

# Répertoire de déploiement
taskflow_app_root: /var/www/taskflow

# Utilisateur propriétaire des fichiers
taskflow_app_user: www-data
taskflow_app_group: www-data

# Port nginx
taskflow_nginx_port: 80

# Nom du vhost nginx
taskflow_vhost_name: taskflow

# Répertoire local du build (relatif au playbook)
taskflow_build_src: "{{ playbook_dir }}/../dist/"
```

---

## Rôle `taskflow` — `tasks/main.yml` (1/2)

```yaml
---
# tasks/main.yml

- name: Installer nginx
  ansible.builtin.package:
    name: nginx
    state: present

- name: Créer le répertoire de l'application
  ansible.builtin.file:
    path: "{{ taskflow_app_root }}"
    state: directory
    owner: "{{ taskflow_app_user }}"
    group: "{{ taskflow_app_group }}"
    mode: "0755"

- name: Synchroniser le build dist/ vers les VMs
  ansible.posix.synchronize:
    src: "{{ taskflow_build_src }}"
    dest: "{{ taskflow_app_root }}/"
    delete: true
    checksum: true
  notify: Reload nginx
```

---

## Rôle `taskflow` — `tasks/main.yml` (2/2)

```yaml
- name: Déployer le vhost nginx depuis le template
  ansible.builtin.template:
    src: nginx-taskflow.conf.j2
    dest: "/etc/nginx/sites-available/{{ taskflow_vhost_name }}"
    owner: root
    group: root
    mode: "0644"
  notify: Reload nginx

- name: Activer le site nginx
  ansible.builtin.file:
    src: "/etc/nginx/sites-available/{{ taskflow_vhost_name }}"
    dest: "/etc/nginx/sites-enabled/{{ taskflow_vhost_name }}"
    state: link
  notify: Reload nginx

- name: S'assurer que nginx est démarré et activé
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
```

---

## Rôle `taskflow` — `handlers/main.yml`

```yaml
---
# handlers/main.yml

- name: Reload nginx
  ansible.builtin.service:
    name: nginx
    state: reloaded
```

**Rappel du flux complet :**

```
tasks/main.yml          handlers/main.yml
─────────────────       ─────────────────
Synchroniser dist/  ─┐
Déployer vhost     ──┼──► notify "Reload nginx" ──► [fin du play] ──► Reload nginx (x1)
Activer le site    ─┘
```

---

## Stratégies de déploiement — `serial`

Par défaut, Ansible exécute chaque tâche sur **tous les hôtes** avant de passer à la suivante.

```yaml
- name: Déployer en rolling update
  hosts: web
  serial: 1          # un hôte à la fois
  # serial: 2        # 2 hôtes simultanément
  # serial: "25%"    # 25% des hôtes à la fois
  roles:
    - taskflow
```

**Avec `pre_tasks` / `post_tasks` :**

```yaml
- hosts: web
  serial: 1
  pre_tasks:
    - name: Retirer du load balancer
      community.general.haproxy:
        state: disabled
        host: "{{ inventory_hostname }}"
  roles:
    - taskflow
  post_tasks:
    - name: Remettre dans le load balancer
      community.general.haproxy:
        state: enabled
        host: "{{ inventory_hostname }}"
```

---

## Tags — Exécution sélective

```yaml
tasks:
  - name: Installer nginx
    ansible.builtin.package:
      name: nginx
      state: present
    tags: [install, nginx]

  - name: Synchroniser le build
    ansible.posix.synchronize:
      src: dist/
      dest: "{{ taskflow_app_root }}/"
    tags: [deploy, app]

  - name: Déployer la configuration nginx
    ansible.builtin.template:
      src: nginx-taskflow.conf.j2
      dest: /etc/nginx/sites-available/taskflow
    tags: [config, nginx]
```

```bash
ansible-playbook deploy-app.yml --tags deploy        # uniquement le déploiement
ansible-playbook deploy-app.yml --skip-tags install  # tout sauf l'installation
```

---

## Dry-run et diff

```bash
# Mode dry-run : voir ce qui SERAIT fait, sans l'appliquer
ansible-playbook deploy-app.yml --check

# Afficher les différences sur les fichiers modifiés
ansible-playbook deploy-app.yml --check --diff

# Utile avant une mise en production !
```

**Exemple de sortie `--diff` :**

```diff
--- /etc/nginx/sites-available/taskflow (avant)
+++ /etc/nginx/sites-available/taskflow (après)
@@ -1,5 +1,5 @@
 server {
-    listen 80;
+    listen 8080;
     server_name web01;
```

> Toujours lancer `--check --diff` avant un déploiement en production.

---

## Ansible Galaxy — Collections

Les **collections** regroupent modules, plugins et rôles par namespace.

```bash
# Installer une collection
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix

# Depuis un fichier requirements.yml
ansible-galaxy collection install -r requirements.yml
```

```yaml
# requirements.yml
---
collections:
  - name: community.general
    version: ">=9.0.0"
  - name: ansible.posix
    version: ">=1.5.0"

roles:
  - name: geerlingguy.nginx
    src: https://github.com/geerlingguy/ansible-role-nginx
```

---

## Ansible Galaxy — Modules utilisés en TP

| FQCN | Usage |
|------|-------|
| `ansible.builtin.package` | installer des paquets |
| `ansible.builtin.template` | déployer un fichier depuis `.j2` |
| `ansible.builtin.file` | créer/supprimer fichiers, liens |
| `ansible.builtin.service` | gérer les services systemd |
| `ansible.posix.synchronize` | synchroniser des répertoires (rsync) |
| `ansible.builtin.assert` | vérifier des conditions |
| `ansible.builtin.debug` | afficher des messages |
| `community.general.haproxy` | gérer HAProxy |

> **FQCN = Fully Qualified Collection Name** — toujours utiliser le nom complet en production.

---

## Ansible Vault — Introduction (teaser Jour 5)

**Problème** : ne jamais stocker de mots de passe en clair dans Git.

```bash
# Chiffrer un fichier de variables
ansible-vault encrypt group_vars/all/secrets.yml

# Editer un fichier chiffré
ansible-vault edit group_vars/all/secrets.yml

# Utiliser au déploiement
ansible-playbook deploy-app.yml --ask-vault-pass
ansible-playbook deploy-app.yml --vault-password-file ~/.vault_pass
```

```yaml
# group_vars/all/secrets.yml (chiffré par Vault)
db_password: "S3cr3t_P@ssw0rd"
api_key: "abc123xyz"
```

> Nous approfondirons Vault au **Jour 5** : rotation de secrets, intégration CI/CD, HashiCorp Vault.

---

<!-- _class: lead -->

## Demo

1. `ansible-galaxy role init roles/taskflow`
2. Remplir `tasks/main.yml`, `defaults/main.yml`, `templates/`
3. Lancer `ansible-playbook playbooks/deploy-app.yml`
4. Modifier le template nginx → observer le handler se déclencher
5. Relancer → confirmer l'idempotence (`changed=0`)

```bash
# Build local préalable
cd taskflow-app && npm run build

# Déploiement
ansible-playbook playbooks/deploy-app.yml -i inventories/production.ini -v
```

---

<!-- _class: lead -->

## TP2 — Déployer TaskFlow avec un rôle Ansible

**Objectifs :**

1. Créer le rôle `taskflow` avec `ansible-galaxy role init`
2. Builder l'application TaskFlow localement (`npm run build`)
3. Déployer l'app sur **2 VMs** via `playbooks/deploy-app.yml`
4. Vérifier que nginx sert correctement le site
5. Relancer le playbook et prouver l'**idempotence** (`changed=0`)

**Durée :** 2h

---

## TP2 — Structure attendue du projet

```
.
├── inventories/
│   └── tp.ini                  # vos 2 VMs
├── group_vars/
│   └── web.yml                 # variables du groupe web
├── playbooks/
│   └── deploy-app.yml          # le playbook de déploiement
├── roles/
│   └── taskflow/
│       ├── defaults/main.yml
│       ├── handlers/main.yml
│       ├── tasks/main.yml
│       └── templates/
│           └── nginx-taskflow.conf.j2
└── requirements.yml            # ansible.posix
```

---

## TP2 — Playbook `playbooks/deploy-app.yml`

```yaml
---
# playbooks/deploy-app.yml

- name: Déployer TaskFlow sur les serveurs web
  hosts: web
  become: true
  roles:
    - role: taskflow
```

**Commandes utiles :**

```bash
# Vérifier la syntaxe
ansible-playbook playbooks/deploy-app.yml --syntax-check

# Dry-run
ansible-playbook playbooks/deploy-app.yml --check --diff

# Déploiement réel
ansible-playbook playbooks/deploy-app.yml -i inventories/tp.ini -v

# Vérifier le site
curl http://<ip-vm>/
```

---

## TP2 — Critères de validation

| Critère | Commande de vérification |
|---------|--------------------------|
| nginx installé et actif | `systemctl status nginx` sur les VMs |
| Fichiers déployés | `ls /var/www/taskflow/` |
| Vhost configuré | `cat /etc/nginx/sites-enabled/taskflow` |
| Site accessible | `curl http://<ip-vm>/` |
| Idempotence | 2e run = `changed=0, failed=0` |
| Handler déclenché | modifier le template, relancer → `changed=1` |

> Bonus : ajouter un tag `deploy` sur la tâche de synchronisation et tester `--tags deploy`.

---

## Récapitulatif Jour 2

**Ce que vous maîtrisez maintenant :**

- Inventaires statiques INI/YAML + notion d'inventaire dynamique
- Précédence des variables (`defaults` < `group_vars` < `host_vars` < `-e`)
- Facts Ansible, `register`, `set_fact`, `when`
- Templates Jinja2 : `{{ }}`, `{% if %}`, `{% for %}`, filtres
- Handlers : `notify` + exécution différée et idempotente
- Rôles : structure standard, `ansible-galaxy role init`
- Rôle `taskflow` du fil rouge : nginx + synchronize + template
- Stratégies : `serial`, `pre/post_tasks`, `tags`, `--check --diff`
- Collections Galaxy, `requirements.yml`
- Introduction à Ansible Vault

---

<!-- _class: lead -->

## Questions ?

**Fabrice Claeys**
Formateur DevOps — ForEach Academy
claeys.fabrice@gmail.com

---

*Jour 3 : Kubernetes — Introduction, Pods, Deployments, Services*

---

**Ressources :**
- Documentation officielle : [docs.ansible.com](https://docs.ansible.com)
- Ansible Galaxy : [galaxy.ansible.com](https://galaxy.ansible.com)
- Projet fil rouge : dépôt `taskflow-devops`
