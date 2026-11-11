# Pagetopdf

Déposez un ou plusieurs documents Apple Pages sur l’icône de Pagetopdf dans le Dock. Pour chaque fichier, le PDF est enregistré dans le même dossier. Par exemple, `Séquence 3.v2.pages` devient `Séquence 3.v2.pdf`, quel que soit le réglage d’affichage des extensions du Finder. Si le nom est déjà pris, l’app essaie `Séquence 3.v2 (2).pdf`, puis les numéros suivants.

## Installation

1. Ouvrez le DMG et faites glisser **Pagetopdf** vers **Applications**.
2. Depuis le Finder, faites glisser **Pagetopdf** d’Applications vers la partie du Dock réservée aux applications.
3. Déposez un document `.pages` sur l’icône. Au premier export, macOS peut demander d’autoriser Pagetopdf à contrôler Pages. Un clic simple sur l’icône permet aussi de choisir les fichiers à convertir.

Le DMG contient une application universelle, compilée à partir de **macOS 10.14.4 Mojave sur Intel** et de **macOS 11 Big Sur sur Apple Silicon**. Apple Pages doit être installé dans une version que le Mac peut lancer et qui sait ouvrir le document. Sur un ancien macOS, utilisez une version de Pages compatible avec ce système. La disponibilité d’une ancienne version sur le Mac App Store dépend de ce qu’Apple propose pour votre compte et votre Mac. [Historique des versions de Pages](https://support.apple.com/fr-fr/guide/pages/tan700f60676/mac)

## Code et compilation

L’ancienne app était un workflow Automator qui demandait à Finder le dossier du fichier et ajoutait `.pdf` au nom affiché dans Pages. La nouvelle app utilise AppKit pour recevoir les fichiers et Foundation pour construire les chemins. Le script est compilé par le système à l’exécution et utilise la commande native d’export PDF de Pages. Pagetopdf reconnaît les identifiants de l’édition classique et de l’édition Creator Studio, y compris si l’app est renommée. Il donne la priorité à une édition déjà ouverte. L’app réutilise Pages pour la série, laisse ouverts les documents déjà ouverts par l’utilisateur et vérifie chaque PDF avant de le déplacer à sa destination. Aucun paquet tiers ni service réseau n’est utilisé par Pagetopdf.

Avec Xcode ou les outils en ligne de commande Apple sur un Mac :

```sh
./script/build_and_run.sh --build-only
```

Le résultat se trouve dans `dist/Pagetopdf.app`. Pour le lancer après compilation, exécutez le script sans option. L’icône est dans `Assets/Pagetopdf.icns`. Le fichier `Assets/MakeIcon.swift` permet de régénérer les PNG aux tailles du Dock, puis `iconutil -c icns` les assemble.

## Validation et distribution

- Les deux minimums sont inscrits dans les exécutables et dans la configuration de l’app. L’export est vérifié sous macOS 26.6.2 avec Pages 15.4 sur Apple Silicon. Les anciennes versions de macOS et de Pages restent à tester sur machine.
- Pour valider une nouvelle version de Pages ou de macOS, lancer Pagetopdf depuis le DMG installé, puis déposer dans le Dock deux documents dont l’un est déjà ouvert. Vérifier les noms et le contenu des PDF, la conservation du PDF existant et le maintien du document ouvert. Si Apple modifie son interface d’automatisation, adapter `Sources/Export.applescript` à la nouvelle définition de script.
- Le DMG de test contient une app signée ad hoc. Pour une distribution GitHub sans blocage standard de Gatekeeper, reconstruire avec `PAGETOPDF_SIGN_IDENTITY='Developer ID Application: …'`, recréer le DMG avec `./script/package_dmg.sh`, le soumettre avec `xcrun notarytool` et agrafer le ticket avec `xcrun stapler`. Tester ensuite le fichier téléchargé sur un autre Mac. [Documentation Apple sur la notarisation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
