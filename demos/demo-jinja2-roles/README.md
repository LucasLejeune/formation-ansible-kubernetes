# Démo 2 — Template Jinja2 + Rôle + Handler

## Objectif pédagogique

Comprendre les trois mécanismes complémentaires qui rendent Ansible puissant pour la gestion de configurations :
- Les **templates Jinja2** pour générer des fichiers dynamiques
- Les **rôles** pour structurer et réutiliser le code Ansible
- Les **handlers** pour déclencher des actions conditionnelles en fin de play

## Prérequis

| Outil | Version minimale | Vérification |
|-------|-----------------|--------------|
| Python | 3.8+ | `python3 --version` |
| Ansible | 2.14+ | `ansible --version` |

## Structure de la démo

```
demo-jinja2-roles/
├── README.md
├── inventory.ini
├── playbook.yml
├── demo.sh
└── roles/
    └── webconfig/
        ├── defaults/
        │   └── main.yml          # Variables par défaut
        ├── templates/
        │   └── app.conf.j2       # Template Jinja2
        ├── tasks/
        │   └── main.yml          # Tâches du rôle
        └── handlers/
            └── main.yml          # Handler de rechargement
```

## Lancement

```bash
chmod +x demo.sh
./demo.sh
```

Ou étape par étape :

```bash
# Exécution initiale (changed + handler)
ansible-playbook -i inventory.ini playbook.yml

# Afficher le fichier généré
cat /tmp/taskflow.conf

# Rejouer sans changement (idempotence, ok, pas de handler)
ansible-playbook -i inventory.ini playbook.yml

# Surcharger une variable (changed + handler redéclenché)
ansible-playbook -i inventory.ini playbook.yml -e "app_env=production app_debug=true"
```

## Déroulé pas-à-pas

### Étape 1 : Structure du rôle

Un rôle Ansible est un répertoire avec une structure conventionnelle. `ansible-galaxy role init <nom>` génère ce squelette :

```
roles/<nom>/
├── tasks/main.yml       # Obligatoire — point d'entrée des tâches
├── handlers/main.yml    # Optionnel — actions sur notification
├── templates/           # Optionnel — templates Jinja2 (.j2)
├── files/               # Optionnel — fichiers statiques
├── vars/main.yml        # Optionnel — variables (priorité haute)
├── defaults/main.yml    # Optionnel — variables par défaut (priorité basse)
├── meta/main.yml        # Optionnel — métadonnées, dépendances
└── README.md
```

### Étape 2 : Template Jinja2

Le fichier `templates/app.conf.j2` illustre les constructions Jinja2 essentielles :

| Construction | Exemple dans le template | Rôle |
|-------------|--------------------------|------|
| Variable | `{{ app_name }}` | Substitution |
| Filtre | `{{ app_name \| upper }}` | Transformation en majuscules |
| Filtre default | `{{ app_log_level \| default('info') }}` | Valeur de repli |
| Conditionnel | `{% if app_debug %}...{% endif %}` | Bloc conditionnel |
| Boucle | `{% for feature in app_features %}` | Itération |
| Variable Ansible | `{{ ansible_os_family }}` | Fact système |

### Étape 3 : Priorité des variables

Du plus faible au plus fort :
1. `defaults/main.yml` — valeurs par défaut du rôle
2. `group_vars/` — variables de groupe
3. `host_vars/` — variables d'hôte
4. `vars/main.yml` — variables du rôle
5. `-e "variable=valeur"` — extra-vars (priorité maximale)

### Étape 4 : Handler

Un **handler** est une tâche spéciale qui :
- Est notifiée via `notify: Nom du handler` dans une tâche
- Ne s'exécute que si la tâche notifiante est `CHANGED`
- S'exécute **une seule fois** à la fin du play (pas immédiatement)
- Est idéal pour des actions comme `systemctl reload`, `nginx -s reload`

## Points pédagogiques à souligner

### Pourquoi les templates ?

Sans template : on copie un fichier statique identique partout. Avec template :
- Une seule source de vérité (le `.j2`)
- Adapté à chaque environnement (dev/staging/production)
- Intègre des informations dynamiques (facts, dates, hôtes)

### Pourquoi les rôles ?

- **Réutilisabilité** : un rôle peut être appliqué à n'importe quel playbook
- **Encapsulation** : les variables, tâches et handlers sont regroupés
- **Partage** : Ansible Galaxy permet de partager des rôles

### Idempotence du module template

Le module `ansible.builtin.template` :
1. Rend le template Jinja2 en mémoire
2. Calcule le hash du résultat
3. Compare avec le hash du fichier existant
4. Écrit le fichier **uniquement si les hashs diffèrent**
5. Notifie le handler **uniquement si le fichier a changé**

## Résultat attendu

Après la 1ère exécution :
```
TASK [webconfig : Générer le fichier de configuration] CHANGED
RUNNING HANDLER [webconfig : Recharger la configuration] OK
PLAY RECAP: changed=2
```

Après la 2ème exécution (sans changement) :
```
TASK [webconfig : Générer le fichier de configuration] OK
PLAY RECAP: changed=0
```

Après la 3ème exécution avec `-e "app_env=production"` :
```
TASK [webconfig : Générer le fichier de configuration] CHANGED
RUNNING HANDLER [webconfig : Recharger la configuration] OK
PLAY RECAP: changed=1
```

## Nettoyage

```bash
rm -f /tmp/taskflow.conf
```
