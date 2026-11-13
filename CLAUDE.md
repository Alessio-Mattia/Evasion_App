# CLAUDE.md

Ce fichier guide Claude Code sur ce projet. Le cahier des charges complet est la référence produit : en cas de doute sur une règle métier, demander plutôt que deviner.

## Le projet

Application mobile (iOS + Android) qui sert à se rencontrer **dans la vraie vie** : croisements par proximité, posts géolocalisés éphémères, groupes qui deviennent des événements sur une carte, like et match débloqués par des rencontres réelles. Public : étudiants d'abord (un seul campus au lancement), puis tout le monde.

Principes non négociables :
- **Le réel débloque le virtuel** : le like n'est possible qu'après une rencontre réelle validée ; après un match, un quota de messages s'applique et une nouvelle rencontre réelle le recharge.
- **Tout le monde au même niveau** : aucun compteur public (abonnés, likes, vues), pas de like sur les posts (on les épingle).
- **Sécurité par défaut** : aucune position précise d'un utilisateur n'est exposée sans son choix explicite ; par défaut, tout est flou.

## Langue

- Répondre et expliquer en **français**.
- Code, noms de variables, commentaires, messages de commit : **anglais**.
- Textes visibles par l'utilisateur : en français, via les fichiers de traduction (`lib/l10n/`), jamais en dur dans les widgets.

## Stack

- Flutter (dernière version stable), Dart avec null safety
- État : **Riverpod** (avec `riverpod_generator`)
- Navigation : **go_router**
- Modèles : **freezed** + **json_serializable**
- Backend : **Supabase** (`supabase_flutter`) — PostgreSQL + PostGIS, Auth, Storage, Realtime, Edge Functions, pg_cron
- Notifications push : **Firebase Cloud Messaging** (uniquement pour le push)
- Tests : `flutter_test`, `mocktail`

N'ajouter aucune autre dépendance sans me la proposer d'abord avec une justification.

## Architecture

Organisation **feature-first**, trois couches par fonctionnalité :

```
lib/
├── main_dev.dart / main_prod.dart
├── app/          # thème, router, config d'environnement
├── core/         # services partagés (localisation, notifications), erreurs, widgets communs, utils
├── l10n/
└── features/
    └── <feature>/
        ├── data/          # repositories : seuls fichiers qui appellent Supabase
        ├── domain/        # modèles freezed, règles métier pures
        └── presentation/  # écrans, widgets, controllers Riverpod
```

Fonctionnalités : `auth`, `onboarding`, `profile`, `map`, `posts`, `groups`, `chat`, `encounters`, `connections` (amis, likes, matchs, rencontres réelles), `moderation`, `notifications`, `settings`.

Règles :
- **Les widgets n'appellent jamais Supabase directement.** Widget → controller (Riverpod) → repository → Supabase.
- Un repository = une classe abstraite dans `domain/` + une implémentation Supabase dans `data/` (testable avec des mocks).
- Une fonctionnalité n'importe pas les fichiers internes d'une autre ; ce qui est partagé va dans `core/`.
- Les erreurs remontent sous forme typée (classe `AppFailure` dans `core/`), jamais d'exception brute jusqu'à l'interface.
- Widgets petits et composables ; pas d'écran de plus de ~200 lignes.
- Thème sombre forcé ; couleurs et styles uniquement via le thème (`app/theme/`), jamais en dur.

## Backend Supabase

