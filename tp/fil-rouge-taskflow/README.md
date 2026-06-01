# TaskFlow — Documentation du projet fil rouge

## Présentation de TaskFlow

TaskFlow est une application web de gestion de tâches minimaliste développée en Vanilla JavaScript avec Vite comme outil de build. Elle permet de créer, afficher et supprimer des tâches dans une interface responsive.

La simplicité de l'application est intentionnelle : l'objectif pédagogique porte sur l'infrastructure et l'automatisation, pas sur le code applicatif.

## Stack technique

| Composant | Technologie | Version |
|---|---|---|
| Langage | Vanilla JavaScript (ES Modules) | — |
| Build tool | Vite | >= 5 |
| Tests | Vitest | >= 1 |
| Linting | ESLint | >= 9 |
| Serveur web (VMs) | nginx | >= 1.24 |
| Serveur web (Docker) | nginx:alpine | latest |
| Image Docker | `taskflow:1.0.0` | — |

## Arborescence du projet

```
fil-rouge-taskflow/
├── README.md                        ← ce fichier
├── starter/                         ← point de départ des étudiants
│   ├── index.html
│   ├── package.json
│   ├── vite.config.js
│   ├── vitest.config.js
│   ├── Dockerfile                   ← multi-stage (node:20-alpine + nginx:alpine)
│   ├── src/
│   │   ├── app.js
│   │   ├── tasks.js
│   │   └── styles.css
│   ├── tests/
│   │   └── tasks.test.js
│   ├── ansible/                     ← squelettes Ansible avec TODO
│   │   ├── ansible.cfg
│   │   ├── requirements.yml
│   │   ├── inventory/
│   │   │   ├── hosts.ini            ← TODO J1 : renseigner les IP
│   │   │   └── group_vars/          ← TODO J1 : créer all.yml et web.yml
│   │   ├── playbooks/
│   │   │   ├── provision.yml        ← TODO J1 : compléter
│   │   │   ├── deploy-app.yml       ← TODO J2 : créer
│   │   │   ├── k8s-deploy.yml       ← TODO J4 : créer
│   │   │   ├── vars/
│   │   │   │   ├── k8s.yml          ← TODO J4 : créer
│   │   │   │   └── secrets.yml      ← TODO J5 : créer + chiffrer
│   │   │   └── templates/
│   │   │       └── k8s/
│   │   │           └── deployment.yaml.j2  ← TODO J4 : créer
│   │   └── roles/
│   │       └── taskflow/            ← TODO J2 : compléter le rôle
│   │           ├── defaults/main.yml
│   │           ├── handlers/main.yml
│   │           ├── tasks/main.yml
│   │           └── templates/       ← TODO J2 : nginx-taskflow.conf.j2
│   └── k8s/                         ← TODO J3 : créer les manifests
│       └── README.md
└── solution/                        ← solution de référence (accès formateur)
    ├── ansible/                     ← solution complète Ansible
    └── k8s/                         ← solution complète K8s
```

## Utiliser le starter

Le dossier `starter/` est le **point de départ officiel** des étudiants.

```bash
# Copier le starter dans votre espace de travail
cp -r starter/ ~/taskflow-lab
cd ~/taskflow-lab

# Vérifier que l'application démarre
npm install
npm run dev

# Lancer les tests
npm test
```

## Accès à la solution

Le dossier `solution/` contient la solution complète et fonctionnelle. Il est destiné au **formateur** pour les démonstrations et les corrections.

Les étudiants ne doivent y accéder qu'après avoir terminé le TP ou en cas de blocage prolongé.

## Prérequis du lab

Avant de commencer le Jour 1, assurez-vous que votre environnement est opérationnel :

- Multipass installé et fonctionnel
- Ansible >= 2.14 disponible sur le nœud de contrôle
- Docker installé (requis par k3d)
- k3d installé
- kubectl installé

L'installation complète est décrite dans :
**[`../../ressources/setup-lab.md`](../../ressources/setup-lab.md)**

## Commandes clés résumées

### Ansible

```bash
# Installer les collections
ansible-galaxy collection install -r ansible/requirements.yml

# Tester la connectivité
ansible web -m ping

# Lancer un playbook
ansible-playbook ansible/playbooks/provision.yml
ansible-playbook ansible/playbooks/deploy-app.yml
ansible-playbook ansible/playbooks/k8s-deploy.yml --ask-vault-pass
```

### Application

```bash
# Build local
npm ci && npm run build       # génère dist/

# Build Docker
docker build -t taskflow:1.0.0 .
```

### Kubernetes (k3d)

```bash
# Créer le cluster
k3d cluster create taskflow --port "8080:80@loadbalancer"

# Importer l'image locale
k3d image import taskflow:1.0.0 -c taskflow

# Appliquer les manifests
kubectl apply -f k8s/

# Vérifier l'état
kubectl get pods -n taskflow
kubectl get all -n taskflow
```
