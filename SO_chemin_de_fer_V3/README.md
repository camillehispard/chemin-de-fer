# SO — Chemin de fer collaboratif

Cette version transforme le prototype local en outil partagé pour l'équipe.

## Ce qui est déjà prévu
- connexion par e-mail ;
- même chemin de fer pour toute l'équipe ;
- mises à jour en temps réel ;
- pages déplaçables par glisser-déposer ;
- rubrique, sujet, responsable, calibrage, statut, notes ;
- doubles pages ;
- plusieurs numéros et duplication de structure ;
- « À arbitrer », « Idées à garder », « Sujets reportés » ;
- recherche dans les archives ;
- impression / PDF ;
- SO Mag 48 prérempli au premier lancement.

## Mise en ligne — version simple

### 1. Créer la base
Créer un projet Supabase.

Dans le SQL Editor, copier-coller tout le contenu de `schema.sql` puis l'exécuter.

### 2. Activer la connexion e-mail
Dans Supabase > Authentication, activer la connexion par e-mail / Magic Link.

Pour un outil interne, créer les comptes de l'équipe puis désactiver les inscriptions publiques si vous ne voulez pas que n'importe quelle adresse puisse créer un compte.

### 3. Relier l'application
Dans le tableau de bord Supabase, récupérer :
- Project URL
- Publishable key

Modifier `config.js` :

window.SO_CONFIG = {
  url: "https://....supabase.co",
  key: "sb_publishable_..."
};

Ne jamais mettre de Secret key dans `config.js`.

### 4. Tester en local
Dans le dossier de l'application, lancer un petit serveur web :

Python 3 :
python3 -m http.server 8080

Puis ouvrir :
http://localhost:8080

Le simple double-clic sur `index.html` peut fonctionner pour l'affichage, mais l'authentification par lien e-mail est plus fiable via localhost.

### 5. Partager avec l'équipe
Héberger les trois fichiers web (`index.html`, `config.js`) sur un hébergement statique interne ou public HTTPS.
Configurer ensuite dans Supabase > Authentication > URL Configuration :
- Site URL = l'adresse du site
- Redirect URLs = cette même adresse

Chaque membre ouvre la même URL et se connecte avec son e-mail.

## Sécurité
Le fichier utilise une Publishable key côté navigateur et les tables ont Row Level Security activé.
La version fournie autorise tous les utilisateurs *authentifiés* du projet à modifier les données. Pour une mise en production municipale, il est recommandé de limiter les inscriptions/comptes aux membres de l'équipe et de faire valider l'hébergement et les règles d'accès par la DSI.

## Fichiers
- `index.html` : application
- `config.js` : connexion au projet
- `schema.sql` : base de données et règles d'accès