- Le schéma vit dans `supabase/migrations/` (Supabase CLI). **Toute modification de la base passe par une nouvelle migration**, jamais par le tableau de bord.
- **Row Level Security activée sur toutes les tables**, avec des politiques explicites. Chaque nouvelle table arrive avec ses politiques dans la même migration.
- Positions : type `geography(Point, 4326)` ; requêtes de distance avec `ST_DWithin`.
- Paires d'utilisateurs stockées avec `user_a < user_b`.
- La position exacte des utilisateurs (`user_locations`) et des posts (`posts.exact_geog`) n'est **jamais** lisible directement : les autres ne voient d'un post que sa position affichée (zone floue, ou point exact si l'auteur l'a choisi), via la vue `posts_public` et des fonctions RPC.
- Logique sensible côté serveur (fonctions SQL, triggers, Edge Functions) : détection des croisements, création des matchs, décompte des quotas de messages, expiration des posts. Le client ne doit jamais pouvoir contourner ces règles.
- Deux projets : `dev` et `prod`. Ne jamais exécuter de commande sur `prod` sans que je le demande explicitement.
- Les clés (URL, publishable key) viennent de `--dart-define-from-file` ; aucun secret dans le code ni dans Git. La `service_role` key n'est jamais utilisée dans l'application.

## Règles métier clés (valeurs à placer dans `core/config/business_rules.dart`)

- Croisement : les deux utilisateurs sont dans le rayon de détection l'un de l'autre ET correspondent aux critères mutuels (sexe, âge, distance). Historique affiché avec zone et heure arrondies.
- Modes de position : `invisible`, `foreground`, `background`.
- Rencontre réelle : validée par QR code scanné par les deux personnes (MVP). Débloque le like pendant une durée limitée.
- Like secret ; message rédigé au like, révélé seulement au match. Like retirable, match annulable.
- Quota de messages après match, rechargé par une nouvelle rencontre réelle.
- Post : image obligatoire. Lieu saisi à la main (limité à un rayon autour de la position réelle) ou, à défaut, position actuelle. Précision au choix : zone floue de quelques centaines de mètres (par défaut) ou exacte, avec un avertissement dans l'app. Public au choix : tout le monde, amis, ou une liste d'amis ; un post est toujours sur la carte pour son public. Durée choisie par l'auteur, bornée. Seuls le public et la durée sont modifiables ; le reste demande de supprimer et de reposter. L'expiration supprime le post ET l'image.
- Amis : ajout mutuel depuis le profil (les deux doivent s'ajouter), possible seulement après une rencontre réelle (QR code, ou bouton quand les deux sont à moins d'une certaine distance). Servent au public des posts, aux conversations privées et aux groupes. Ami et amour (like, match) sont deux notions séparées : le quota de messages ne s'applique qu'à l'amour, et un amour peut aussi être un ami.
- Groupe public = événement sur la carte, avec lieu, date/heure de début, fin optionnelle, catégorie, ouvert ou sur demande, max de participants.
- Blocage : l'utilisateur bloqué disparaît partout (carte, croisements, messagerie, profils).

Les seuils (durées, quotas, rayons) ne sont pas encore fixés : les centraliser comme constantes, jamais en dur ailleurs.

## Commandes

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build       # après modification d'un modèle freezed / provider
flutter analyze
flutter test
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json
flutter run --flavor prod -t lib/main_prod.dart --dart-define-from-file=env/prod.json
supabase start                    # Supabase local (nécessite Docker)
supabase migration new <nom>
supabase db reset                 # rejoue toutes les migrations en local
```

`flutter gen-l10n` et `build_runner` doivent être lancés après un clone ou un pull : le code généré n'est pas versionné.

## Façon de travailler

- Pour toute fonctionnalité non triviale : **proposer d'abord un plan** (fichiers créés/modifiés, migration SQL, tests) et attendre ma validation.
- Avancer par petites étapes : une fonctionnalité ou une couche à la fois.
- Après chaque modification : `flutter analyze` sans avertissement, et `flutter test` qui passe.
- Écrire des tests unitaires pour les règles métier (`domain/`) et les controllers ; tester les politiques RLS en SQL quand elles sont non triviales.
- Expliquer brièvement les choix techniques : nous apprenons en même temps.
- Ne jamais modifier ce fichier ni le cahier des charges sans me le demander.
- Ne pas faire de commit ni de push sans que je le demande.

## Ancien projet

L'ancienne application (FlutterFlow + Firebase) peut servir de référence pour la logique métier uniquement. Ne rien copier tel quel : réécrire selon l'architecture ci-dessus.
