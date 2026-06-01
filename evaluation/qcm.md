# QCM — Formation M2 DevOps : Ansible & Kubernetes

**Durée** : 45 minutes
**Questions** : 30
**Validation** : Note >= 10/20

> Chaque question comporte **une seule bonne réponse** parmi les quatre
> propositions. Aucune pénalité pour les mauvaises réponses.

---

## Section 1 — Fondamentaux Ansible

**1.** Quelle est la principale caractéristique de l'architecture d'Ansible par
rapport à des outils comme Puppet ou Chef ?

A. Ansible utilise un agent installé sur chaque nœud géré.
B. Ansible est agentless : il se connecte aux nœuds via SSH sans installer d'agent.
C. Ansible requiert un serveur maître dédié avec une base de données.
D. Ansible ne fonctionne qu'avec des systèmes Linux RedHat.

---

**2.** Quel protocole Ansible utilise-t-il par défaut pour se connecter aux
hôtes Linux distants ?

A. WinRM
B. Telnet
C. SSH
D. RDP

---

**3.** Dans un inventaire statique Ansible, comment regroupe-t-on les hôtes
dans un groupe nommé `web` ?

A. En préfixant chaque hôte par `web:`.
B. En créant une section `[web]` dans le fichier d'inventaire.
C. En ajoutant la variable `group=web` dans `ansible.cfg`.
D. En créant un fichier `web.ini` séparé.

---

**4.** Quelle commande permet d'exécuter le module `ping` Ansible de façon
ad-hoc sur tous les hôtes du groupe `web` ?

A. `ansible web -m ping`
B. `ansible-playbook web -m ping`
C. `ansible web --module ping`
D. `ansible-galaxy web -m ping`

---

**5.** Qu'est-ce que l'idempotence dans le contexte d'Ansible ?

A. La capacité d'Ansible à paralléliser les tâches sur plusieurs hôtes
   simultanément.
B. La propriété qui garantit que l'exécution répétée d'un playbook aboutit
   toujours au même état final, sans effectuer de modifications inutiles.
C. Le fait qu'Ansible chiffre automatiquement toutes les communications réseau.
D. La possibilité de définir des variables au niveau du groupe d'hôtes.

---

**6.** Quel fichier de configuration Ansible permet de définir le chemin de
l'inventaire par défaut, via le paramètre `inventory` ?

A. `hosts.cfg`
B. `inventory.yml`
C. `ansible.cfg`
D. `defaults.ini`

---

## Section 2 — Playbooks, rôles, variables

**7.** Dans un playbook Ansible, quelle clé YAML désigne la liste des tâches à
exécuter sur les hôtes cibles ?

A. `roles`
B. `tasks`
C. `actions`
D. `steps`

---

**8.** À quoi sert un **handler** dans un playbook Ansible ?

A. À définir les variables d'un groupe d'hôtes.
B. À exécuter une tâche uniquement lorsqu'une autre tâche l'a notifié via
   `notify`, et ce une seule fois en fin de jeu.
C. À importer un rôle depuis Ansible Galaxy.
D. À collecter les facts d'un hôte distant.

---

**9.** Quelle syntaxe Jinja2 permet d'insérer la valeur d'une variable Ansible
nommée `app_name` dans un template ?

A. `{# app_name #}`
B. `{% app_name %}`
C. `{{ app_name }}`
D. `<% app_name %>`

---

**10.** Dans quelle structure de répertoires Ansible les variables spécifiques
à un groupe d'hôtes sont-elles généralement placées ?

A. `host_vars/<nom_hote>/`
B. `group_vars/<nom_groupe>/` ou `group_vars/<nom_groupe>.yml`
C. `defaults/main.yml`
D. `vars/global.yml`

---

**11.** Quelle commande installe un rôle ou une collection Ansible depuis
Galaxy à partir d'un fichier `requirements.yml` ?

A. `ansible install -r requirements.yml`
B. `ansible-galaxy install -r requirements.yml`
C. `ansible-playbook requirements.yml`
D. `pip install -r requirements.yml`

---

**12.** Quelle est la structure minimale correcte d'un rôle Ansible nommé
`myrole` ?

A. Un répertoire `myrole/` contenant un unique fichier `main.yml`.
B. Un fichier `myrole.yml` à la racine du projet.
C. Un répertoire `myrole/` contenant au moins un sous-répertoire `tasks/` avec
   un fichier `main.yml`.
D. Un répertoire `myrole/` contenant obligatoirement les répertoires `tasks/`,
   `vars/`, `meta/`, `files/` et `templates/`.

---

## Section 3 — Fondamentaux Kubernetes

**13.** Quel composant du **control plane** Kubernetes est responsable de
l'assignation des Pods aux nœuds workers ?

A. `etcd`
B. `kube-apiserver`
C. `kube-scheduler`
D. `kubelet`

---

**14.** Quel composant Kubernetes tourne sur chaque **nœud worker** et est
responsable du démarrage et de la surveillance des conteneurs ?

A. `kube-proxy`
B. `kube-controller-manager`
C. `etcd`
D. `kubelet`

---

**15.** Quelle est la base de données distribuée utilisée par Kubernetes pour
stocker l'ensemble de l'état du cluster ?

A. PostgreSQL
B. Redis
C. etcd
D. CockroachDB

---

**16.** Quel outil en ligne de commande est l'interface principale pour
interagir avec un cluster Kubernetes ?

A. `helm`
B. `kubectl`
C. `k3d`
D. `kubeadm`

---

**17.** Qu'est-ce que **k3d** ?

