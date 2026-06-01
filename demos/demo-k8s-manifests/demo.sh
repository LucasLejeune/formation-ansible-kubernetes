#!/usr/bin/env bash
# =============================================================================
# DÉMO 3 — k3d + Manifests Kubernetes déclaratifs
# Formation M2 DevOps - Ansible & Kubernetes | ForEach Academy
# Formateur : Fabrice Claeys
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/manifests"
CLUSTER_NAME="demo"
LOCAL_PORT="8088"
NAMESPACE="demo"

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

titre()  { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"; echo -e "${BOLD}${CYAN}  $1${RESET}"; echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"; }
etape()  { echo -e "\n${YELLOW}▶ $1${RESET}"; }
info()   { echo -e "  ${GREEN}ℹ  $1${RESET}"; }
warn()   { echo -e "  ${RED}⚠  $1${RESET}"; }
pause()  { echo -e "\n${GREEN}[PAUSE PÉDAGOGIQUE]${RESET} $1"; read -p "  Appuyez sur Entrée pour continuer... " _; echo; }

# =============================================================================
titre "DÉMO 3 : Kubernetes — Manifests déclaratifs avec k3d"
echo "Cluster : ${CLUSTER_NAME} | Namespace : ${NAMESPACE} | Port local : ${LOCAL_PORT}"
# =============================================================================

pause "Prêt à démarrer ?"

# -----------------------------------------------------------------------------
etape "0/9 — Vérification des prérequis"
info "Vérification de k3d et kubectl..."
echo
echo "  k3d version :"
k3d version

echo
echo "  kubectl version (client) :"
kubectl version --client --short 2>/dev/null || kubectl version --client

pause "k3d et kubectl sont disponibles."

# -----------------------------------------------------------------------------
etape "1/9 — Créer le cluster k3d"
info "k3d crée un cluster Kubernetes dans Docker (k3s dans des conteneurs)."
info "Le port 8088 de la machine est mappé sur le port 80 du loadbalancer du cluster."
echo
echo "  Commande : k3d cluster create ${CLUSTER_NAME} --port \"${LOCAL_PORT}:80@loadbalancer\""
echo

# Supprimer le cluster s'il existe déjà (cas de reprise de démo)
if k3d cluster list | grep -q "^${CLUSTER_NAME}"; then
    warn "Un cluster '${CLUSTER_NAME}' existe déjà. Suppression pour repartir de zéro..."
    k3d cluster delete "${CLUSTER_NAME}"
    echo
fi

k3d cluster create "${CLUSTER_NAME}" --port "${LOCAL_PORT}:80@loadbalancer"

echo
info "Mise à jour du kubeconfig..."
k3d kubeconfig merge "${CLUSTER_NAME}" --kubeconfig-switch-context

pause "Le cluster est créé et le contexte kubectl est mis à jour automatiquement."

# -----------------------------------------------------------------------------
etape "2/9 — Vérifier l'état du cluster"
echo "  Commande : kubectl get nodes"
echo
kubectl get nodes
echo
echo "  Commande : kubectl cluster-info"
echo
kubectl cluster-info

pause "Le cluster a un nœud 'Ready'. On peut déployer."

# -----------------------------------------------------------------------------
etape "3/9 — Appliquer les manifests (approche DÉCLARATIVE)"
info "kubectl apply -f = on DÉCLARE l'état désiré, Kubernetes s'occupe de l'atteindre."
info "C'est différent de l'approche impérative (kubectl run, kubectl create)."
echo
echo "  Manifests à appliquer :"
ls -1 "${MANIFESTS_DIR}/"
echo
echo "  Commande : kubectl apply -f manifests/"
echo
kubectl apply -f "${MANIFESTS_DIR}/"

pause "Tous les objets ont été créés. Notez 'created' (1ère fois) vs 'unchanged' (idempotence)."

# -----------------------------------------------------------------------------
etape "4/9 — Observer les ressources créées"
echo "  Commande : kubectl get all -n ${NAMESPACE}"
echo
kubectl get all -n "${NAMESPACE}"

pause "Deployment, ReplicaSet, Pods, Service sont tous visibles. Les Pods sont peut-être encore en 'ContainerCreating'."

# -----------------------------------------------------------------------------
etape "5/9 — Attendre que le déploiement soit prêt (rollout status)"
info "kubectl rollout status attend que tous les pods soient prêts (readiness probe OK)."
echo
echo "  Commande : kubectl rollout status deployment/webserver -n ${NAMESPACE}"
echo
kubectl rollout status deployment/webserver -n "${NAMESPACE}"

