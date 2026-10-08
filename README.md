# 🏢 Lab — Déploiement Active Directory en PowerShell (AGDLP + GPO)

## 📋 Contexte

L'entreprise fictive **TechNova** crée son service Comptabilité. Il faut un domaine Active Directory, des comptes, un dossier partagé accessible **uniquement** à la compta, et des stratégies de groupe pour les postes du service.

**Mission :** déployer le domaine et la structure **en PowerShell**, appliquer la méthode **AGDLP**, configurer des **GPO**, puis **prouver** par des tests que chaque mécanisme fonctionne.

## 🖥️ Environnement

| Élément | Détail |
|---|---|
| Hyperviseur | VMware Workstation (réseau Bridged) |
| Contrôleur de domaine | Windows Server 2022 — `SRV-AD`, domaine `technova.local` |
| Poste client | Windows 10 Entreprise — `PC-COMPTA01`, joint au domaine |
| Outils | PowerShell, module ActiveDirectory, GroupPolicy, SMB, icacls, GPMC |

## 🔐 AGDLP appliqué

```
Alice ─┐
Bruno ─┼─► GG_Compta ─► GDL_Partage_Compta_RW ─► Partage \\SRV-AD\Compta
Chloé ─┘                                          (SMB : Full / NTFS : Modify)
  A          G                  DL                         P
```

| Lettre | Rôle | Objet créé |
|---|---|---|
| **A** | Comptes utilisateurs | `amartin`, `bpetit`, `cbernard` |
| **G** | Groupe **global** : regroupe les personnes par métier | `GG_Compta` |
| **DL** | Groupe **domaine local** : porte les droits sur une ressource | `GDL_Partage_Compta_RW` |
| **P** | Permissions attribuées **au groupe DL uniquement** | Partage SMB + NTFS Modify |

## 📜 Stratégies de groupe (liées à l'OU Comptabilite)

| GPO | Méthode | Effet |
|---|---|---|
| `GPO_Compta_LecteurP` | Console GPMC (Préférences) | Lecteur `P:` mappé vers `\\SRV-AD\Compta` |
| `GPO_Compta_NoPanneau` | PowerShell (`Set-GPRegistryValue`) | Panneau de configuration interdit |

Les deux sont des réglages de **Configuration utilisateur** : ils suivent la personne, quel que soit le poste.

## ⚙️ Le script

[`technova_ad.ps1`](technova_ad.ps1) : configuration IP, promotion du contrôleur de domaine, OU, comptes, groupes, imbrication AGDLP, partage, droits NTFS, nouvel arrivant et GPO.
Mots de passe saisis de façon masquée (`Read-Host -AsSecureString`), jamais écrits en clair.

## ✅ Tests réalisés

| Utilisateur | Dans l'OU Compta | Dans GG_Compta | Lecteur P: | Accès au partage | Panneau de config |
|---|---|---|---|---|---|
| Alice | ✅ | ✅ | ✅ | ✅ | 🚫 bloqué |
| Chloé (nouvelle arrivée) | ✅ | ✅ | ✅ | ✅ | 🚫 bloqué |
| Charles (contre-test) | ✅ | ❌ | ✅ | ❌ refusé | 🚫 bloqué |
| Administrateur | ❌ | ❌ | ❌ | — | ✅ non concerné |

**Ce que démontre ce tableau :**
- **Nouvel arrivant :** Chloé a obtenu l'accès en étant **seulement ajoutée à `GG_Compta`**. Aucune permission modifiée.
- **Les GPO suivent l'OU :** Charles, rangé dans l'OU, reçoit le lecteur P: et la restriction.
- **Les droits suivent les groupes :** Charles, absent de `GG_Compta`, voit le lecteur mais **ne peut pas l'ouvrir**.
- ➡️ **OU et groupes sont deux mécanismes indépendants** : l'OU organise et porte les GPO, le groupe donne
