# Grille d'évaluation — TP fil rouge TaskFlow

**Formation** : DevOps - Ansible & Kubernetes (35h / 5 jours)
**Formateur** : Fabrice Claeys — ForEach Academy

> **Note sur 100 points.** Seuil de validation : **50 points** (= 10/20).

---

## Bloc 1 — Provisioning Ansible (20 points)

> Objectif : l'étudiant est capable de configurer Ansible et d'écrire un
> playbook de provisioning idempotent ciblant les VMs Multipass.

| Élément | Points | Vérification |
|---|---|---|
| Inventaire `hosts.ini` correct : groupe `[web]` avec les deux hôtes, section `[web:vars]` (ansible_user, clé SSH) | 5 | Ouvrir `ansible/inventory/hosts.ini` ; vérifier la présence du groupe `[web]`, de deux hôtes avec `ansible_host`, et de `[web:vars]` |
| `ansible.cfg` présent et configuré (inventory, host_key_checking, stdout_callback ou équivalent) | 5 | Ouvrir `ansible/ansible.cfg` ; vérifier au moins `inventory` et `host_key_checking = False` |
| Playbook `provision.yml` fonctionnel : paquets installés, utilisateur de déploiement créé, UFW configuré (SSH + HTTP autorisés) | 7 | Exécuter `ansible-playbook playbooks/provision.yml` ; contrôler que les tâches passent sans erreur |
| Idempotence : 2e exécution = 0 `changed`, 0 `failed` | 3 | Relancer le playbook immédiatement après la 1re exécution ; la sortie doit afficher `changed=0` |

---

## Bloc 2 — Déploiement par rôle (20 points)

> Objectif : l'étudiant structure le déploiement en rôle Ansible avec template
> Jinja2 et handler.

| Élément | Points | Vérification |
|---|---|---|
| Structure de rôle correcte sous `roles/taskflow/` : répertoires `tasks/`, `handlers/`, `templates/`, `defaults/` (et optionnellement `meta/`) | 5 | `find ansible/roles/taskflow -type d` ; les quatre dossiers doivent être présents |
| Template Jinja2 du vhost nginx (`nginx-taskflow.conf.j2`) : variables `app_http_port`, `app_server_name`, `app_web_root` utilisées | 7 | Lire `roles/taskflow/templates/nginx-taskflow.conf.j2` ; vérifier l'usage des variables Jinja2 |
| Handler `Reload nginx` déclenché par les tâches de déploiement du fichier de config et de la synchronisation des fichiers | 4 | Lire `roles/taskflow/handlers/main.yml` ; vérifier le nom du handler et sa présence dans les `notify` des tâches concernées |
| Application TaskFlow servie et accessible sur les VMs (requête HTTP répond 200) | 4 | `curl http://<IP_VM>` depuis le poste ; statut HTTP 200 attendu |

---

## Bloc 3 — Kubernetes et manifests (20 points)

> Objectif : l'étudiant construit l'image Docker, configure un cluster k3d et
> déploie TaskFlow via des manifests `kubectl`.

| Élément | Points | Vérification |
|---|---|---|
| Image `taskflow:1.0.0` construite et importée dans k3d (`k3d image import`) | 5 | `kubectl get pods -n taskflow` doit afficher les pods sans `ImagePullBackOff` ; vérifier `imagePullPolicy: IfNotPresent` dans le Deployment |
| Manifests valides : `namespace.yaml`, `configmap.yaml`, `deployment.yaml` (2 réplicas), `service.yaml`, `ingress.yaml` présents et syntaxiquement corrects | 7 | `kubectl apply --dry-run=client -f k8s/` ne doit renvoyer aucune erreur |
| Cluster k3d actif, `kubectl apply -f k8s/` exécuté sans erreur, 2 pods en état `Running` | 5 | `kubectl get pods -n taskflow` : 2 pods `Running` |
| Accès HTTP via l'Ingress (`curl http://taskflow.localhost`) retourne le HTML de l'application | 3 | `curl -H "Host: taskflow.localhost" http://localhost` ou via `/etc/hosts` ; code HTTP 200 avec contenu HTML attendu |

---

## Bloc 4 — Automatisation K8s avec Ansible (20 points)

> Objectif : l'étudiant remplace les commandes `kubectl` manuelles par un
> playbook Ansible utilisant la collection `kubernetes.core`.

| Élément | Points | Vérification |
|---|---|---|
| Collection `kubernetes.core` déclarée dans `requirements.yml` et installée | 4 | Lire `ansible/requirements.yml` ; vérifier la présence de `kubernetes.core` |
| Playbook `k8s-deploy.yml` présent, utilisant le module `kubernetes.core.k8s` pour déployer namespace, ConfigMap, Secret, Service et Ingress | 8 | Lire `ansible/playbooks/k8s-deploy.yml` ; chaque ressource K8s doit être gérée par une tâche `kubernetes.core.k8s` |
| Template Jinja2 pour le Deployment (`templates/k8s/deployment.yaml.j2`) avec variables `k8s_namespace`, `taskflow_replicas`, `taskflow_image`, et les ressources CPU/mémoire | 5 | Lire le template ; vérifier l'usage des variables Ansible dans les champs critiques |
| Idempotence vérifiée : 2e exécution de `k8s-deploy.yml` = 0 `changed` (ou uniquement des tâches qui ne changent réellement rien) | 3 | Relancer `ansible-playbook playbooks/k8s-deploy.yml` ; la sortie doit afficher `changed=0` |

---

## Bloc 5 — Sécurité et bonnes pratiques (20 points)

> Objectif : l'étudiant applique les bonnes pratiques de sécurité côté Ansible
> (Vault) et Kubernetes (Secrets, probes, ressources).

