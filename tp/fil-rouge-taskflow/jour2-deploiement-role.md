# TP Jour 2 : Déploiement de l'application par rôle Ansible

> **Durée** : ~2h | **Objectif** : Structurer le déploiement de TaskFlow dans un rôle Ansible réutilisable, automatiser le build local de l'application, déployer les fichiers statiques derrière nginx sur les deux VMs, et vérifier l'idempotence.

---

## Prérequis

- TP Jour 1 terminé : les VMs `taskflow-web1` et `taskflow-web2` sont provisionnées et accessibles via `ansible web -m ping`
- Node.js >= 18 et npm disponibles sur le nœud de contrôle (pour builder l'application)
- Les collections `community.general` et `ansible.posix` sont installées

Vérification rapide :

```bash
node --version    # >= v18
npm --version
ansible web -m ping
```

---

## Étape 1 : Comprendre la structure du rôle taskflow (10 min)

### 1.1 Arborescence cible du rôle

Le rôle `taskflow` est déjà partiellement créé dans le starter. Sa structure cible est :

```
ansible/roles/taskflow/
├── defaults/
│   └── main.yml          ← valeurs par défaut (déjà présent dans le starter)
├── handlers/
│   └── main.yml          ← handler "Reload nginx" (à compléter)
├── tasks/
│   └── main.yml          ← tâches du rôle (à compléter)
├── templates/
│   └── nginx-taskflow.conf.j2  ← template vhost nginx (à créer)
└── meta/
    └── main.yml          ← métadonnées du rôle (optionnel mais bonne pratique)
```

### 1.2 Rappel : variables du rôle

Le fichier `ansible/inventory/group_vars/web.yml` (créé au Jour 1) fournit les variables utilisées par le rôle :

```yaml
app_name: taskflow
app_web_root: /var/www/taskflow
app_server_name: taskflow.local
app_http_port: 80
app_dist_local: "{{ playbook_dir }}/../dist"
```

Ces variables surchargent les valeurs par défaut de `roles/taskflow/defaults/main.yml`.

---

## Étape 2 : Écrire le template nginx (20 min)

### 2.1 Créer le template `ansible/roles/taskflow/templates/nginx-taskflow.conf.j2`

```jinja2
# {{ ansible_managed }}
# Configuration nginx pour {{ app_name }} — générée par Ansible
server {
    listen {{ app_http_port }};
    server_name {{ app_server_name }};

    root {{ app_web_root }};
    index index.html;

    # SPA : toutes les routes retombent sur index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    access_log /var/log/nginx/{{ app_name }}_access.log;
    error_log  /var/log/nginx/{{ app_name }}_error.log;
}
```

> Le commentaire `# {{ ansible_managed }}` est une bonne pratique : il indique que le fichier est géré par Ansible et ne doit pas être modifié manuellement.

---

## Étape 3 : Écrire le handler du rôle (10 min)

### 3.1 Compléter `ansible/roles/taskflow/handlers/main.yml`

```yaml
---
- name: Reload nginx
  ansible.builtin.service:
    name: nginx
    state: reloaded
```

> Un handler ne s'exécute qu'une seule fois en fin de play, et seulement si au moins une tâche l'a notifié via `notify: Reload nginx`. C'est plus efficace qu'un simple `service: state: restarted` dans chaque tâche.

---

## Étape 4 : Écrire les tâches du rôle (40 min)

### 4.1 Compléter `ansible/roles/taskflow/tasks/main.yml`

```yaml
---
# Rôle taskflow — déploie l'application TaskFlow (build statique) derrière nginx.
- name: Installer nginx
  ansible.builtin.apt:
    name: nginx
    state: present
    update_cache: true

- name: Créer la racine web de l'application
  ansible.builtin.file:
    path: "{{ app_web_root }}"
    state: directory
    owner: www-data
    group: www-data
    mode: "0755"

- name: Copier les fichiers buildés de l'application
  ansible.posix.synchronize:
    src: "{{ app_dist_local }}/"
    dest: "{{ app_web_root }}/"
    delete: true
    recursive: true
  notify: Reload nginx

- name: Déployer la configuration nginx de TaskFlow
  ansible.builtin.template:
    src: nginx-taskflow.conf.j2
    dest: "/etc/nginx/sites-available/{{ app_name }}.conf"
    owner: root
    group: root
    mode: "0644"
  notify: Reload nginx

- name: Activer le site TaskFlow
  ansible.builtin.file:
    src: "/etc/nginx/sites-available/{{ app_name }}.conf"
    dest: "/etc/nginx/sites-enabled/{{ app_name }}.conf"
    state: link
  notify: Reload nginx

- name: Désactiver le site nginx par défaut
  ansible.builtin.file:
    path: /etc/nginx/sites-enabled/default
    state: absent
  notify: Reload nginx

- name: S'assurer que nginx est démarré et activé au boot
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
```

> La tâche `Copier les fichiers buildés` utilise `ansible.posix.synchronize` (wrapper autour de `rsync`). L'option `delete: true` garantit que les fichiers obsolètes sur les VMs sont supprimés, rendant le déploiement déterministe.

---

## Étape 5 : Écrire le playbook `deploy-app.yml` (20 min)

### 5.1 Créer `ansible/playbooks/deploy-app.yml`

Ce playbook comporte deux plays :
1. Un play sur `localhost` qui installe les dépendances npm et build l'application
2. Un play sur le groupe `web` qui applique le rôle `taskflow`

```yaml
---
# =============================================================================
# TP Jour 2 — Déploiement de TaskFlow via un rôle Ansible
# 1) build local de l'application (dist/)  2) déploiement par le rôle taskflow
# Exécution : ansible-playbook playbooks/deploy-app.yml
# =============================================================================
- name: Construire l'application TaskFlow localement
  hosts: localhost
  connection: local
  gather_facts: false

  tasks:
    - name: Installer les dépendances npm
      community.general.npm:
        path: "{{ playbook_dir }}/.."
        ci: true

    - name: Builder l'application (vite build -> dist/)
      ansible.builtin.command:
        cmd: npm run build
        chdir: "{{ playbook_dir }}/.."
        creates: "{{ playbook_dir }}/../dist/index.html"

- name: Déployer TaskFlow sur les serveurs web
  hosts: web
  become: true
  gather_facts: true

  roles:
    - role: taskflow
```

> Le paramètre `creates` dans la tâche `command` la rend idempotente : si `dist/index.html` existe déjà, la commande n'est pas relancée.

---

## Étape 6 : Builder l'application et déployer (20 min)

### 6.1 Lancer le playbook complet

Depuis le dossier `ansible/` :

```bash
ansible-playbook playbooks/deploy-app.yml
```

**Résultat attendu :**

```
PLAY [Construire l'application TaskFlow localement] ****************************

TASK [Installer les dépendances npm] *******************************************
changed: [localhost]

TASK [Builder l'application (vite build -> dist/)] *****************************
changed: [localhost]

PLAY [Déployer TaskFlow sur les serveurs web] **********************************

TASK [Gathering Facts] *********************************************************
ok: [taskflow-web1]
ok: [taskflow-web2]

TASK [taskflow : Installer nginx] **********************************************
changed: [taskflow-web1]
changed: [taskflow-web2]

...

RUNNING HANDLER [taskflow : Reload nginx] **************************************
changed: [taskflow-web1]
changed: [taskflow-web2]

PLAY RECAP *********************************************************************
localhost                  : ok=2    changed=2    unreachable=0    failed=0
taskflow-web1              : ok=8    changed=6    unreachable=0    failed=0
taskflow-web2              : ok=8    changed=6    unreachable=0    failed=0
```

### 6.2 Vérifier l'accès à TaskFlow

Ouvrez un navigateur ou utilisez curl avec l'IP de chaque VM :

```bash
curl http://192.168.64.11
curl http://192.168.64.12
```

**Résultat attendu :** le HTML de l'application TaskFlow s'affiche (balise `<title>TaskFlow</title>` dans le code source).

### 6.3 Vérifier l'idempotence

```bash
ansible-playbook playbooks/deploy-app.yml
```

**Résultat attendu :**

```
PLAY RECAP *********************************************************************
localhost                  : ok=2    changed=0    unreachable=0    failed=0
taskflow-web1              : ok=8    changed=0    unreachable=0    failed=0
taskflow-web2              : ok=8    changed=0    unreachable=0    failed=0
```

---

## Checklist de validation

- [ ] Le fichier `ansible/roles/taskflow/templates/nginx-taskflow.conf.j2` existe et contient le bloc `server {}`
- [ ] Le handler `Reload nginx` est défini dans `ansible/roles/taskflow/handlers/main.yml`
- [ ] `ansible/roles/taskflow/tasks/main.yml` contient les 7 tâches (nginx, répertoire, synchronize, template, lien, désactivation default, service)
- [ ] `ansible/playbooks/deploy-app.yml` contient bien deux plays (localhost + web)
- [ ] Le dossier `dist/` a été généré à la racine du projet (présence de `dist/index.html`)
- [ ] `curl http://<IP-web1>` retourne du HTML contenant TaskFlow
- [ ] `curl http://<IP-web2>` retourne du HTML contenant TaskFlow
- [ ] Le second lancement de `deploy-app.yml` retourne `changed=0` pour les deux VMs

---

## Erreurs courantes

**`FAILED! => rsync not found on the host`**
`ansible.posix.synchronize` nécessite `rsync` sur le nœud de contrôle ET sur les hôtes cibles. Installez-le : `sudo apt install rsync` sur le nœud de contrôle, puis ajoutez `rsync` à la liste `base_packages` dans `group_vars/all.yml` et relancez `provision.yml`.

**`FAILED! => Could not find template 'nginx-taskflow.conf.j2'`**
Le template doit se trouver dans `ansible/roles/taskflow/templates/nginx-taskflow.conf.j2`. Vérifiez que vous ne l'avez pas créé directement dans `templates/` à la racine du projet.

**Le handler `Reload nginx` ne s'exécute pas**
Vérifiez l'orthographe : le nom dans `notify:` doit correspondre exactement au nom du handler (`Reload nginx`, avec majuscule). YAML est sensible à la casse.

**`curl` retourne la page nginx par défaut**
Le site par défaut n'a pas été désactivé. Vérifiez que la tâche "Désactiver le site nginx par défaut" est présente dans `tasks/main.yml` et que le fichier `/etc/nginx/sites-enabled/default` a bien disparu (`ansible web -m command -a "ls /etc/nginx/sites-enabled/" --become`).

---

## Ressources

- [Documentation Ansible — module `ansible.posix.synchronize`](https://docs.ansible.com/ansible/latest/collections/ansible/posix/synchronize_module.html)
- [Documentation Ansible — module `ansible.builtin.template`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html)
- [Documentation Ansible — Handlers](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_handlers.html)
- [Documentation Ansible — Rôles](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html)
- [Documentation nginx — Configurer un virtual host](https://nginx.org/en/docs/http/ngx_http_core_module.html)

---

**Prochain TP** : [Jour 3 — Manifests Kubernetes](./jour3-kubernetes-manifests.md)
