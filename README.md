# 🏢 Lab — Déploiement Active Directory en PowerShell (AGDLP)

## 📋 Contexte

L'entreprise fictive **TechNova** crée son service Comptabilité. Il faut un domaine Active Directory, des comptes, et un dossier partagé accessible **uniquement** à la compta.

**Mission :** déployer le domaine et toute la structure **en PowerShell**, appliquer la méthode **AGDLP**, puis **prouver** par des tests que les bons utilisateurs ont accès, et que les autres sont refusés.

## 🖥️ Environnement

| Élément | Détail |
|---|---|
| Hyperviseur | VMware Workstation (réseau Bridged) |
| Contrôleur de domaine | Windows Server 2022 — `SRV-AD`, domaine `technova.local` |
| Poste client | Windows 10 Entreprise — `PC-COMPTA01`, joint au domaine |
| Outils | PowerShell, module ActiveDirectory, SMB, icacls |

## 🔐 AGDLP appliqué

```
Alice ─┐
       ├─► GG_Compta ─► GDL_Partage_Compta_RW ─► Partage \\SRV-AD\Compta
Bruno ─┘                                          (SMB : Full / NTFS : Modify)
  A          G                  DL                         P
```

| Lettre | Rôle | Objet créé |
|---|---|---|
| **A** | Comptes utilisateurs | `amartin`, `bpetit` |
| **G** | Groupe **global** : regroupe les personnes par métier | `GG_Compta` |
| **DL** | Groupe **domaine local** : porte les droits sur une ressource | `GDL_Partage_Compta_RW` |
| **P** | Permissions attribuées **au groupe DL uniquement** | Partage SMB + NTFS Modify |

**Intérêt :** un nouvel arrivant en compta est simplement ajouté à `GG_Compta`. Aucune permission à modifier sur le partage.

## ⚙️ Le script

[`technova_ad.ps1`](technova_ad.ps1) : configuration IP, promotion du contrôleur de domaine, création de l'OU, des comptes, des groupes, imbrication AGDLP, partage et droits NTFS.
Mots de passe saisis de façon masquée (`Read-Host -AsSecureString`), jamais écrits en clair.

## ✅ Tests réalisés

### 1. Accès autorisé
Connexion sur le poste client en `TECHNOVA\amartin` (membre de `GG_Compta`) → création d'un fichier sur `\\SRV-AD\Compta` : **réussie**.

### 2. Accès refusé (contre-test)
Création de `cdurand`, rangé **dans l'OU Comptabilité** mais **hors du groupe** `GG_Compta` → **accès refusé**.
➡️ Démontre que **l'OU ne donne aucun droit** : l'accès dépend de l'**appartenance aux groupes**. L'OU sert à organiser et à appliquer des GPO.

## 🔧 Incidents rencontrés et résolus

### Jonction du poste client au domaine
| Symptôme | Cause | Résolution |
|---|---|---|
| Client en `192.168.50.x` | Carte VMware en NAT, pas sur le réseau du DC | Passage en Bridged |
| "Média déconnecté" | Carte virtuelle non connectée | Option *Connected* cochée |
| `technova.local` introuvable | Le client utilisait le DNS IPv6 de la box | DNS pointé vers le DC, IPv6 désactivé sur le client du lab |

➡️ Diagnostic du bas vers le haut : couche physique, puis IP, puis DNS. Résolution DNS comparée en interrogeant directement le DC (`Resolve-DnsName -Server`).

### Accès refusé malgré une configuration correcte
Après un arrêt brutal du serveur, le groupe `GDL_Partage_Compta_RW` avait **disparu**. Les droits du partage et du NTFS pointaient vers un **SID orphelin** (`S-1-5-21-...-1106`).
➡️ Les permissions sont liées au **SID** de l'objet, pas à son nom : un groupe recréé avec le même nom obtient un **nouveau SID** et doit recevoir à nouveau ses droits.
➡️ Diagnostic maillon par maillon de la chaîne AGDLP, puis recréation du groupe et réattribution des droits.

## 🔜 Améliorations prévues
- Rendre le script **idempotent** (vérifier l'existence d'un objet avant de le créer)
- Créer les utilisateurs depuis un fichier **CSV**
- Nettoyer automatiquement les SID orphelins
- Ajouter une **GPO** liée à l'OU Comptabilité (lecteur réseau mappé)

## 🎯 Ce que ce lab démontre
- **Automatisation :** déployer un domaine Active Directory complet en PowerShell, de façon reproductible.
- **Gestion des accès :** appliquer AGDLP et comprendre la différence entre OU et groupe.
- **Méthode :** tester les cas autorisé **et** refusé, diagnostiquer des pannes réelles (réseau, DNS, SID orphelin) et documenter leur résolution.
