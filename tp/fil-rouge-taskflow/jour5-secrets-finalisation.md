# TP Jour 5 : Secrets, bonnes pratiques et finalisation

> **Durée** : ~2h | **Objectif** : Chiffrer `secrets.yml` avec Ansible Vault, intégrer le Secret Kubernetes dans le playbook, vérifier les probes liveness/readiness dans le Deployment, passer `ansible-lint` sans erreur bloquante, et effectuer un déploiement complet et propre en guise de bilan de la semaine.

---

## Prérequis

- TP Jour 4 terminé : `playbooks/k8s-deploy.yml` fonctionne et retourne `changed=0`
- Le cluster k3d `taskflow` est actif (`k3d cluster list`)
- `ansible-lint` installé sur le nœud de contrôle

```bash
# Installer ansible-lint si nécessaire
pip install ansible-lint

# Vérifier
ansible-lint --version
```

---

## Étape 1 : Comprendre les enjeux de la gestion des secrets (10 min)

### 1.1 Pourquoi les secrets ne doivent jamais être en clair dans Git

Le fichier `ansible/playbooks/vars/secrets.yml` contient actuellement une valeur de token en clair :

```yaml
vault_taskflow_api_token: "s3cr3t-token-de-demonstration"
```

Committer ce fichier tel quel dans Git est une **faille de sécurité critique**. Même si le dépôt est privé, un historique Git contient potentiellement des secrets pour toujours.

**Ansible Vault** chiffre les fichiers de variables sensibles avec AES-256. Le fichier chiffré peut être commité en toute sécurité : il est illisible sans le mot de passe du vault.

### 1.2 Rappel : le Secret Kubernetes n'est pas un chiffrement

Un `Secret` Kubernetes stocke les données encodées en base64, **pas chiffrées**. Quiconque a accès à l'API server peut décoder un Secret. L'encodage base64 est une représentation, pas une protection. La vraie protection repose sur :
- Le contrôle d'accès (RBAC) au niveau Kubernetes
- Le chiffrement at-rest des etcd (configuration avancée)
- Ansible Vault pour la gestion des valeurs en amont

---

## Étape 2 : Chiffrer `secrets.yml` avec Ansible Vault (20 min)

### 2.1 Choisir un mot de passe vault

Pour ce lab, utilisez un mot de passe simple et mémorisable, par exemple : `taskflow-lab-2024`.

### 2.2 Chiffrer le fichier

Depuis le dossier `ansible/` :

```bash
ansible-vault encrypt playbooks/vars/secrets.yml
```

Ansible vous demande de saisir et confirmer le mot de passe :

```
New Vault password:
Confirm New Vault password:
Encryption successful
```

### 2.3 Vérifier le résultat

```bash
cat playbooks/vars/secrets.yml
```

**Résultat attendu :** le fichier est maintenant chiffré et commence par `$ANSIBLE_VAULT;` :

```
$ANSIBLE_VAULT;1.1;AES256
61363964356138623562356361626263326339363561303639346334323833373732303034343033
3262306334636332366639623839653337666566323161370a383261363236393663346163656662
...
```

### 2.4 Vérifier que le contenu reste lisible avec le mot de passe

```bash
ansible-vault view playbooks/vars/secrets.yml
```

Saisissez le mot de passe. Le contenu en clair s'affiche.

### 2.5 Modifier une valeur chiffrée (démonstration)

```bash
ansible-vault edit playbooks/vars/secrets.yml
```

Cela ouvre l'éditeur configuré (vim par défaut) avec le contenu déchiffré. Vous pouvez modifier la valeur et sauvegarder ; Ansible rechiffre automatiquement.

---

## Étape 3 : Vérifier les probes et les resource limits dans le template (20 min)

### 3.1 Rappel : pourquoi les probes sont indispensables

Sans `livenessProbe`, Kubernetes ne détecte pas un pod en état bloqué et ne le redémarre jamais. Sans `readinessProbe`, Kubernetes envoie du trafic à un pod qui n'est pas encore prêt à servir des requêtes (par exemple, pendant le démarrage).

### 3.2 Vérifier le template `ansible/playbooks/templates/k8s/deployment.yaml.j2`

Le template créé au Jour 4 contient déjà les probes et les resources. Vérifiez que cette section est bien présente dans votre fichier :