echo
info "Re-vérification de l'état :"
kubectl get all -n "${NAMESPACE}"

pause "Les 2 réplicas sont Running et Ready."

# -----------------------------------------------------------------------------
etape "6/9 — Scaler le déploiement à 4 réplicas"
info "Le scaling est déclaratif : on indique l'état DÉSIRÉ, pas les commandes à exécuter."
echo
echo "  Commande : kubectl scale deployment/webserver --replicas=4 -n ${NAMESPACE}"
echo
kubectl scale deployment/webserver --replicas=4 -n "${NAMESPACE}"

echo
info "Surveillance des pods en temps réel (5 secondes)..."
echo
kubectl get pods -n "${NAMESPACE}" -w &
WATCH_PID=$!
sleep 5
kill "${WATCH_PID}" 2>/dev/null || true

echo
kubectl get pods -n "${NAMESPACE}"

pause "4 pods sont maintenant Running. Le Deployment a mis à jour le ReplicaSet."

# -----------------------------------------------------------------------------
etape "7/9 — Re-appliquer les manifests (idempotence déclarative)"
info "On réapplique les manifests originaux (2 réplicas)."
info "Kubernetes va réconcilier : supprimer 2 pods pour revenir à l'état déclaré."
echo
echo "  Commande : kubectl apply -f manifests/"
echo
kubectl apply -f "${MANIFESTS_DIR}/"

echo
info "Attente du rollout..."
kubectl rollout status deployment/webserver -n "${NAMESPACE}"
echo
kubectl get pods -n "${NAMESPACE}"

pause "Retour à 2 réplicas. 'kubectl apply' re-synchronise toujours vers l'état déclaré."

# -----------------------------------------------------------------------------
etape "8/9 — Accéder à l'application via port-forward"
info "ClusterIP n'est accessible que dans le cluster. port-forward crée un tunnel temporaire."
echo
echo "  Commande : kubectl port-forward svc/webserver 9090:80 -n ${NAMESPACE}"
echo
info "Lancement du port-forward en arrière-plan (10 secondes)..."
kubectl port-forward svc/webserver 9090:80 -n "${NAMESPACE}" &
PF_PID=$!
sleep 2

echo
info "Test avec curl :"
curl -s http://localhost:9090 | grep -o "<title>.*</title>" || echo "(curl non disponible, ouvrez http://localhost:9090 dans votre navigateur)"

sleep 2
kill "${PF_PID}" 2>/dev/null || true

pause "L'application répond. En production, on utiliserait un Ingress ou un Service NodePort/LoadBalancer."

# -----------------------------------------------------------------------------
etape "9/9 — Nettoyage : suppression du cluster"
warn "La suppression du cluster est IRRÉVERSIBLE pour cette session."
read -p "  Confirmer la suppression du cluster '${CLUSTER_NAME}' ? [o/N] " confirm
if [[ "${confirm}" =~ ^[oO]$ ]]; then
    echo
    k3d cluster delete "${CLUSTER_NAME}"
    echo
    info "Cluster supprimé."
else
    echo
    warn "Cluster conservé. Pour nettoyer manuellement : k3d cluster delete ${CLUSTER_NAME}"
fi

# =============================================================================
titre "BILAN PÉDAGOGIQUE"
echo
echo "  APPROCHE DÉCLARATIVE :"
echo "    - On décrit l'ÉTAT FINAL désiré dans des fichiers YAML"
echo "    - Kubernetes calcule et applique les actions nécessaires pour y arriver"
echo "    - 'kubectl apply' est idempotent : relancer ne crée pas de doublons"
echo
echo "  RÉCONCILIATION :"
echo "    - K8s surveille en permanence l'état réel vs l'état désiré"
echo "    - Si un pod plante => K8s en recrée un (auto-healing)"
echo "    - Si on scale manuellement => 'kubectl apply' remet le bon nombre"
echo
echo "  OBJETS K8S utilisés :"
echo "    Namespace    => isolation logique des ressources"
echo "    Deployment   => gère les pods et le ReplicaSet, supporte les rollouts"
echo "    ReplicaSet   => maintient le nombre de réplicas demandé"
echo "    Pod          => unité minimale d'exécution (1+ conteneurs)"
echo "    Service      => point d'accès réseau stable pour les pods"
echo
echo "  SCALING :"
echo "    - Horizontal : augmenter le nombre de réplicas (kubectl scale)"
echo "    - Déclaratif : modifier replicas: dans le manifest + kubectl apply"
echo
# =============================================================================
