# ============================================================
# Lab 2 - TechNova : déploiement Active Directory en PowerShell
# À exécuter en administrateur, partie par partie
# (le serveur redémarre après les parties 1 et 2)
# ============================================================

# --- Variables (à adapter à son environnement) ---
$Interface  = "Ethernet0"
$IP         = "192.168.1.80"
$Passerelle = "192.168.1.1"
$NomServeur = "SRV-AD"
$Domaine    = "technova.local"
$NetBIOS    = "TECHNOVA"
$OU         = "OU=Comptabilite,DC=technova,DC=local"

# --- PARTIE 1 : IP fixe + renommage (redémarrage) ---
New-NetIPAddress -InterfaceAlias $Interface -IPAddress $IP -PrefixLength 24 -DefaultGateway $Passerelle
Set-DnsClientServerAddress -InterfaceAlias $Interface -ServerAddresses $Passerelle
Rename-Computer -NewName $NomServeur -Restart

# --- PARTIE 2 : rôle AD DS + création de la forêt (redémarrage) ---
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Install-ADDSForest -DomainName $Domaine -DomainNetbiosName $NetBIOS -InstallDns

# --- PARTIE 3 : structure TechNova + AGDLP ---
# Après promotion : le DC devient son propre DNS
Set-DnsClientServerAddress -InterfaceAlias $Interface -ServerAddresses $IP

# Unité d'organisation
New-ADOrganizationalUnit -Name "Comptabilite" -Path "DC=technova,DC=local"

# A : comptes utilisateurs (mot de passe saisi masqué, jamais en clair)
$mdp = Read-Host "Mot de passe initial" -AsSecureString
New-ADUser -Name "Alice Martin" -SamAccountName "amartin" -Path $OU -AccountPassword $mdp -Enabled $true
New-ADUser -Name "Bruno Petit"  -SamAccountName "bpetit"  -Path $OU -AccountPassword $mdp -Enabled $true

# G : groupe global (par métier)
New-ADGroup -Name "GG_Compta" -GroupScope Global -GroupCategory Security -Path $OU
# DL : groupe domaine local (par ressource)
New-ADGroup -Name "GDL_Partage_Compta_RW" -GroupScope DomainLocal -GroupCategory Security -Path $OU

# Imbrication A -> G -> DL
Add-ADGroupMember -Identity "GG_Compta" -Members amartin, bpetit
Add-ADGroupMember -Identity "GDL_Partage_Compta_RW" -Members "GG_Compta"

# P : permissions (partage SMB + NTFS) attribuées au groupe DL uniquement
New-Item -Path "C:\Partages\Compta" -ItemType Directory
New-SmbShare -Name "Compta" -Path "C:\Partages\Compta" -FullAccess "$NetBIOS\GDL_Partage_Compta_RW"
icacls "C:\Partages\Compta" /grant "$NetBIOS\GDL_Partage_Compta_RW:(OI)(CI)M"

# --- PARTIE 4 : nouvel arrivant (démonstration AGDLP) ---
# Une seule action : l'ajouter au groupe global. Aucun droit à modifier.
New-ADUser -Name "Chloe Bernard" -SamAccountName "cbernard" -Path $OU -AccountPassword $mdp -Enabled $true
Add-ADGroupMember -Identity "GG_Compta" -Members cbernard

# --- PARTIE 5 : stratégies de groupe liées à l'OU Comptabilite ---
# GPO 1 : lecteur P: -> \\SRV-AD\Compta
# Créée et liée ici ; le mappage de lecteur se configure dans la console GPMC
# (Configuration utilisateur > Préférences > Paramètres Windows > Mappages de lecteurs),
# car les Préférences de GPO n'ont pas de commande PowerShell native.
New-GPO -Name "GPO_Compta_LecteurP" | New-GPLink -Target $OU

# GPO 2 : interdire le Panneau de configuration (clé de registre utilisateur)
New-GPO -Name "GPO_Compta_NoPanneau" | New-GPLink -Target $OU
Set-GPRegistryValue -Name "GPO_Compta_NoPanneau" -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "NoControlPanel" -Type DWord -Value 1