| Élément | Points | Vérification |
|---|---|---|
| `vars/secrets.yml` chiffré avec Ansible Vault (ou preuve de chiffrement : en-tête `$ANSIBLE_VAULT;1.1;...`) | 6 | Afficher les premiers octets du fichier : `head -1 ansible/playbooks/vars/secrets.yml` ; doit commencer par `$ANSIBLE_VAULT` |
| Kubernetes Secret créé via le playbook Ansible (`stringData` depuis le Vault) avec `no_log: true` sur la tâche concernée | 5 | Lire `k8s-deploy.yml` ; vérifier la tâche Secret avec `no_log: true` et l'usage de la variable issue du Vault |
| Probes `livenessProbe` et `readinessProbe` présentes dans le Deployment (manifest K8s ou template Jinja2) | 5 | Lire `k8s/deployment.yaml` ou `templates/k8s/deployment.yaml.j2` ; vérifier la présence des deux probes avec `httpGet` sur le port 80 |
| `requests` et `limits` CPU/mémoire définis dans le Deployment ; `ansible-lint` passe sans erreur bloquante | 4 | Vérifier les champs `resources` dans le Deployment ; exécuter `ansible-lint ansible/` depuis la racine du projet |

---

## Tableau récapitulatif

| # | Bloc | Points |
|---|---|---|
| 1 | Provisioning Ansible | /20 |
| 2 | Déploiement par rôle | /20 |
| 3 | Kubernetes et manifests | /20 |
| 4 | Automatisation K8s avec Ansible | /20 |
| 5 | Sécurité et bonnes pratiques | /20 |
| | **Total** | **/100** |

**Conversion en note sur 20** : note = total / 5.

---

## Barème de validation

| Score (/100) | Mention | Commentaire |
|---|---|---|
| 80 – 100 | Excellent | Maîtrise complète de l'ensemble du parcours |
| 65 – 79 | Bien | Bonne maîtrise, quelques points à consolider |
| 50 – 64 | Validé | Compétences minimales acquises |
| < 50 | Non validé | Des lacunes significatives subsistent |

> Seuil de validation : **50 points** (équivalent 10/20).

---

## Bonus (hors barème)

Les éléments suivants ne sont pas requis mais témoignent d'un niveau
d'excellence au-delà des objectifs de la formation.

- **Inventaire dynamique** : script ou plugin d'inventaire interrogeant
  Multipass ou une API pour générer `hosts` à la volée.
- **Helm via Ansible** : déploiement de TaskFlow avec `kubernetes.core.helm`
  plutôt qu'avec des manifests bruts.
- **RBAC Kubernetes** : ajout d'un `ServiceAccount`, d'un `Role` et d'un
  `RoleBinding` pour restreindre les droits des pods.
- **Monitoring** : intégration de Prometheus/Grafana ou d'un exporteur de
  métriques dans le déploiement K8s.
- **Pipeline CI/CD** : workflow GitHub Actions ou Woodpecker CI qui exécute
  `ansible-lint` et applique les manifests automatiquement.

---

## Checklist formateur

À vérifier sur le dépôt de l'étudiant avant la notation :

**Bloc 1 — Provisioning Ansible**
- [ ] `ansible/ansible.cfg` présent, `inventory` et `host_key_checking` configurés
- [ ] `ansible/inventory/hosts.ini` : groupe `[web]` avec 2 hôtes et `[web:vars]`
- [ ] `ansible/inventory/group_vars/all.yml` (ou `web.yml`) contient les variables
- [ ] `ansible/playbooks/provision.yml` : tâches apt, user, UFW présentes
- [ ] 2e exécution de `provision.yml` : `changed=0`

**Bloc 2 — Déploiement par rôle**
- [ ] Répertoire `ansible/roles/taskflow/` avec sous-dossiers `tasks/`, `handlers/`, `templates/`, `defaults/`
- [ ] `tasks/main.yml` : installation nginx, copie des fichiers, déploiement du template, activation du site
- [ ] `templates/nginx-taskflow.conf.j2` : variables Jinja2 utilisées (port, server_name, root)
- [ ] `handlers/main.yml` : handler `Reload nginx` présent
- [ ] Accès HTTP 200 sur les VMs

**Bloc 3 — Kubernetes et manifests**
- [ ] `Dockerfile` correct, image construite avec le tag `taskflow:1.0.0`
- [ ] Image importée dans k3d (`k3d image import taskflow:1.0.0 -c <cluster>`)
- [ ] Répertoire `k8s/` avec les 5 manifests (namespace, configmap, deployment, service, ingress)
- [ ] `deployment.yaml` : `replicas: 2`, `imagePullPolicy: IfNotPresent`
- [ ] `kubectl get pods -n taskflow` : 2 pods `Running`
- [ ] Accès HTTP via Ingress

**Bloc 4 — Automatisation K8s avec Ansible**
- [ ] `kubernetes.core` dans `ansible/requirements.yml`
- [ ] `ansible/playbooks/k8s-deploy.yml` : toutes les ressources K8s gérées par `kubernetes.core.k8s`
- [ ] Template `ansible/playbooks/templates/k8s/deployment.yaml.j2` avec variables
- [ ] 2e exécution de `k8s-deploy.yml` : `changed=0`

**Bloc 5 — Sécurité et bonnes pratiques**
- [ ] `ansible/playbooks/vars/secrets.yml` : commence par `$ANSIBLE_VAULT`
- [ ] Tâche Secret dans `k8s-deploy.yml` : `no_log: true`, valeur issue du Vault
- [ ] `livenessProbe` et `readinessProbe` dans le Deployment ou le template J2
- [ ] `resources.requests` et `resources.limits` définis (cpu + memory)
- [ ] `ansible-lint ansible/` : aucune erreur de niveau VIOLATION ou ERROR
