# ELITE : brancher l'interface admin (10 minutes, gratuit)

Le site reste statique (Vercel/GitHub). Les messages sont stockés dans Supabase.

1. Créez un projet sur https://supabase.com (gratuit).
2. **SQL Editor** : collez le contenu de `supabase.sql`, puis *Run*.
3. **Authentication > Users > Add user** : créez le compte admin (e-mail + mot de passe).
4. **Authentication > Sign In / Providers** : désactivez *Allow new users to sign up* (sinon n'importe qui pourrait créer un compte).
5. **Project Settings > API** : copiez *Project URL* et la clé *anon public*.
6. Collez-les dans `index.html` ET `admin.html` (constantes `SUPABASE_URL` et `SUPABASE_ANON_KEY`, en haut du script).
7. Poussez sur GitHub : Vercel redéploie. Dossier `images/` à envoyer aussi.

Utilisation : `https://votre-site/admin.html` -> connexion -> messages, adhésions, témoignages.
Un témoignage n'apparaît sur le site qu'après avoir cliqué sur *Publier sur le site*.
La clé anon est publique par conception : la sécurité repose sur les règles (RLS) du fichier SQL.
