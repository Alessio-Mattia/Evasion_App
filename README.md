<div align="center">

# Evasion

**L'application pour se rencontrer dans la vraie vie.**

Croisements par proximité, posts géolocalisés éphémères, groupes qui deviennent des événements sur une carte,
et un like qui ne se débloque qu'après une vraie rencontre.

[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Postgres%20%2B%20PostGIS-3FCF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Plateformes](https://img.shields.io/badge/plateformes-iOS%20%7C%20Android-lightgrey)](#prérequis)
[![Licence](https://img.shields.io/badge/licence-tous%20droits%20r%C3%A9serv%C3%A9s-red)](LICENSE)

</div>

> **Statut : en développement.** L'application n'est pas encore disponible sur l'App Store ni sur le Google Play Store.
> Le lancement est prévu d'abord sur un seul campus, puis pour tout le monde.
>
> Ce dépôt est public pour présenter l'application et notre travail. Le code reste notre propriété : il peut être consulté, mais pas réutilisé (voir [Licence](#licence)).

---

## Sommaire

- [Le concept](#le-concept)
- [Fonctionnalités](#fonctionnalités)
- [Stack technique](#stack-technique)
- [Architecture](#architecture)
- [Sécurité et vie privée](#sécurité-et-vie-privée)
- [Démarrer](#démarrer)
- [Tests](#tests)
- [Base de données](#base-de-données)
- [Façon de travailler](#façon-de-travailler)
- [Auteurs](#auteurs)
- [Licence](#licence)

---

## Le concept

La plupart des applications de rencontre gardent les gens derrière leur écran. Evasion fait l'inverse : **le réel débloque le virtuel**.

Trois principes guident toutes les décisions :

| Principe | En pratique |
|---|---|
| **Le réel débloque le virtuel** | On ne peut liker quelqu'un qu'après une rencontre réelle, validée par un QR code scanné par les deux personnes. Après un match, un quota de messages s'applique, et une nouvelle rencontre le recharge. |
| **Tout le monde au même niveau** | Aucun compteur public : pas d'abonnés, pas de likes, pas de vues. Les posts ne se likent pas, ils s'épinglent. |
| **Sécurité par défaut** | Aucune position précise n'est exposée sans le choix explicite de la personne. Par défaut, tout est flou. |

---

## Fonctionnalités

| Fonctionnalité | Description | État |
|---|---|---|
| Connexion | Par code à usage unique envoyé par e-mail, sans mot de passe | ✅ Fait |
| Création du profil | Prénom, date de naissance, genre et photo, étape par étape | ✅ Fait |
| Badge étudiant | Accordé automatiquement si l'adresse e-mail confirmée appartient à une université reconnue | ✅ Fait |
| Profil en carrousel | Une page principale, puis jusqu'à 5 pages libres (texte, photo, centres d'intérêt) à ajouter, modifier et réordonner | ✅ Fait |
| Modification du profil | Textes, photo, et une seule correction de la date de naissance | ✅ Fait |
| Réglages | Mode de position (invisible, au premier plan, en arrière-plan), rayon de détection, critères de croisement | ✅ Fait |
| Blocage | Une personne bloquée disparaît partout : carte, croisements, messagerie, profils | ✅ Côté serveur |
| Suppression du compte | Supprime le compte, les données et les photos, après confirmation par un code récent | ✅ Fait |
| Posts | Photo obligatoire, lieu flou par défaut, public au choix (tout le monde, amis, liste d'amis), durée limitée | 🚧 En cours |
| Carte | Posts et événements autour de soi | 📋 Prévu |
| Croisements | Détection des personnes croisées selon des critères mutuels ; historique avec zone et heure arrondies | 📋 Prévu |
| Rencontres réelles | Validation par QR code, qui débloque le like pendant une durée limitée | 📋 Prévu |
| Amis | Ajout mutuel après une rencontre réelle | 📋 Prévu |
| Likes et matchs | Like secret avec un message révélé seulement au match | 📋 Prévu |
| Messagerie | Conversations privées et de groupe | 📋 Prévu |
| Groupes et événements | Un groupe public devient un événement sur la carte | 📋 Prévu |
| Notifications push | Via Firebase Cloud Messaging | 📋 Prévu |
| Modération | Signalements et outils d'administration | 📋 Prévu |

---

## Stack technique

| Couche | Technologie |
|---|---|
| Application | [Flutter](https://flutter.dev) (stable), Dart avec null safety |
| État | [Riverpod](https://riverpod.dev) avec `riverpod_generator` |
| Navigation | [go_router](https://pub.dev/packages/go_router) |
| Modèles | [freezed](https://pub.dev/packages/freezed) et `json_serializable` |
| Backend | [Supabase](https://supabase.com) : PostgreSQL et PostGIS, Auth, Storage, Realtime, Edge Functions, pg_cron |
| Notifications push | Firebase Cloud Messaging (prévu, uniquement pour le push) |
| Tests | `flutter_test`, `mocktail`, et [pgTAP](https://pgtap.org) pour la base de données |
| Langue | Français, via les fichiers de traduction de `lib/l10n/` |

---

## Architecture

### Application

Le code est organisé **par fonctionnalité**, chacune découpée en trois couches :

```
lib/
├── main_dev.dart / main_prod.dart   # points d'entrée, un par environnement
├── app/                             # thème, router, configuration
├── core/                            # code partagé : erreurs, stockage, validation, widgets communs
├── l10n/                            # textes de l'application (app_fr.arb)
└── features/
    └── <fonctionnalité>/
        ├── data/                    # repositories : les seuls fichiers qui appellent Supabase
        ├── domain/                  # modèles et règles métier, sans dépendance à Supabase
        └── presentation/            # écrans, widgets et controllers Riverpod
```

Fonctionnalités : `auth`, `onboarding`, `profile`, `map`, `posts`, `groups`, `chat`, `encounters`, `connections`, `moderation`, `notifications`, `settings`.

Quelques règles :

- **Un widget n'appelle jamais Supabase.** Le chemin est toujours : widget → controller → repository → Supabase.
- **Chaque repository est une interface** dans `domain/`, avec son implémentation Supabase dans `data/`. Les tests remplacent l'implémentation par une fausse.
- **Les erreurs remontent typées** (`AppFailure`), jamais sous forme d'exception brute jusqu'à l'écran.
- **Une fonctionnalité n'importe pas les fichiers internes d'une autre.** Ce qui est partagé va dans `core/`.
- **Tous les seuils** (durées, quotas, rayons, longueurs) sont regroupés dans [`lib/core/config/business_rules.dart`](lib/core/config/business_rules.dart). Ceux qui protègent les données sont aussi imposés par la base.

### Serveur

```
supabase/
├── migrations/       # le schéma complet, une migration par changement
├── tests/database/   # tests pgTAP : politiques d'accès, contraintes, triggers
├── functions/        # Edge Functions (par exemple delete-account)
├── templates/        # e-mails d'authentification
└── config.toml       # configuration de la pile locale
```

Toutes les règles sensibles sont appliquées **côté serveur** : contraintes, triggers, fonctions SQL et Edge Functions. L'application ne peut pas les contourner, même modifiée.

---

## Sécurité et vie privée

- **Row Level Security sur toutes les tables**, avec des politiques explicites et testées.
- **Les positions précises ne sont jamais lisibles directement.** Les autres utilisateurs ne voient qu'une position affichée, floue par défaut, à travers des vues et des fonctions dédiées.
- **Le blocage est vérifié par la base** dans chaque requête qui montre un utilisateur à un autre. Une personne bloquée ne sait pas qui l'a bloquée.
- **Photos privées** : chaque bucket de stockage est privé. Une photo n'est lisible que par ceux qui ont le droit de voir le profil ou le post concerné, par des liens temporaires.
- **Aucun secret dans le dépôt.** L'application n'utilise que l'URL du projet et sa clé publique (publishable key). La clé `service_role` n'est jamais utilisée dans l'application.

Vous avez trouvé une faille ? Merci de **ne pas ouvrir d'issue publique** : utilisez le [signalement privé de vulnérabilité](https://github.com/Alessio-Mattia/Evasion_App/security/advisories/new) de GitHub.

---

## Démarrer

Ces instructions servent aux deux auteurs pour leur environnement de développement. Elles montrent aussi comment le projet est outillé.

### Prérequis

- [Flutter](https://docs.flutter.dev/get-started/install) (canal stable, Dart 3.13 ou plus récent)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/), pour la pile Supabase locale
- [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) 3.x
- Pour Android : Android Studio et un émulateur ou un téléphone
- Pour iOS : un Mac avec Xcode ; iOS 15 minimum

### 1. Récupérer le projet

```bash
git clone https://github.com/Alessio-Mattia/Evasion_App.git
cd Evasion_App
```

### 2. Générer le code

Le code généré (traductions, modèles, providers) n'est pas versionné. À relancer après chaque clone ou pull :

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build -d
```

### 3. Lancer Supabase en local

Avec Docker démarré :

```bash
supabase start      # démarre la pile locale et affiche l'URL et la publishable key
supabase db reset   # applique toutes les migrations sur une base vide
```

> `supabase start` réutilise la base existante. Après un pull qui ajoute des migrations, relancez `supabase db reset`. Attention, cela efface les comptes de test locaux.

Les e-mails de connexion (codes) n'arrivent pas dans une vraie boîte : ils sont visibles dans Mailpit, sur http://127.0.0.1:54324.

### 4. Configurer l'environnement

Les clés sont passées à l'application au lancement, à partir d'un fichier JSON qui n'est jamais versionné. Copiez le modèle :

```bash
cp env/example.json env/local.json
```

Puis renseignez-y la publishable key affichée par `supabase start`, et l'URL de l'API selon l'appareil :

| Appareil | `SUPABASE_URL` |
|---|---|
| Simulateur iOS | `http://127.0.0.1:54321` |
| Émulateur Android | `http://10.0.2.2:54321` |

Sur un téléphone réel, utilisez plutôt un projet Supabase hébergé : créez de la même façon `env/dev.json` ou `env/prod.json` avec l'URL `https://<ref>.supabase.co` et la publishable key du projet.

### 5. Lancer l'application

L'option `--flavor` est obligatoire : sans elle, la compilation échoue.

```bash
# Avec la pile locale
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/local.json

# Avec un projet hébergé
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json
flutter run --flavor prod -t lib/main_prod.dart --dart-define-from-file=env/prod.json
```

Les flavors `dev` et `prod` installent deux applications distinctes sur le même appareil.

---

## Tests

```bash
flutter analyze     # doit finir sans aucun avertissement
flutter test        # tests unitaires et de widgets
supabase test db    # tests pgTAP de la base (pile locale démarrée)
```

- **Règles métier et controllers** : testés en Dart, avec des repositories remplacés par des faux (`mocktail`).
- **Politiques d'accès, contraintes et triggers** : testés en SQL avec pgTAP, en se connectant comme différents utilisateurs.

---

## Base de données

**Le schéma n'est modifié que par des migrations**, jamais depuis le tableau de bord Supabase.

```bash
supabase migration new <nom_de_la_migration>   # crée un fichier vide dans supabase/migrations/
supabase db reset                              # rejoue toutes les migrations en local
supabase test db                               # vérifie que les tests passent toujours
```

Chaque nouvelle table arrive avec ses politiques Row Level Security et ses tests, dans la même migration.

Les migrations ne sont appliquées sur les projets hébergés (`dev`, puis `prod`) qu'après leur fusion dans `main`.

---

## Façon de travailler

- **`main` est la branche de référence.** Chaque changement part d'une branche (`feat/…`, `fix/…`, `docs/…`) et revient dans `main` par une pull request.
- **Chaque pull request est relue** par l'autre développeur avant d'être fusionnée, avec `flutter analyze`, `flutter test` et `supabase test db` au vert.
- **Code, commentaires et messages de commit en anglais**. Textes de l'application, discussions et revues en français.
- Les idées et les tâches à venir sont suivies dans un tableau GitHub Projects.

### Contributions

Evasion est développé uniquement par ses deux auteurs : **les contributions extérieures ne sont pas acceptées**, et les pull requests ouvertes par d'autres personnes seront fermées sans être fusionnées.

---

## Auteurs

Evasion est développé par deux frères :

| | Rôle | GitHub |
|---|---|---|
| **Sirio Mattia** | Serveur et base de données : schéma, sécurité, Edge Functions | [@Sirio-Mattia](https://github.com/Sirio-Mattia) |
| **Alessio Mattia** | Application : écrans, navigation, expérience utilisateur | [@Alessio-Mattia](https://github.com/Alessio-Mattia) |

---

## Licence

© 2026 Alessio Mattia et Sirio Mattia. **Tous droits réservés.**

Ce dépôt est public uniquement pour être consulté. Aucune licence n'est accordée : sans notre autorisation écrite, il est interdit d'utiliser, de copier, de modifier, de distribuer ou de réutiliser tout ou partie du code, du schéma de base de données ou de la documentation. Voir le fichier [LICENSE](LICENSE).

Les bibliothèques externes utilisées par le projet ne font pas partie de ce dépôt et restent sous leur propre licence.
