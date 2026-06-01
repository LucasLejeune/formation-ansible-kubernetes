# Démo 1 — Commandes ad-hoc & Idempotence Ansible

## Objectif pédagogique

Découvrir les commandes ad-hoc Ansible et comprendre le concept fondamental d'**idempotence** : la propriété qui garantit qu'un playbook peut être rejoué sans effets indésirables.

## Prérequis

| Outil | Version minimale | Vérification |
|-------|-----------------|--------------|
| Python | 3.8+ | `python3 --version` |
| Ansible | 2.14+ | `ansible --version` |

```bash
# Installation rapide si nécessaire
pip install ansible
```

## Structure de la démo

```
demo-ansible-adhoc/
├── README.md          # Ce fichier
├── inventory.ini      # Inventaire : localhost en connexion locale
├── playbook.yml       # 3 tâches idempotentes
└── demo.sh            # Script de démonstration commenté
```

## Inventaire

```ini
[all]
localhost ansible_connection=local
```

L'option `ansible_connection=local` évite SSH et exécute directement sur la machine. Idéal pour les démos sans VMs.

## Lancement

```bash
chmod +x demo.sh
./demo.sh
```

Ou étape par étape :

```bash
# Test de connectivité
ansible all -i inventory.ini -m ping

# Collecte de facts (informations système)
ansible all -i inventory.ini -m setup -a 'filter=ansible_distribution*'

# Commande ad-hoc (non idempotente)
ansible all -i inventory.ini -m ansible.builtin.command -a 'date'

# Playbook - 1ère exécution (changed)
ansible-playbook -i inventory.ini playbook.yml

# Playbook - 2ème exécution (ok = idempotence)
ansible-playbook -i inventory.ini playbook.yml
```

## Déroulé pas-à-pas

### Étape 1 : Version d'Ansible
```bash
ansible --version
```
Montre la version d'Ansible, la version Python associée et l'emplacement du fichier de configuration.

### Étape 2 : Module ping
```bash
ansible all -i inventory.ini -m ping
```
**Point pédagogique** : Le ping Ansible n'est PAS un ping réseau ICMP. Il teste :
1. La connexion vers l'hôte (SSH ou locale)
2. La disponibilité de l'interpréteur Python
3. Le bon fonctionnement du module Ansible côté cible

### Étape 3 : Module setup (facts)
```bash
ansible all -i inventory.ini -m setup -a 'filter=ansible_distribution*'
```
Les **facts** sont des variables système collectées automatiquement. Elles sont disponibles dans les playbooks via `{{ ansible_distribution }}`, `{{ ansible_kernel }}`, etc.

### Étape 4 : Module command
```bash
ansible all -i inventory.ini -m ansible.builtin.command -a 'date'
```
**Point pédagogique** : Le module `command` n'est PAS idempotent. Il exécute la commande à chaque fois, sans vérifier l'état préalable. À utiliser avec parcimonie.

### Étape 5 : Playbook — 1ère exécution
```bash
ansible-playbook -i inventory.ini playbook.yml
```
Résultat attendu dans le PLAY RECAP :
- `changed=1` (le fichier `/tmp/ansible-demo-marker.txt` est créé)
- `ok=2` (stat + debug, toujours ok)

### Étape 6 : Playbook — 2ème exécution
```bash
ansible-playbook -i inventory.ini playbook.yml
```
Résultat attendu dans le PLAY RECAP :
- `changed=0` (le fichier existe déjà avec le même contenu)
- `ok=3` (toutes les tâches sont déjà dans l'état cible)

## Points pédagogiques à souligner

### Idempotence

> **Définition** : Une opération est idempotente si la réaliser une ou plusieurs fois produit le même résultat.

En Ansible, un module idempotent :
1. **Vérifie** l'état actuel de la ressource
2. **Compare** avec l'état désiré (tel que défini dans le playbook)
3. **Agit** uniquement si les deux états diffèrent

**Conséquence pratique** : on peut rejouer un playbook après un échec partiel, une coupure réseau, ou simplement pour vérifier l'état de l'infrastructure — sans risque de casser ce qui fonctionne.

### Modules idempotents vs non-idempotents

| Module | Idempotent ? | Raison |
|--------|-------------|--------|
| `copy` | Oui | Vérifie le hash du fichier |
| `file` | Oui | Vérifie permissions/existence |
| `package` | Oui | Vérifie si le paquet est installé |
| `command` | Non | Exécute aveuglément |
| `shell` | Non | Exécute aveuglément |
| `raw` | Non | Exécute aveuglément |

### PLAY RECAP : lire les couleurs
- **Vert (ok)** : aucune action nécessaire, état cible déjà atteint
- **Jaune (changed)** : action effectuée, état modifié
- **Rouge (failed)** : erreur, la tâche a échoué
- **Bleu (skipped)** : tâche ignorée (condition `when` non remplie)

## Résultat attendu

Après la 2ème exécution du playbook :

```
PLAY RECAP ****
localhost : ok=3 changed=0 unreachable=0 failed=0 skipped=0
```

Et le fichier créé :
```
/tmp/ansible-demo-marker.txt
```

## Nettoyage

```bash
rm -f /tmp/ansible-demo-marker.txt
```
