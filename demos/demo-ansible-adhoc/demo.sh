#!/usr/bin/env bash
# =============================================================================
# DÉMO 1 — Commandes ad-hoc Ansible & Idempotence
# Formation M2 DevOps - Ansible & Kubernetes | ForEach Academy
# Formateur : Fabrice Claeys
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${SCRIPT_DIR}/inventory.ini"
PLAYBOOK="${SCRIPT_DIR}/playbook.yml"

# Couleurs pour la lisibilité en live
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

titre() { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"; echo -e "${BOLD}${CYAN}  $1${RESET}"; echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"; }
etape() { echo -e "\n${YELLOW}▶ $1${RESET}"; }
pause() { echo -e "\n${GREEN}[PAUSE PÉDAGOGIQUE]${RESET} $1"; read -p "  Appuyez sur Entrée pour continuer... " _; echo; }

# =============================================================================
titre "DÉMO 1 : Commandes ad-hoc & Idempotence"
echo "Inventaire utilisé : ${INVENTORY}"
echo "Cible              : localhost (connexion locale, sans SSH)"
# =============================================================================

pause "Prêt à démarrer ?"

# -----------------------------------------------------------------------------
etape "1/6 — Version d'Ansible installée"
echo "  Commande : ansible --version"
echo
ansible --version

pause "Notez la version de Python et le chemin de la configuration."

# -----------------------------------------------------------------------------
etape "2/6 — Module PING : vérifier que l'hôte répond"
echo "  Commande : ansible all -i inventory.ini -m ping"
echo "  Le module ping Ansible n'est PAS un ping ICMP :"
echo "  il teste la connexion SSH (ou locale ici) ET l'interpréteur Python."
echo
ansible all -i "${INVENTORY}" -m ping

pause "Résultat 'pong' = l'hôte est joignable et Python fonctionne."

# -----------------------------------------------------------------------------
etape "3/6 — Module SETUP : récupérer les facts de distribution"
echo "  Commande : ansible all -i inventory.ini -m setup -a 'filter=ansible_distribution*'"
echo "  Les 'facts' sont des variables collectées automatiquement sur l'hôte cible."
echo "  On filtre ici sur les informations de distribution."
echo
ansible all -i "${INVENTORY}" -m setup -a 'filter=ansible_distribution*'

pause "Les facts sont accessibles dans les playbooks via {{ ansible_distribution }}, etc."

# -----------------------------------------------------------------------------
etape "4/6 — Module COMMAND : exécuter une commande shell arbitraire"
echo "  Commande : ansible all -i inventory.ini -m ansible.builtin.command -a 'date'"
echo "  ATTENTION : le module 'command' n'est PAS idempotent par nature."
echo "  Il exécute la commande à chaque fois, sans vérification d'état."
echo
ansible all -i "${INVENTORY}" -m ansible.builtin.command -a 'date'

pause "Comparez avec les modules déclaratifs (copy, file, package) qui vérifient l'état avant d'agir."

# -----------------------------------------------------------------------------
etape "5/6 — PLAYBOOK — Première exécution (attendu : 'changed')"
echo "  Commande : ansible-playbook -i inventory.ini playbook.yml"
echo
echo "  Le playbook contient 3 tâches :"
echo "    1. Créer /tmp/ansible-demo-marker.txt (copy)"
echo "    2. Vérifier la présence de curl (stat)"
echo "    3. Afficher les facts de distribution (debug)"
echo
echo "  Lors de la 1ère exécution, la tâche 'copy' va créer le fichier"
echo "  => elle sera marquée CHANGED (jaune)."
echo
ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}"

pause "Regardez le PLAY RECAP : 'changed=1' pour la création du fichier."

# -----------------------------------------------------------------------------
etape "6/6 — PLAYBOOK — Deuxième exécution (attendu : 'ok', pas de 'changed')"
echo "  On relance exactement la même commande sans rien modifier."
echo "  Le fichier existe déjà avec le même contenu => Ansible ne le recrée PAS."
echo "  Toutes les tâches seront marquées OK (vert)."
echo
ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}"

pause "CONCEPT CLÉ : l'idempotence."

# =============================================================================
titre "BILAN PÉDAGOGIQUE"
echo
echo "  IDEMPOTENCE : propriété fondamentale d'Ansible."
echo "    - Un module idempotent vérifie l'ÉTAT actuel avant d'agir."
echo "    - Si l'état cible est déjà atteint => OK (aucune action)."
echo "    - Si l'état cible n'est pas atteint => CHANGED (action effectuée)."
echo
echo "  Conséquence : on peut relancer un playbook autant de fois que"
echo "  nécessaire sans craindre de casser quelque chose."
echo
echo "  Modules ad-hoc utiles :"
echo "    ansible -m ping          => test de connectivité"
echo "    ansible -m setup         => collecte de facts"
echo "    ansible -m command       => commande shell (non idempotent)"
echo "    ansible -m copy          => copie de fichiers (idempotent)"
echo "    ansible -m file          => gestion de fichiers/dossiers (idempotent)"
echo "    ansible -m package       => gestion de paquets (idempotent)"
echo
echo "  Vérification du fichier créé :"
cat /tmp/ansible-demo-marker.txt
echo
# =============================================================================