```jinja2
          resources:
            requests:
              cpu: {{ taskflow_resources.requests.cpu }}
              memory: {{ taskflow_resources.requests.memory }}
            limits:
              cpu: {{ taskflow_resources.limits.cpu }}
              memory: {{ taskflow_resources.limits.memory }}
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 3
            periodSeconds: 5
```

Les valeurs des resources sont définies dans `playbooks/vars/k8s.yml` :

```yaml
taskflow_resources:
  requests:
    cpu: 50m
    memory: 32Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

> `requests` définit les ressources garanties (Kubernetes les alloue au scheduling). `limits` définit le plafond : le container est tué s'il dépasse la mémoire limite, ou throttlé pour le CPU.

---

## Étape 4 : Passer `ansible-lint` (20 min)

### 4.1 Lancer ansible-lint sur le projet

Depuis le dossier `ansible/` :

```bash
ansible-lint playbooks/provision.yml playbooks/deploy-app.yml playbooks/k8s-deploy.yml
```

### 4.2 Corriger les erreurs bloquantes

ansible-lint classe les règles par sévérité. Les règles de sévérité `error` (bloquantes) doivent toutes être corrigées. Les règles `warning` sont des recommandations.

Erreurs courantes et corrections :

| Règle ansible-lint | Cause | Correction |
|---|---|---|
| `yaml[truthy]` | Usage de `yes`/`no` à la place de `true`/`false` | Remplacer par `true`/`false` |
| `fqcn[action-core]` | Module sans nom complet qualifié (ex: `apt` au lieu de `ansible.builtin.apt`) | Préfixer le module avec son FQCN |
| `no-changed-when` | Tâche `command`/`shell` sans `changed_when` | Ajouter `changed_when: false` ou une condition appropriée |
| `risky-file-permissions` | Tâche `file` ou `copy` sans `mode` | Ajouter `mode: "0644"` ou la valeur appropriée |

### 4.3 Exemple de correction `no-changed-when`

Si ansible-lint signale une tâche `command` sans `changed_when`, ajoutez la directive. Exemple dans `deploy-app.yml` :

```yaml
- name: Builder l'application (vite build -> dist/)
  ansible.builtin.command:
    cmd: npm run build
    chdir: "{{ playbook_dir }}/.."
    creates: "{{ playbook_dir }}/../dist/index.html"
  changed_when: false
```

### 4.4 Valider l'absence d'erreurs bloquantes

```bash
ansible-lint playbooks/provision.yml playbooks/deploy-app.yml playbooks/k8s-deploy.yml
echo "Exit code: $?"
```

**Résultat attendu :** exit code 0 (ou seulement des warnings, pas d'errors).

---

## Étape 5 : Déploiement complet et final (25 min)

Cette étape est le bilan de la semaine : vous effectuez un déploiement complet propre, du provisioning jusqu'au déploiement Kubernetes sécurisé.

### 5.1 Recréer le cluster (optionnel, pour partir d'un état propre)

```bash
k3d cluster delete taskflow
k3d cluster create taskflow --port "8080:80@loadbalancer"
k3d image import taskflow:1.0.0 -c taskflow
```

### 5.2 Provisionner les VMs

```bash
ansible-playbook playbooks/provision.yml
```

**Résultat attendu :** `changed=0` (les VMs sont déjà provisionnées depuis J1).

### 5.3 Déployer l'application sur les VMs

```bash
ansible-playbook playbooks/deploy-app.yml
```

### 5.4 Déploiement Kubernetes complet avec Vault

```bash
ansible-playbook playbooks/k8s-deploy.yml --ask-vault-pass
```

Saisissez le mot de passe vault configuré à l'étape 2.

**Résultat attendu :**

```
PLAY [Déployer TaskFlow sur Kubernetes] ****************************************

TASK [Créer le namespace] ******************************************************
ok: [localhost]

TASK [Appliquer la ConfigMap] **************************************************
ok: [localhost]

TASK [Appliquer le Secret (valeurs issues du Vault)] ***************************
ok: [localhost]

TASK [Appliquer le Deployment (template Jinja2)] *******************************
ok: [localhost]

TASK [Appliquer le Service] ****************************************************
ok: [localhost]

