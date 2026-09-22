# Installation V3

1. Dans Supabase > SQL Editor, exécuter `MIGRATION_V3_UTILISATEURS_NOTIFICATIONS.sql`.
2. Créer le premier admin UNE SEULE FOIS dans SQL Editor en remplaçant le mot de passe :
   `select public.app_create_user('camille','Camille','TON-MOT-DE-PASSE','admin');`
3. Dans Supabase > Project Settings / API, copier **Project URL** et la **Publishable key** dans `config.js`.
4. Déployer ce dossier complet sur le projet Netlify existant.
5. Se connecter avec `camille` + le mot de passe choisi. Ensuite, le bouton **Utilisateurs** permet de créer les autres comptes.

Fonctions : nouveaux statuts, Dîner en ville, rédacteur/calibrage, dernière page affichée en premier, Word/photos, commentaires, @mentions, cloche et bip en direct.
