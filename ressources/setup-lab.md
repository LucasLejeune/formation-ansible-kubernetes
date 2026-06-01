# Guide d'installation du lab — Ansible & Kubernetes (M2 DevOps)

> ForEach Academy — Formateur : Fabrice Claeys

---

## 1. Vue d'ensemble de l'architecture du lab

```
┌─────────────────────────────────────────────────────────────────┐
│                      POSTE ÉTUDIANT                              │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Windows (ou macOS/Linux natif)                           │   │
│  │                                                           │   │
│  │  ┌─────────────────────┐   ┌──────────────────────────┐  │   │
│  │  │  Docker Desktop      │   │  Multipass (Hyper-V)     │  │   │
│  │  │  ┌───────────────┐  │   │  ┌────────────────────┐  │  │   │
│  │  │  │  k3d cluster  │  │   │  │  taskflow-web1 VM  │  │  │   │
│  │  │  │  (k3s/Docker) │  │   │  │  ubuntu 22.04      │  │  │   │
│  │  │  └───────────────┘  │   │  ├────────────────────┤  │  │   │
│  │  └─────────────────────┘   │  │  taskflow-web2 VM  │  │  │   │
│  │                             │  │  ubuntu 22.04      │  │  │   │
│  │  ┌─────────────────────┐   │  └────────────────────┘  │  │   │
│  │  │  WSL2 (Ubuntu)       │   └──────────────────────────┘  │   │
│  │  │  nœud de contrôle    │                                  │   │
│  │  │  - ansible           │   Réseau Multipass               │   │
│  │  │  - kubectl           │   (172.x.x.x)   ←───────────────┤   │
│  │  │  - k3d               │                                  │   │
│  │  │  - git               │                                  │   │
│  │  └─────────────────────┘                                   │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Rôles dans le lab :**

| Composant | Rôle | Où tourne-t-il |
|---|---|---|
| WSL2 Ubuntu | Nœud de contrôle Ansible | Côté Windows, dans WSL2 |
| Multipass VMs | Cibles Ansible (groupe `[web]`) | Côté Windows, VM Hyper-V |
| Docker Desktop | Moteur Docker pour k3d | Côté Windows |
| k3d / kubectl | Cluster Kubernetes local | Dans WSL2 (k3d gère Docker Desktop) |
| Ansible | Orchestre les 2 VMs et le cluster | Dans WSL2 |

> **Pourquoi WSL2 ?** Ansible ne peut pas s'exécuter nativement sous Windows. WSL2 fournit un vrai Linux directement sur Windows, sans VM lourde.

---

## 2. Installation — Windows (parcours principal)

### 2.1 Activer WSL2 et installer Ubuntu

Ouvrir **PowerShell en tant qu'administrateur** :

```powershell
# Installe WSL2 + Ubuntu par défaut (redémarrage requis)
wsl --install

# Après redémarrage, vérifier la version
wsl --version

# Lister les distributions disponibles
wsl --list --verbose
```

Au premier lancement, Ubuntu demande un nom d'utilisateur et un mot de passe : les choisir et **les noter**.

Mettre à jour le système Ubuntu (dans le terminal WSL2) :

```bash
sudo apt update && sudo apt upgrade -y
```

### 2.2 Installer Docker Desktop avec intégration WSL2

1. Télécharger Docker Desktop depuis <https://www.docker.com/products/docker-desktop/>
2. Lors de l'installation, cocher **"Use WSL 2 instead of Hyper-V"**
3. Après installation, ouvrir Docker Desktop → **Settings → Resources → WSL Integration**
4. Activer l'intégration pour la distribution **Ubuntu** (ou le nom affiché)
5. Cliquer **Apply & Restart**

Vérifier dans WSL2 :

```bash
docker version          # doit répondre sans erreur
docker run hello-world  # test rapide
```

> Docker Desktop fait tourner le daemon Docker côté Windows ; WSL2 y accède via socket partagé. k3d, lui, tourne dans WSL2 et pilote ce Docker.

### 2.3 Installer Multipass (backend Hyper-V)

> Multipass tourne côté **Windows**, pas dans WSL2.

1. Télécharger Multipass : <https://multipass.run/install>
2. Lors de l'installation, sélectionner le backend **Hyper-V** (activé automatiquement si Windows 10/11 Pro/Enterprise)
3. Vérifier dans PowerShell :

```powershell
multipass version
multipass list
```

> **Prérequis Hyper-V :** nécessite Windows 10/11 Pro, Enterprise ou Education. Sous Windows Home, utiliser le backend VirtualBox (installer VirtualBox avant Multipass, puis sélectionner VirtualBox dans l'installeur).

### 2.4 Installer Ansible dans WSL2

Dans le terminal WSL2 Ubuntu :

```bash
# Méthode recommandée : pipx (isole Ansible dans son propre venv)
sudo apt install -y pipx python3-pip
pipx install ansible
pipx ensurepath

