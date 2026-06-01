# Formation DevOps - Ansible & Kubernetes

> Formation de 5 jours (35h) sur l'automatisation et l'orchestration d'infrastructures avec Ansible et Kubernetes

**Public**: M2 ESTD - Expert en stratégie et transformation digitale - Architecte Web
**Durée**: 35 heures (5 jours x 7h)
**Institution**: ForEach Academy (certification IEF2I)
**Formateur**: Fabrice Claeys
**Référent IEF2I**: Michael MAVRODIS
**Prérequis**: DevOps - Initialisation de l'intégration du système CI, Virtualisation et Containerisation avec Docker
**Dates**: 3, 4, 5 juin et 1, 2 juillet 2026

---

## Objectifs du cours

Ce cours vise à fournir aux étudiants les compétences nécessaires pour automatiser et orchestrer des infrastructures à l'aide d'Ansible et Kubernetes.

**À l'issue de la formation, les participants seront capables de :**

- Comprendre les principes et les avantages de l'automatisation et de l'orchestration des infrastructures
- Utiliser Ansible pour automatiser le déploiement et la configuration d'applications
- Gérer des clusters Kubernetes avec Ansible
- Maîtriser les concepts essentiels de Kubernetes pour le déploiement d'applications
- Appliquer les meilleures pratiques pour l'automatisation et l'orchestration des infrastructures

**Compétences visées** : C33, C34, C35

---

## Organisation

**Structure de chaque journée :**
- **Matin (9h-12h15)** : Théorie et démonstrations
- **Après-midi (13h15-17h)** : Travaux pratiques

**1 module = 1 journée**

### Projet fil rouge : TaskFlow

Les étudiants travaillent sur le **même projet** pendant les 5 jours, en l'enrichissant progressivement. On part d'une application TaskFlow figée (fournie) et on construit toute la chaîne d'automatisation et d'orchestration autour :

| Jour | Enrichissement du projet |
|------|--------------------------|
| J1 | Provisionner 2 VMs + configuration de base via un playbook idempotent |
| J2 | Déployer TaskFlow avec un **rôle** Ansible (templates Jinja2, handlers) |
| J3 | Containeriser + déployer sur un cluster **k3d** via manifests `kubectl` |
| J4 | Automatiser le déploiement Kubernetes avec Ansible (`kubernetes.core`) |
| J5 | Secrets (Vault + Kubernetes Secrets), probes/limits, déploiement complet |

**Stack** : Ansible + Multipass + Docker + k3d (Kubernetes) + kubernetes.core

**Évaluation** : État final du repository TaskFlow (100 points)

---

## Programme de formation détaillé

### Module 1 : Introduction à Ansible

**Jour 1 (7h) — 3 juin**

| Horaire | Contenu |
|---------|---------|
| **MATIN - Théorie** | |
| 9h00-9h30 | Accueil et introduction à l'automatisation |
| 9h30-11h00 | **Présentation d'Ansible** : architecture agentless, SSH, control node vs managed nodes, cas d'usage |
| 11h15-12h15 | **Installation et configuration** : inventaire, `ansible.cfg`, commandes ad-hoc, modules de base, **idempotence** |
| **APRÈS-MIDI - Pratique** | |
| 13h15-15h00 | **Playbooks** : structure YAML, tasks, premier playbook, `ansible-playbook` |
| 15h15-17h00 | **TP1 : Provisioning de l'infrastructure** |

**Slides**: [Jour 1](./slides/jour1-introduction-ansible.md) | **TP1**: [Provisioning](./tp/fil-rouge-taskflow/jour1-provisioning.md)

---

### Module 2 : Automatisation du déploiement avec Ansible

**Jour 2 (7h) — 4 juin**

| Horaire | Contenu |
|---------|---------|
| **MATIN - Théorie** | |
| 9h00-10h30 | **Inventaires et variables** : inventaires statiques/dynamiques, groupes, `group_vars`/`host_vars`, facts |
| 10h45-12h15 | **Templates et rôles** : Jinja2, handlers, structure d'un rôle, `ansible-galaxy init`, intro Ansible Vault |
| **APRÈS-MIDI - Pratique** | |
| 13h15-15h00 | **Stratégies de déploiement** : modules de déploiement, ordre d'exécution, serial, tags |
| 15h15-17h00 | **TP2 : Déploiement de TaskFlow via un rôle** |

**Slides**: [Jour 2](./slides/jour2-deploiement-ansible.md) | **TP2**: [Déploiement par rôle](./tp/fil-rouge-taskflow/jour2-deploiement-role.md)

---

### Module 3 : Introduction à Kubernetes

**Jour 3 (7h) — 5 juin**

| Horaire | Contenu |
|---------|---------|
| **MATIN - Théorie** | |
| 9h00-10h30 | **Concepts clés** : pourquoi l'orchestration, architecture (control plane, nodes, etcd, kubelet, scheduler) |
| 10h45-12h15 | **Objets Kubernetes** : Pod, ReplicaSet, Deployment, Service, ConfigMap, Namespace, Ingress |
| **APRÈS-MIDI - Pratique** | |
| 13h15-15h00 | **kubectl et cluster local** : installation k3d, `kubectl`, manifests YAML, déploiement manuel |
| 15h15-17h00 | **TP3 : Déploiement de TaskFlow sur Kubernetes** |

