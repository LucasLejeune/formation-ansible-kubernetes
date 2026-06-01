#!/usr/bin/env bash
# =============================================================================
# DÉMO 4 — Ansible pilote Kubernetes avec kubernetes.core
# Formation M2 DevOps - Ansible & Kubernetes | ForEach Academy
# Formateur : Fabrice Claeys
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${SCRIPT_DIR}/inventory.ini"
DEPLOY_PLAYBOOK="${SCRIPT_DIR}/deploy.yml"
CLEANUP_PLAYBOOK="${SCRIPT_DIR}/cleanup.yml"
CLUSTER_NAME="demo-ansible-k8s"
NAMESPACE="demo-ansible"

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

titre()  { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"; echo -e "${BOLD}${CYAN}  $1${RESET}"; echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"; }
etape()  { echo -e "\n${YELLOW}▶ $1${RESET}"; }
info()   { echo -e "  ${GREEN}ℹ  $1${RESET}"; }
warn()   { echo -e "  ${RED}⚠  $1${RESET}"; }
succes() { echo -e "  ${GREEN}✓  $1${RESET}"; }
pause()  { echo -e "\n${GREEN}[PAUSE PÉDAGOGIQUE]${RESET} $1"; read -p "  Appuyez sur Entrée pour continuer... " _; echo; }

# =============================================================================
titre "DÉMO 4 : Ansible pilote Kubernetes — kubernetes.core"
echo "Namespace cible : ${NAMESPACE}"
echo "Cluster         : ${CLUSTER_NAME} (k3d)"
# =============================================================================

pause "Prêt à démarrer ?"

# -----------------------------------------------------------------------------
etape "1/8 — Installer la collection kubernetes.core"
info "Les collections Ansible étendent les modules disponibles."
info "kubernetes.core apporte : k8s, k8s_info, k8s_scale, helm, etc."
echo
echo "  Commande : ansible-galaxy collection install -r requirements.yml"
echo
ansible-galaxy collection install -r "${SCRIPT_DIR}/requirements.yml"

pause "La collection kubernetes.core est installée (ou déjà à jour)."

# -----------------------------------------------------------------------------
etape "2/8 — Prérequis Python : bibliothèque 'kubernetes'"
info "Le module kubernetes.core.k8s appelle l'API K8s via Python."
info "Il faut la bibliothèque Python 'kubernetes' sur le control node."
echo
echo "  Vérification :"
if python3 -c "import kubernetes; print('  kubernetes Python SDK version :', kubernetes.__version__)" 2>/dev/null; then
    succes "La bibliothèque Python 'kubernetes' est disponible."
else
    warn "La bibliothèque 'kubernetes' n'est pas installée."
    echo "  Installation : pip install kubernetes"
    echo
    read -p "  Installer maintenant ? [o/N] " install_k8s
    if [[ "${install_k8s}" =~ ^[oO]$ ]]; then
        pip install kubernetes
    else
        warn "Sans cette bibliothèque, le playbook échouera. Installation manuelle requise."
    fi
fi

pause "La bibliothèque Python est prête."

# -----------------------------------------------------------------------------
etape "3/8 — Vérifier / Créer le cluster k3d"
info "Le playbook Ansible a besoin d'un cluster K8s accessible via kubeconfig."
echo
if kubectl cluster-info &>/dev/null 2>&1; then
    succes "Un cluster K8s est déjà accessible."
    echo
    kubectl cluster-info
else
    info "Aucun cluster accessible. Création d'un cluster k3d '${CLUSTER_NAME}'..."
    if k3d cluster list | grep -q "^${CLUSTER_NAME}"; then
        warn "Cluster '${CLUSTER_NAME}' existe mais kubeconfig non configuré. Merge..."
        k3d kubeconfig merge "${CLUSTER_NAME}" --kubeconfig-switch-context
    else
        k3d cluster create "${CLUSTER_NAME}"
        k3d kubeconfig merge "${CLUSTER_NAME}" --kubeconfig-switch-context
    fi
    succes "Cluster prêt."
fi

pause "Le cluster est accessible. Ansible utilisera le kubeconfig courant (~/.kube/config)."

# -----------------------------------------------------------------------------
etape "4/8 — PLAYBOOK — Première exécution (attendu : 'changed')"
info "Ansible va créer via l'API K8s : Namespace, Deployment, Service."
info "Comme les ressources n'existent pas encore => toutes les tâches seront CHANGED."
echo
echo "  Commande : ansible-playbook -i inventory.ini deploy.yml"
echo
ansible-playbook -i "${INVENTORY}" "${DEPLOY_PLAYBOOK}"