TASK [Appliquer l'Ingress] *****************************************************
ok: [localhost]

TASK [Attendre que le déploiement soit disponible] *****************************
ok: [localhost]

PLAY RECAP *********************************************************************
localhost                  : ok=7    changed=0    unreachable=0    failed=0
```

### 5.5 Vérifier les probes dans les pods déployés

```bash
kubectl describe pod -n taskflow -l app=taskflow | grep -A 10 "Liveness\|Readiness"
```

**Résultat attendu :**

```
    Liveness:       http-get http://:80/ delay=5s timeout=1s period=10s #success=1 #failure=3
    Readiness:      http-get http://:80/ delay=3s timeout=1s period=5s #success=1 #failure=3
```

### 5.6 Vérification finale complète

```bash
# État des pods
kubectl get pods -n taskflow

# Accès à l'application
curl http://taskflow.localhost:8080

# Vérifier le Secret (encodé base64, jamais en clair dans les logs)
kubectl get secret taskflow-secret -n taskflow -o yaml
```

---

## Checklist de validation

- [ ] `cat ansible/playbooks/vars/secrets.yml` commence par `$ANSIBLE_VAULT;1.1;AES256`
- [ ] `ansible-vault view ansible/playbooks/vars/secrets.yml` affiche le contenu en clair après saisie du mot de passe
- [ ] Le template `deployment.yaml.j2` contient les sections `livenessProbe`, `readinessProbe` et `resources`
- [ ] `ansible-lint` ne retourne aucune erreur bloquante (exit code 0)
- [ ] `ansible-playbook playbooks/k8s-deploy.yml --ask-vault-pass` se termine avec `failed=0`
- [ ] `kubectl describe pod -n taskflow` montre les probes liveness et readiness configurées
- [ ] `curl http://taskflow.localhost:8080` retourne du HTML contenant TaskFlow
- [ ] Le Secret Kubernetes `taskflow-secret` est présent dans le namespace `taskflow`
- [ ] Le projet complet est dans un état `changed=0` après un second déploiement complet

---

## Erreurs courantes

**`ERROR! Decryption failed (no vault secrets would decrypt)`**
Le mot de passe saisi est incorrect, ou vous avez oublié `--ask-vault-pass`. Vérifiez le mot de passe avec `ansible-vault view playbooks/vars/secrets.yml`.

**`ansible-lint` échoue avec `yaml[truthy]` sur les fichiers de la collection**
ansible-lint analyse aussi les fichiers des collections installées. Limitez l'analyse à vos fichiers : `ansible-lint playbooks/ roles/`.

**Les pods redémarrent en boucle (`CrashLoopBackOff`)**
Inspectez les logs : `kubectl logs -n taskflow -l app=taskflow`. Si la probe liveness échoue trop tôt, augmentez `initialDelaySeconds`.

**`FAILED! => Unable to retrieve file contents`**
Le chemin du template dans la tâche `kubernetes.core.k8s` doit être relatif au répertoire du playbook. Vérifiez que `templates/k8s/deployment.yaml.j2` est bien dans `ansible/playbooks/templates/k8s/`.

---

## Récapitulatif de la semaine

Vous avez construit, au fil de la semaine, une infrastructure complète et automatisée pour l'application TaskFlow :

| Jour | Ce que vous avez appris | Ce que vous avez livré |
|---|---|---|
| J1 | Inventaire Ansible, ansible.cfg, modules apt/ufw/user | playbooks/provision.yml (idempotent) |
| J2 | Rôles Ansible, handlers, synchronize, templates Jinja2 | roles/taskflow/, playbooks/deploy-app.yml |
| J3 | Manifests K8s, Deployment/Service/Ingress, k3d | k8s/*.yaml (6 fichiers) |
| J4 | kubernetes.core, template K8s depuis Ansible, scaling déclaratif | playbooks/k8s-deploy.yml, deployment.yaml.j2 |
| J5 | Ansible Vault, probes, resource limits, ansible-lint | secrets.yml chiffré, projet finalisé |

---

## Ressources

- [Documentation Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html)
- [Documentation ansible-lint](https://ansible-lint.readthedocs.io/)
- [Kubernetes — Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Kubernetes — Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Kubernetes — Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)

---

**Prochain TP** : [Évaluation finale](../../evaluation/grille-evaluation.md) — Bonne chance !