**Slides**: [Jour 3](./slides/jour3-introduction-kubernetes.md) | **TP3**: [Manifests Kubernetes](./tp/fil-rouge-taskflow/jour3-kubernetes-manifests.md)

---

### Module 4 : Gestion des clusters Kubernetes avec Ansible

**Jour 4 (7h) — 1 juillet**

| Horaire | Contenu |
|---------|---------|
| **MATIN - Théorie** | |
| 9h00-10h30 | **Ansible + Kubernetes** : collection `kubernetes.core`, module `k8s`, kubeconfig, prérequis Python |
| 10h45-12h15 | **Gestion des ressources** : appliquer des manifests, templating Jinja2 de manifests, `k8s_info`, idempotence |
| **APRÈS-MIDI - Pratique** | |
| 13h15-15h00 | **Déploiement d'applications** : variabilisation, boucles, Helm via Ansible (option) |
| 15h15-17h00 | **TP4 : Automatiser le déploiement Kubernetes** |

**Slides**: [Jour 4](./slides/jour4-kubernetes-avec-ansible.md) | **TP4**: [Automatisation K8s](./tp/fil-rouge-taskflow/jour4-automatisation-k8s-ansible.md)

---

### Module 5 : Bonnes pratiques et cas d'utilisation avancés

**Jour 5 (7h) — 2 juillet**

| Horaire | Contenu |
|---------|---------|
| **MATIN - Théorie** | |
| 9h00-10h30 | **Sécurité et secrets** : Ansible Vault, Kubernetes Secrets, bonnes pratiques de gestion |
| 10h45-12h15 | **Bonnes pratiques** : structure de projet, `ansible-lint`, tags, check mode, probes & resource limits, intégration CI/CD |
| **APRÈS-MIDI - Pratique** | |
| 13h15-15h30 | **TP5 : Déploiement complet et sécurisé** |
| 15h45-16h30 | **Étude de cas avancée** : pipeline complet Ansible + Kubernetes |
| 16h30-17h00 | **QCM Final** |

**Slides**: [Jour 5](./slides/jour5-securite-bonnes-pratiques.md) | **TP5**: [Finalisation](./tp/fil-rouge-taskflow/jour5-secrets-finalisation.md) | **Évaluation**: [QCM](./evaluation/)

---

## Pourquoi ces outils ?

| Outil | Rôle dans le cours | Pourquoi ce choix |
|-------|--------------------|--------------------|
| **Ansible** | Automatisation de configuration et déploiement | Agentless (SSH), YAML lisible, idempotent, standard du marché |
| **Multipass** | VMs cibles gérées par Ansible | Léger, multiplateforme (Windows/macOS/Linux), simule de vrais serveurs |
| **k3d** | Cluster Kubernetes local | k3s dans Docker, démarrage en secondes, s'appuie sur Docker déjà acquis |
| **kubernetes.core** | Piloter Kubernetes depuis Ansible | Collection officielle, idempotente, unifie config et orchestration |

> Ansible ne s'exécute pas nativement sous Windows : les étudiants Windows utilisent **WSL2 (Ubuntu)** comme nœud de contrôle. Voir [setup-lab.md](./ressources/setup-lab.md).

---

## Évaluation

| Type | Coefficient |
|------|-------------|
| TP (projet fil rouge) | 100% |
| QCM | 100% |

**Validation de la compétence** : Note >= 10/20

Détails : [Grille d'évaluation](./evaluation/grille-evaluation.md) · [QCM](./evaluation/qcm.md)

---

## Ressources

### Documentation officielle
- [Ansible Documentation](https://docs.ansible.com/ansible/latest/)
- [Collection kubernetes.core](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [k3d Documentation](https://k3d.io/)

### Outils recommandés
- **VSCode** + extensions Ansible, YAML, Kubernetes
- **Multipass** - VMs légères pour les cibles Ansible
- **k3d** + **kubectl** - Cluster Kubernetes local
- **ansible-lint** - Vérification des bonnes pratiques

### Aide-mémoire
- [Cheatsheet Ansible](./ressources/cheatsheet-ansible.md)
- [Cheatsheet Kubernetes](./ressources/cheatsheet-kubernetes.md)
- [Guide d'installation du lab](./ressources/setup-lab.md)

### Bibliographie
- *Ansible — Gérez la configuration de vos serveurs et le déploiement de vos applications*, Yannig PERRÉ, éditions ENI
- *Kubernetes — Gérez la plateforme de déploiement de vos applications conteneurisées*, Yannig PERRÉ, éditions ENI

---

## Contact

**Formateur ForEach** : Fabrice Claeys
**Référent IEF2I** : Michael MAVRODIS (michaelmavrodis@formateur.ief2i.fr)

---

**2026 - Formation Ansible & Kubernetes - ForEach Academy**