pause "Regardez le PLAY RECAP : changed=3 (namespace + deployment + service)."

# -----------------------------------------------------------------------------
etape "5/8 — Vérifier avec kubectl que les ressources existent"
info "On peut vérifier le résultat avec kubectl, indépendamment d'Ansible."
echo
echo "  Commande : kubectl get all -n ${NAMESPACE}"
echo
kubectl get all -n "${NAMESPACE}"

pause "Namespace, Pods, ReplicaSet, Deployment, Service : tout est là."

# -----------------------------------------------------------------------------
etape "6/8 — PLAYBOOK — Deuxième exécution (idempotence : attendu 'ok')"
info "On relance exactement la même commande sans rien modifier."
info "Ansible compare la spec actuelle avec la spec désirée."
info "Si identiques => OK (aucune action). C'est l'idempotence vs kubectl apply."
echo
echo "  Commande : ansible-playbook -i inventory.ini deploy.yml"
echo
ansible-playbook -i "${INVENTORY}" "${DEPLOY_PLAYBOOK}"

pause "PLAY RECAP : changed=0. Ansible a vérifié et n'a rien modifié."

# -----------------------------------------------------------------------------
etape "7/8 — Modifier un paramètre et relancer (-e k8s_replicas=4)"
info "On surcharge la variable k8s_replicas pour passer à 4 réplicas."
info "Seul le Deployment sera CHANGED (la spec replicas diffère)."
echo
echo "  Commande : ansible-playbook -i inventory.ini deploy.yml -e 'k8s_replicas=4'"
echo
ansible-playbook -i "${INVENTORY}" "${DEPLOY_PLAYBOOK}" -e "k8s_replicas=4"

echo
info "Vérification kubectl :"
kubectl get pods -n "${NAMESPACE}"

pause "changed=1 (uniquement le Deployment). Namespace et Service sont inchangés (ok)."

# -----------------------------------------------------------------------------
etape "8/8 — Nettoyage avec state: absent (playbook cleanup)"
info "Pour supprimer les ressources, on utilise state: absent."
info "C'est aussi idempotent : si le namespace n'existe pas, aucune erreur."
echo
echo "  Commande : ansible-playbook -i inventory.ini cleanup.yml"
echo
ansible-playbook -i "${INVENTORY}" "${CLEANUP_PLAYBOOK}"

echo
info "Vérification (le namespace ne doit plus exister) :"
kubectl get namespace "${NAMESPACE}" 2>&1 || echo "  => Namespace '${NAMESPACE}' supprimé (Not Found attendu)."

pause "Nettoyage complet. On peut relancer deploy.yml et obtenir de nouveau changed=3."

# =============================================================================
titre "BILAN PÉDAGOGIQUE"
echo
echo "  KUBERNETES.CORE :"
echo "    kubernetes.core.k8s       => créer/modifier/supprimer n'importe quel objet K8s"
echo "    kubernetes.core.k8s_info  => interroger l'API K8s, attendre des conditions"
echo "    kubernetes.core.k8s_scale => scaler un Deployment/StatefulSet"
echo "    kubernetes.core.helm      => déployer des Helm charts"
echo
echo "  AVANTAGE D'ANSIBLE VS kubectl APPLY :"
echo "    - Un seul outil pour provisionner les VMs ET déployer sur K8s"
echo "    - Variables Ansible réutilisables (inventaire, group_vars, vault)"
echo "    - Logique conditionnelle, boucles, handlers dans le même playbook"
echo "    - Secrets gérés via ansible-vault (pas en clair dans les manifests)"
echo "    - Idempotence garantie par Ansible, pas juste par kubectl"
echo
echo "  IDEMPOTENCE ANSIBLE vs KUBECTL :"
echo "    kubectl apply : rejoue l'intégralité des manifests (server-side apply)"
echo "    ansible k8s   : compare champ par champ, ne PATCH que les différences"
echo "    Les deux sont idempotents, mais Ansible offre plus de contrôle"
echo
echo "  STATE : present / absent"
echo "    present => créer ou mettre à jour (kubectl apply équivalent)"
echo "    absent  => supprimer si existe (kubectl delete équivalent, sans erreur si absent)"
echo
echo "  BONNE PRATIQUE : structure de projet type"
echo "    inventory/group_vars/k8s.yml  => variables K8s communes"
echo "    playbooks/deploy.yml          => déploiement applicatif"
echo "    playbooks/cleanup.yml         => nettoyage"
echo "    roles/app-deploy/             => rôle réutilisable pour les déploiements K8s"
echo
# =============================================================================