A. Un outil pour convertir des fichiers Docker Compose en manifests Kubernetes.
B. Un outil qui lance des clusters Kubernetes légers (k3s) dans des conteneurs
   Docker, idéal pour le développement local.
C. Une distribution Kubernetes optimisée pour les environnements de production.
D. Un client graphique pour gérer les clusters Kubernetes.

---

**18.** Quel est le modèle de déploiement fondamental de Kubernetes, à
l'opposé d'une approche impérative ?

A. Agentless
B. Événementiel
C. Déclaratif
D. Procédural

---

## Section 4 — Objets et manifests Kubernetes

**19.** Quel objet Kubernetes est la plus petite unité déployable et peut
contenir un ou plusieurs conteneurs ?

A. Deployment
B. ReplicaSet
C. Pod
D. Service

---

**20.** Quel objet Kubernetes garantit qu'un nombre spécifié de réplicas d'un
Pod est toujours en cours d'exécution, et gère le remplacement automatique des
pods défaillants ?

A. DaemonSet
B. ReplicaSet
C. StatefulSet
D. Job

---

**21.** Quel type de `Service` Kubernetes expose l'application uniquement à
l'intérieur du cluster, sans la rendre accessible depuis l'extérieur ?

A. `NodePort`
B. `LoadBalancer`
C. `ExternalName`
D. `ClusterIP`

---

**22.** Quel objet Kubernetes permet de stocker des données de configuration
non sensibles (variables d'environnement, fichiers de config) et de les injecter
dans les Pods ?

A. `Secret`
B. `ConfigMap`
C. `PersistentVolume`
D. `Annotation`

---

**23.** À quoi servent les **labels** dans Kubernetes ?

A. À chiffrer les données sensibles stockées dans les Secrets.
B. À définir les limites de ressources CPU et mémoire d'un conteneur.
C. À identifier et sélectionner des objets Kubernetes, notamment pour les
   Services qui utilisent des `selector` pour router le trafic.
D. À décrire l'image Docker à utiliser dans un Pod.

---

**24.** Quel objet Kubernetes gère le routage du trafic HTTP/HTTPS entrant
depuis l'extérieur du cluster vers les Services internes, en fonction de règles
basées sur l'hôte ou le chemin ?

A. `Service` de type `LoadBalancer`
B. `NetworkPolicy`
C. `Ingress`
D. `Gateway`

---

## Section 5 — Ansible + K8s, sécurité, bonnes pratiques

**25.** Dans la collection `kubernetes.core`, quel module Ansible permet de
créer, mettre à jour ou supprimer n'importe quelle ressource Kubernetes en
fournissant sa définition YAML ?

A. `kubernetes.core.k8s_exec`
B. `kubernetes.core.k8s`
C. `kubernetes.core.kubectl`
D. `kubernetes.core.k8s_apply`

---

**26.** Quelle commande Ansible Vault permet de **chiffrer** un fichier de
variables existant (par exemple `secrets.yml`) ?

A. `ansible-vault create secrets.yml`
B. `ansible-vault view secrets.yml`
C. `ansible-vault encrypt secrets.yml`
D. `ansible-vault seal secrets.yml`

---

**27.** Comment les **Secrets Kubernetes** stockent-ils leurs données ?

A. Chiffrés avec AES-256 par défaut dans `etcd`.
B. Encodés en Base64 (et non chiffrés) dans `etcd` par défaut ; le chiffrement
   au repos nécessite une configuration supplémentaire.
C. En texte clair dans un fichier sur chaque nœud worker.
D. Hachés avec SHA-256, rendant leur récupération impossible.

---

**28.** Quelle directive Ansible doit être ajoutée à une tâche pour éviter
que son contenu (notamment les valeurs de secrets) n'apparaisse dans les logs
d'exécution ?

A. `become: true`
B. `ignore_errors: true`
C. `no_log: true`
D. `run_once: true`

---

**29.** Dans un manifest Kubernetes, quelle probe vérifie que le conteneur est
**prêt à recevoir du trafic** et, si elle échoue, retire le Pod des endpoints
du Service ?

A. `livenessProbe`
B. `startupProbe`
C. `healthProbe`
D. `readinessProbe`

---

**30.** Dans un manifest Kubernetes, quelle est la différence entre
`resources.requests` et `resources.limits` ?

A. `requests` définit les ressources allouées au démarrage du Pod ;
   `limits` désactive les ressources après un certain temps.
B. `requests` est la quantité de ressources que le scheduler garantit au Pod
   pour le planifier ; `limits` est le maximum que le conteneur ne peut pas
   dépasser sous peine d'être tué (OOMKill pour la mémoire) ou étranglé (CPU).
C. `requests` et `limits` sont identiques : ce sont deux façons d'écrire la
   même chose.
D. `requests` s'applique au nœud entier ; `limits` s'applique au conteneur.

---

## Barème

| Section | Questions | Points |
|---|---|---|
| 1 — Fondamentaux Ansible | 1 – 6 | 6 |
| 2 — Playbooks, rôles, variables | 7 – 12 | 6 |
| 3 — Fondamentaux Kubernetes | 13 – 18 | 6 |
| 4 — Objets et manifests K8s | 19 – 24 | 6 |
| 5 — Ansible + K8s, sécurité, bonnes pratiques | 25 – 30 | 6 |
| **Total** | **30** | **30** |

**Conversion en note sur 20** : note = (total × 20) / 30, arrondi au demi-point
le plus proche.

Exemple : 21 bonnes réponses → 21 × 20 / 30 = **14/20**.