# Recharger le PATH
source ~/.bashrc

# Vérifier
ansible --version
```

Alternative via apt (version plus ancienne mais stable) :

```bash
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
```

### 2.5 Installer kubectl dans WSL2

```bash
# Télécharger kubectl (version stable)
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Vérifier
kubectl version --client
```

### 2.6 Installer k3d dans WSL2

```bash
# Script officiel k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Vérifier
k3d version
```

**Récapitulatif Windows — ce qui tourne où :**

| Outil | Windows natif | WSL2 Ubuntu |
|---|---|---|
| Multipass | ✅ | — |
| Docker Desktop | ✅ | — (accès socket) |
| WSL2 Ubuntu | ✅ (hôte) | — |
| Ansible | — | ✅ |
| kubectl | — | ✅ |
| k3d | — | ✅ |
| git | Optionnel | ✅ |

---

## 3. Installation — macOS

```bash
# Homebrew (si absent)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Outils du lab
brew install ansible
brew install kubectl
brew install k3d
brew install --cask multipass
brew install --cask docker

# Docker Desktop : le lancer depuis Applications, puis l'activer
# Multipass : lancer depuis Applications ou via CLI
multipass version
```

Pas de WSL2 nécessaire : tout tourne nativement sur macOS.

---

## 4. Installation — Linux

```bash
# Ansible via pipx (recommandé)
sudo apt install -y pipx python3-pip
pipx install ansible
pipx ensurepath
source ~/.bashrc

# Multipass via snap
sudo snap install multipass

# Docker Engine
curl -fsSL https://get.docker.com | sudo bash
sudo usermod -aG docker $USER
newgrp docker

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

---

## 5. Création des VMs Multipass

> Sous Windows : exécuter les commandes Multipass depuis **PowerShell** (pas WSL2).
> Sous macOS/Linux : les exécuter depuis le terminal natif.

```bash
# Créer les 2 VMs cibles Ansible
multipass launch --name taskflow-web1 --cpus 1 --memory 1G --disk 5G 22.04
multipass launch --name taskflow-web2 --cpus 1 --memory 1G --disk 5G 22.04

# Vérifier et récupérer les IP
multipass list
```

Exemple de sortie :

```
Name            State       IPv4             Image
taskflow-web1   Running     172.22.135.10    Ubuntu 22.04 LTS
taskflow-web2   Running     172.22.135.11    Ubuntu 22.04 LTS
```

> **Noter les IP** : elles seront utilisées dans l'inventaire Ansible.

Depuis WSL2 (ou terminal macOS/Linux), vérifier l'accessibilité réseau :

```bash
ping 172.22.135.10   # adapter l'IP
```

---

## 5 bis. Raccourci : le wrapper `lab-up.sh` (multipass **ou** incus)

Pour éviter de retaper la création des VMs **et** l'injection de la clé SSH, le dépôt
fournit un script qui fait tout, **avec la même commande pour tout le monde** :

```bash
# Depuis la racine du projet TaskFlow (où se trouve ressources/lab/)
./ressources/lab/lab-up.sh      # crée taskflow-web1/web2 + injecte ~/.ssh/taskflow_lab + génère un inventaire
./ressources/lab/lab-down.sh    # supprime les VMs
```

