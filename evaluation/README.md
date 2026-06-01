# Évaluation — Formation M2 DevOps : Ansible & Kubernetes

**Formation** : DevOps - Ansible & Kubernetes (35h / 5 jours)
**Organisme** : ForEach Academy
**Formateur** : Fabrice Claeys
**Référent pédagogique** : Michael MAVRODIS

---

## Modalités d'évaluation

| Modalité | Pondération | Seuil de validation |
|---|---|---|
| TP fil rouge — état final du repo TaskFlow | 100 % | ≥ 10 / 20 |
| QCM théorique (30 questions, 45 min) | 100 % | ≥ 10 / 20 |

Les deux modalités sont **indépendantes** : chacune est validée à partir de 10/20.
Il n'y a pas de compensation entre les deux notes.

---

## TP fil rouge — TaskFlow (100 points)

### Principe

Tout au long de la formation, les stagiaires construisent incrémentalement
l'infrastructure de déploiement de l'application **TaskFlow** (application web
statique de gestion de tâches). L'évaluation porte sur **l'état final du
dépôt Git** rendu en fin de formation.

### Ce qui est évalué

Le travail est organisé en cinq blocs de 20 points chacun, couvrant l'ensemble
du parcours pédagogique :

| # | Bloc | Points |
|---|---|---|
| 1 | Provisioning Ansible (inventaire, ansible.cfg, playbook, idempotence) | 20 |
| 2 | Déploiement par rôle (structure rôle, template Jinja2, handler, accès HTTP) | 20 |
| 3 | Kubernetes et manifests (image, cluster k3d, manifests, pods Running) | 20 |
| 4 | Automatisation K8s avec Ansible (collection kubernetes.core, playbook k8s-deploy.yml, idempotence) | 20 |
| 5 | Sécurité et bonnes pratiques (Vault, Secrets K8s, probes, ressources, ansible-lint) | 20 |
| | **Total** | **100** |

### Rendu attendu

Le stagiaire soumet l'URL de son dépôt Git (ou une archive) contenant :

```
ansible/
  ansible.cfg
  inventory/
    hosts.ini
    group_vars/
  playbooks/
    provision.yml
    deploy-app.yml
    k8s-deploy.yml
    vars/
    templates/
  roles/
    taskflow/
  requirements.yml
k8s/
  namespace.yaml
  configmap.yaml
  deployment.yaml
  service.yaml
  ingress.yaml
  secret.yaml
```

La grille de correction détaillée est disponible dans
[grille-evaluation.md](grille-evaluation.md).

---

## QCM théorique

| Paramètre | Valeur |
|---|---|
| Nombre de questions | 30 |
| Durée | 45 minutes |
| Format | 1 bonne réponse parmi 4 propositions (A/B/C/D) |
| Correction | 1 point par bonne réponse |
| Seuil de validation | ≥ 15 points (= 10/20) |

### Sections

| Section | Thème | Questions |
|---|---|---|
| 1 | Fondamentaux Ansible | 1 – 6 |
| 2 | Playbooks, rôles, variables | 7 – 12 |
| 3 | Fondamentaux Kubernetes | 13 – 18 |
| 4 | Objets et manifests K8s | 19 – 24 |
| 5 | Ansible + K8s, sécurité, bonnes pratiques | 25 – 30 |

Le QCM est disponible dans [qcm.md](qcm.md).
Le corrigé formateur (usage interne uniquement) est dans `qcm-corrige.md`.
