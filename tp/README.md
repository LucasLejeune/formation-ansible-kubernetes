# TP Fil rouge — Formation DevOps : Ansible & Kubernetes

## Concept du fil rouge

Cette série de travaux pratiques repose sur un **projet unique et progressif** : l'application **TaskFlow**. Plutôt que cinq TP indépendants, vous enrichissez le même projet tout au long de la semaine — chaque journée capitalise sur le travail de la veille.

À la fin de la semaine, vous disposez d'une infrastructure complète, automatisée et documentée, couvrant le provisioning, le déploiement applicatif, les manifests Kubernetes, l'automatisation K8s par Ansible, et la gestion des secrets.

## Le projet : TaskFlow

**TaskFlow** est une application web de gestion de tâches développée en Vanilla JS + Vite. Elle est intentionnellement simple pour que vous puissiez vous concentrer sur l'infrastructure et l'automatisation.

- Interface statique servie par nginx
- Build via `npm run build` → dossier `dist/`
- Image Docker : `taskflow:1.0.0` (base `nginx:alpine`, port 80)
- Réutilise les notions Docker vues lors du cours précédent

## Stack technique

| Couche | Technologie |
|---|---|
| Application | Vanilla JS + Vite |
| Serveur web (VMs) | nginx |
| Provisioning / déploiement | Ansible >= 2.14 |
| Collections Ansible | community.general, ansible.posix, kubernetes.core |
| VMs cibles | Multipass (`taskflow-web1`, `taskflow-web2`) |
| Conteneurisation | Docker |
| Cluster Kubernetes | k3d (k3s dans Docker) |
| Secrets | Ansible Vault |

## Tableau de progression J1 → J5

| Jour | Module | Objectif du TP | Livrable |
|---|---|---|---|
| J1 | Ansible — Bases & Inventaire | Provisionner 2 VMs Multipass avec un playbook idempotent | `ansible/inventory/hosts.ini`, `playbooks/provision.yml` |
| J2 | Ansible — Rôles & Déploiement | Déployer TaskFlow sur les VMs via un rôle structuré | `roles/taskflow/`, `playbooks/deploy-app.yml` |
| J3 | Kubernetes — Manifests | Déployer TaskFlow sur k3d avec des manifests YAML | `k8s/*.yaml` (6 fichiers) |
| J4 | Ansible + Kubernetes | Piloter Kubernetes depuis Ansible (kubernetes.core) | `playbooks/k8s-deploy.yml`, template Jinja2 |
| J5 | Secrets & Finalisation | Chiffrer les secrets, ajouter les probes, passer ansible-lint | Vault, probes, projet finalisé |

## Point de départ

Le code de démarrage est fourni dans le dossier `fil-rouge-taskflow/starter/`. Il contient l'application TaskFlow et des squelettes avec des `TODO` à compléter.

```bash
# Depuis la racine du dépôt, copiez le starter dans votre répertoire de travail
cp -r tp/fil-rouge-taskflow/starter ~/taskflow-lab
cd ~/taskflow-lab
```

Consultez [`fil-rouge-taskflow/README.md`](./fil-rouge-taskflow/README.md) pour la description détaillée de l'arborescence.

## Prérequis du lab

L'environnement lab (installation de Multipass, k3d, Ansible, clé SSH...) est décrit dans :

- [`../ressources/setup-lab.md`](../ressources/setup-lab.md)

Lisez ce fichier **avant** le Jour 1.

## Évaluation finale

L'évaluation porte sur 100 points et couvre l'ensemble du projet fil rouge. La grille détaillée est disponible dans :

- [`../evaluation/grille-evaluation.md`](../evaluation/grille-evaluation.md)

## Ressources

| Ressource | Lien |
|---|---|
| Guide d'installation du lab | [`../ressources/setup-lab.md`](../ressources/setup-lab.md) |
| Documentation Ansible officielle | https://docs.ansible.com |
| Documentation Kubernetes officielle | https://kubernetes.io/docs |
| Collection community.general | https://docs.ansible.com/ansible/latest/collections/community/general/ |
| Collection kubernetes.core | https://docs.ansible.com/ansible/latest/collections/kubernetes/core/ |
| Documentation k3d | https://k3d.io |

## Capitalisation sur le cours Docker

Ce fil rouge réutilise directement les acquis du cours Docker précédent :

- Le `Dockerfile` multi-stage est **déjà écrit** dans le starter (vous l'avez vu en cours)
- La commande `docker build` est rappelée au Jour 3
- k3d fait tourner k3s **dans Docker** — Docker doit donc être installé et actif

---

**Premier TP** : [Jour 1 — Provisioning](./fil-rouge-taskflow/jour1-provisioning.md)