Le script **auto-détecte le backend** :
- `multipass` s'il est présent (étudiants Windows/macOS/Linux) ;
- `incus` sinon (formateur sous NixOS — voir 5 ter).

On peut le forcer : `LAB_BACKEND=incus ./ressources/lab/lab-up.sh`.
Il écrit un inventaire prêt à l'emploi dans `inventory.generated.ini` (à copier dans
`ansible/inventory/hosts.ini`). La suite (Ansible, k3d) est alors **identique** quel que soit le backend.

---

## 5 ter. Formateur sous NixOS (sans Multipass) — Incus

Multipass n'est pas packagé sur NixOS (distribué via snap par Canonical). On le remplace
par **Incus** (successeur de LXD), qui lance de vraies VMs KVM à partir d'images cloud Ubuntu
avec cloud-init — exactement le modèle de Multipass. `systemd` et `UFW` fonctionnent donc
normalement dans les VMs (indispensable : le playbook J1 configure UFW, le rôle J2 gère nginx en service).

### 1. Activer Incus dans la configuration NixOS

```nix
# configuration.nix (ou un module dédié)
virtualisation.incus.enable = true;

# Donner les droits à ton utilisateur (adapter le nom)
users.users.fabrice.extraGroups = [ "incus-admin" ];

# Recommandé pour le réseau des instances
networking.nftables.enable = true;
```

```bash
sudo nixos-rebuild switch
# Recharger l'appartenance au groupe (ou se reconnecter)
newgrp incus-admin
```

### 2. Initialiser Incus (une seule fois)

```bash
incus admin init --minimal
incus profile list        # doit répondre sans erreur
```

### 3. Lancer le lab

```bash
LAB_BACKEND=incus ./ressources/lab/lab-up.sh
```

Ce que fait le script en Incus :

```bash
# équivalent manuel, pour info
incus launch images:ubuntu/22.04 taskflow-web1 --vm \
  -c limits.cpu=1 -c limits.memory=1GiB \
  -c user.user-data="$(printf '#cloud-config\nssh_authorized_keys:\n  - %s\n' "$(cat ~/.ssh/taskflow_lab.pub)")"
incus list taskflow-web1 -c4 --format csv   # récupérer l'IPv4
```

> L'agent Incus (présent dans l'image cloud) met parfois ~1 min à remonter l'IP : le script attend automatiquement.

### 4. Et après ?

Tout est identique aux étudiants : `ansible web -m ping`, `ansible-playbook playbooks/provision.yml`,
`k3d cluster create taskflow ...`, etc. **Seule la création des VMs diffère** ; les commandes Ansible/Kubernetes
sont les mêmes, ce qui te permet de dérouler le TP exactement comme en classe.

> Alternative homelab : tu peux aussi créer 2 VMs Ubuntu sur ton **Proxmox** et pointer l'inventaire
> dessus (`ansible_host=<IP Proxmox>`) — encore plus réaliste, mais hors du laptop.

---

## 6. Configuration SSH pour Ansible

### 6.1 Générer la paire de clés

Dans WSL2 (ou le terminal du nœud de contrôle) :

```bash
ssh-keygen -t ed25519 -f ~/.ssh/taskflow_lab -C "ansible-lab"
# Appuyer sur Entrée pour ne pas mettre de passphrase (facilite le lab)
```

### 6.2 Injecter la clé publique dans les VMs

**Méthode 1 — via `multipass exec` (la plus simple) :**

```bash
# Récupérer la clé publique
PUB_KEY=$(cat ~/.ssh/taskflow_lab.pub)

# L'injecter dans taskflow-web1
multipass exec taskflow-web1 -- bash -c "
  mkdir -p /home/ubuntu/.ssh
  chmod 700 /home/ubuntu/.ssh
  echo '$PUB_KEY' >> /home/ubuntu/.ssh/authorized_keys
  chmod 600 /home/ubuntu/.ssh/authorized_keys
  chown -R ubuntu:ubuntu /home/ubuntu/.ssh
"

# Idem pour taskflow-web2
multipass exec taskflow-web2 -- bash -c "
  mkdir -p /home/ubuntu/.ssh
  chmod 700 /home/ubuntu/.ssh
  echo '$PUB_KEY' >> /home/ubuntu/.ssh/authorized_keys
  chmod 600 /home/ubuntu/.ssh/authorized_keys
  chown -R ubuntu:ubuntu /home/ubuntu/.ssh
"
```

