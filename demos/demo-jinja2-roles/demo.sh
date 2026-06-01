#!/usr/bin/env bash
# =============================================================================
# DÉMO 2 — Template Jinja2 + Rôle Ansible + Handler
# Formation M2 DevOps - Ansible & Kubernetes | ForEach Academy
# Formateur : Fabrice Claeys
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${SCRIPT_DIR}/inventory.ini"
PLAYBOOK="${SCRIPT_DIR}/playbook.yml"
CONF_FILE="/tmp/taskflow.conf"

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

titre()  { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"; echo -e "${BOLD}${CYAN}  $1${RESET}"; echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"; }
etape()  { echo -e "\n${YELLOW}▶ $1${RESET}"; }
info()   { echo -e "  ${MAGENTA}ℹ  $1${RESET}"; }
pause()  { echo -e "\n${GREEN}[PAUSE PÉDAGOGIQUE]${RESET} $1"; read -p "  Appuyez sur Entrée pour continuer... " _; echo; }

# =============================================================================
titre "DÉMO 2 : Template Jinja2 + Rôle + Handler"
echo "Répertoire : ${SCRIPT_DIR}"
echo "Inventaire : ${INVENTORY}"
# =============================================================================

pause "Prêt à démarrer ?"

# -----------------------------------------------------------------------------
etape "1/7 — Structure d'un rôle : ce que génère ansible-galaxy role init"
info "Un rôle est une unité de réutilisation Ansible avec une structure standardisée."
info "Voici la structure du rôle 'webconfig' que nous allons utiliser :"
echo
find "${SCRIPT_DIR}/roles" -type f | sort | sed "s|${SCRIPT_DIR}/||"

pause "Notez les dossiers tasks/, templates/, handlers/, defaults/. Chacun a un rôle précis."

# -----------------------------------------------------------------------------
etape "2/7 — Le template Jinja2 : app.conf.j2"
info "Un template Jinja2 permet de générer des fichiers dynamiquement."
info "Syntaxe clé : {{ variable }}, {% if %}, {% for %}, filtres | default(), | upper, etc."
echo
echo "--- Contenu du template ---"
cat "${SCRIPT_DIR}/roles/webconfig/templates/app.conf.j2"
echo "--- Fin du template ---"

pause "Identifiez : variables, blocs conditionnels ({% if %}), boucles ({% for %}), filtres (| upper, | default)."

# -----------------------------------------------------------------------------
etape "3/7 — Les valeurs par défaut : defaults/main.yml"
info "defaults/main.yml définit les valeurs par défaut des variables du rôle."
info "Elles peuvent être surchargées par : vars/, group_vars/, host_vars/, -e sur la ligne de commande."
echo
cat "${SCRIPT_DIR}/roles/webconfig/defaults/main.yml"

pause "La surcharge de variables est un mécanisme central de la réutilisabilité des rôles."

# -----------------------------------------------------------------------------
etape "4/7 — PLAYBOOK — Première exécution (attendu : 'changed' + handler)"
info "Le fichier ${CONF_FILE} n'existe pas encore."
info "Le module 'template' va le créer => CHANGED => le handler sera notifié."
echo
ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}"

pause "Regardez : CHANGED pour la tâche 'template', puis le HANDLER s'est exécuté à la fin."

# -----------------------------------------------------------------------------
etape "5/7 — Résultat : afficher le fichier de config généré"
info "Le template a été rendu avec les valeurs de defaults/main.yml."
echo
echo "--- Contenu de ${CONF_FILE} ---"
cat "${CONF_FILE}"
echo "--- Fin du fichier ---"

pause "Le template Jinja2 a été rendu : variables substituées, blocs conditionnels évalués, boucles déroulées."

# -----------------------------------------------------------------------------
etape "6/7 — PLAYBOOK — Deuxième exécution sans changement (idempotence)"
info "On relance sans modifier les variables."
info "Le fichier existe avec le même contenu => OK, le handler NE sera PAS déclenché."
echo
ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}"

pause "PLAY RECAP : changed=0. Le handler n'a pas été déclenché car rien n'a changé."

# -----------------------------------------------------------------------------
etape "7/7 — Surcharge de variable avec -e : changer l'environnement en 'production'"
info "On surcharge app_env=production et app_debug=true via -e."
info "Le contenu du fichier va changer => CHANGED => handler redéclenché."
echo
echo "  Commande : ansible-playbook -i inventory.ini playbook.yml -e \"app_env=production app_debug=true\""
echo
ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" -e "app_env=production app_debug=true"

echo
echo "--- Nouveau contenu de ${CONF_FILE} après surcharge ---"
cat "${CONF_FILE}"
echo "--- Fin du fichier ---"

pause "Notez : le bloc [security] SSL est apparu ({% if app_env == 'production' %}), et debug=true."

# =============================================================================
titre "BILAN PÉDAGOGIQUE"
echo
echo "  TEMPLATE JINJA2 :"
echo "    - {{ variable }}          => substitution de variable"
echo "    - {% if condition %}      => bloc conditionnel"
echo "    - {% for item in list %}  => boucle"
echo "    - | default('val')        => filtre (valeur par défaut si variable nulle)"
echo "    - | upper / | lower       => filtres de transformation"
echo
echo "  RÔLE ANSIBLE :"
echo "    tasks/main.yml      => liste des tâches du rôle"
echo "    templates/          => fichiers Jinja2"
echo "    handlers/main.yml   => actions déclenchées sur notification"
echo "    defaults/main.yml   => valeurs par défaut (priorité la plus basse)"
echo
echo "  HANDLER :"
echo "    - Notifié par une tâche via 'notify: Nom du handler'"
echo "    - S'exécute UNE SEULE FOIS à la fin du playbook"
echo "    - S'exécute UNIQUEMENT si la tâche notifiante est CHANGED"
echo "    - Idéal pour : reload de service, redémarrage conditionnel"
echo
echo "  IDEMPOTENCE :"
echo "    - Le module 'template' calcule le hash du fichier rendu"
echo "    - Si le hash est identique à l'existant => OK (aucune action)"
echo "    - Sinon => CHANGED (fichier mis à jour + handler notifié)"
echo
# =============================================================================

# Nettoyage optionnel
echo -e "${YELLOW}Nettoyage optionnel : rm -f ${CONF_FILE}${RESET}"