> Sous Windows, exécuter la commande `multipass exec` depuis PowerShell. Récupérer le contenu de la clé publique (`type C:\...` ou depuis WSL2 `cat ~/.ssh/taskflow_lab.pub`) et coller manuellement dans la commande.

**Méthode 2 — via `multipass transfer` :**

```bash
# Copier la clé publique dans la VM
multipass transfer ~/.ssh/taskflow_lab.pub taskflow-web1:/tmp/taskflow_lab.pub

# L'installer
multipass exec taskflow-web1 -- bash -c "
  cat /tmp/taskflow_lab.pub >> /home/ubuntu/.ssh/authorized_keys
  chmod 600 /home/ubuntu/.ssh/authorized_keys
"
```

### 6.3 Tester la connexion SSH

```bash
ssh -i ~/.ssh/taskflow_lab ubuntu@172.22.135.10   # adapter l'IP
# Répondre "yes" à la question fingerprint

# Quitter la VM
exit
```

### 6.4 Configurer `~/.ssh/config` (facultatif mais pratique)

```
Host taskflow-web1
    HostName 172.22.135.10
    User ubuntu
    IdentityFile ~/.ssh/taskflow_lab
    StrictHostKeyChecking no

Host taskflow-web2
    HostName 172.22.135.11
    User ubuntu
    IdentityFile ~/.ssh/taskflow_lab
    StrictHostKeyChecking no
```

---

## 7. Collections Ansible et dépendances Python

### 7.1 Fichier `requirements.yml`

À la racine du projet :

```yaml
---
collections:
  - name: community.general
    version: ">=8.0.0"
  - name: ansible.posix
    version: ">=1.5.0"
  - name: kubernetes.core
    version: ">=3.0.0"
```

### 7.2 Installer les collections

```bash
ansible-galaxy collection install -r requirements.yml
```

### 7.3 Installer le client Python Kubernetes

```bash
# Nécessaire pour le module kubernetes.core.k8s
pip install kubernetes

# Vérifier
python3 -c "import kubernetes; print(kubernetes.__version__)"
```

---

## 8. Créer le cluster k3d

```bash
# Créer le cluster avec exposition du port 80 sur le port 8080 de la machine hôte
k3d cluster create taskflow --port "8080:80@loadbalancer"

# Vérifier que le cluster est opérationnel
kubectl get nodes

# Vérifier le contexte kubectl courant
kubectl config current-context
```

Exemple de sortie de `kubectl get nodes` :

```
NAME                     STATUS   ROLES                  AGE   VERSION
k3d-taskflow-server-0    Ready    control-plane,master   30s   v1.28.x+k3s1
```

> k3d met à jour automatiquement `~/.kube/config` avec le contexte du cluster. Sous Windows, s'assurer que `KUBECONFIG` n'est pas défini sur une valeur incorrecte.

---

## 9. Vérification — Checklist

Cocher chaque point avant de commencer les TPs :

### Nœud de contrôle (WSL2/macOS/Linux)

- [ ] `ansible --version` → version >= 2.15
- [ ] `python3 --version` → version >= 3.10
- [ ] `pip show kubernetes` → installé
- [ ] `ansible-galaxy collection list` → community.general, ansible.posix, kubernetes.core présents
- [ ] `kubectl version --client` → réponse sans erreur
- [ ] `k3d version` → réponse sans erreur

### Cluster Kubernetes

- [ ] `kubectl get nodes` → nœud en état `Ready`
- [ ] `kubectl config current-context` → affiche `k3d-taskflow`
- [ ] `curl http://localhost:8080` → connexion (peut être une erreur 404, c'est normal à ce stade)

### VMs Multipass

- [ ] `multipass list` → taskflow-web1 et taskflow-web2 en état `Running`
- [ ] `ssh -i ~/.ssh/taskflow_lab ubuntu@<IP-web1>` → connexion SSH réussie
- [ ] `ssh -i ~/.ssh/taskflow_lab ubuntu@<IP-web2>` → connexion SSH réussie

### Ansible ping

```bash
# Créer un inventaire minimal de test
cat > /tmp/test_inventory.ini << 'EOF'
[web]
taskflow-web1 ansible_host=172.22.135.10
taskflow-web2 ansible_host=172.22.135.11

[web:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/taskflow_lab
ansible_python_interpreter=/usr/bin/python3
EOF

ansible -i /tmp/test_inventory.ini web -m ansible.builtin.ping
```

Résultat attendu :

```json
taskflow-web1 | SUCCESS => { "changed": false, "ping": "pong" }
taskflow-web2 | SUCCESS => { "changed": false, "ping": "pong" }
```

- [ ] Ansible ping renvoie SUCCESS sur les 2 VMs

---

## 10. Dépannage

### Multipass + Hyper-V

**Problème :** `multipass launch` échoue avec "hypervisor not available"

```powershell
# Vérifier que Hyper-V est activé
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V

# Activer Hyper-V si nécessaire (redémarrage requis)
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

> Windows Home ne supporte pas Hyper-V. Utiliser le backend VirtualBox : installer VirtualBox d'abord, puis lors de l'installation de Multipass, sélectionner "VirtualBox" comme driver.

**Problème :** les VMs Multipass ne sont pas joignables depuis WSL2

- Vérifier que l'interface réseau Multipass est visible depuis WSL2 : `ip route`
- En cas de problème réseau entre WSL2 et Hyper-V, essayer : `multipass set local.driver=hyperv` depuis PowerShell

### Docker Desktop non démarré

**Symptôme :** `docker: error during connect` ou `k3d cluster create` échoue

- Lancer Docker Desktop depuis le menu Démarrer (icône dans la barre des tâches)
- Attendre que le daemon soit prêt (icône Docker verte)
- Vérifier l'intégration WSL2 dans Settings → Resources → WSL Integration

### KUBECONFIG incorrect

**Symptôme :** `kubectl` renvoie "no configuration has been provided"

```bash
# Vérifier la variable d'environnement
echo $KUBECONFIG

# Si définie sur une valeur incorrecte, la réinitialiser
unset KUBECONFIG

# Ou pointer explicitement vers le fichier par défaut
export KUBECONFIG=~/.kube/config

# Vérifier les contextes disponibles
kubectl config get-contexts
```

### Droits SSH refusés

**Symptôme :** `Permission denied (publickey)` lors du ping Ansible

```bash
# Vérifier les permissions côté VM
multipass exec taskflow-web1 -- ls -la /home/ubuntu/.ssh/
# authorized_keys doit être 600, .ssh doit être 700

# Corriger les permissions
multipass exec taskflow-web1 -- chmod 700 /home/ubuntu/.ssh
multipass exec taskflow-web1 -- chmod 600 /home/ubuntu/.ssh/authorized_keys

# Vérifier que la bonne clé publique est injectée
multipass exec taskflow-web1 -- cat /home/ubuntu/.ssh/authorized_keys
cat ~/.ssh/taskflow_lab.pub   # doit correspondre
```

**Symptôme :** Ansible utilise la mauvaise clé SSH

```bash
# Forcer la clé dans la commande ad-hoc
ansible -i inventory.ini web -m ping \
  --private-key ~/.ssh/taskflow_lab \
  -u ubuntu

# Ou ajouter dans ansible.cfg :
# [defaults]
# private_key_file = ~/.ssh/taskflow_lab
```

### pip install kubernetes échoue dans un environnement pipx

```bash
# Injecter kubernetes dans le venv Ansible géré par pipx
pipx inject ansible kubernetes

# Vérifier
pipx runpip ansible show kubernetes
```
