# Création des tableaux
$UpdateStatus = @()
$SummaryStatus = @()
$ServersPerUpdate = @()

# Connexion au serveur WSUS
[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null
$WSUS = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer()

# Récupération de la dernière synchro du WSUS
$LastSync = ($wsus.GetSubscription()).LastSynchronizationTime

# Create a default update scope object
$UpdateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
# Modify the update scope ApprovedStates value from "Any" to "LatesRevisionApproved".
$UpdateScope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::LatestRevisionApproved
# Create a computerscope object for use as an a requred part of a method below.
$ComputerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope

# Récupération des données pour les clients avec un ID groupe spécifique
$ComputerTargetGroups = $WSUS.GetComputerTargetGroups() `
| Where { $_.id -eq '[REMPLACER AVEC VOTRE ID' }
# Récupération de tous les objets type "ordinateurs" et membres du groupe "Serveurs"
$MemberOfGroup = $wsus.getComputerTargetGroup($ComputerTargetGroups.Id).GetComputerTargets()

Try {
	# Suppression de l'ancien fichier
	Remove-Item -Path "[REPERTOIRE]\WSUSUpdate.txt"
}
Catch {
	echo "`t[!!]Impossible de supprimer le fichier WSUSUpdate.txt"
}

# Création du nouveau fichier
New-Item -Path "[REPERTOIRE]\WSUSUpdate.txt" -ItemType file -Force

# Récupération des données à partir du WSUS
Foreach ($Object in $wsus.GetSummariesPerComputerTarget($updatescope, $computerscope)) {
	
	foreach ($object1 in $MemberOfGroup) {

		If ($object.computertargetid -match $object1.id) {
			# Initialisation de la cible avec le nom du serveur
			$ComputerTargetToUpdate = $wsus.GetComputerTargetByName($object1.FullDomainName)
			
			#Filtrage des updates selon leur statut
			$NeededUpdate = $ComputerTargetToUpdate.GetUpdateInstallationInfoPerUpdate() `
			| where {
				($_.UpdateApprovalAction -eq "install") -and `
				(($_.UpdateInstallationState -eq "downloaded") -or `
				($_.UpdateInstallationState -eq "notinstalled"))
			}
			
			$FailedUpdateReport = $null
			$NeededUpdateReport = $null
			
			# Récupération des noms de serveurs, numéro de KB, nom de l'update...
			if ($NeededUpdate -ne $null) {
				foreach ($Update in $NeededUpdate) {
					$myObject2 = New-Object -TypeName PSObject
					$myObject2 | add-member -type Noteproperty -Name Server -Value (($object1 | select -ExpandProperty FullDomainName) -replace ".FQDN", "")
					$myObject2 | add-member -type Noteproperty -Name Update -Value ('<a href' + '=' + '"' + ($wsus.GetUpdate([Guid]$update.updateid).AdditionalInformationUrls) + '"' + '>' + (($wsus.GetUpdate([Guid]$update.updateid)).title) + '<' + '/' + 'a' + '>')
					$myObject2 | add-member -type Noteproperty -Name Update2 -Value ((($wsus.GetUpdate([Guid]$update.updateid)).title))
					
					$UpdateStatus += $myObject2
					
					$KBNumber = (($wsus.GetUpdate([Guid]$update.updateid)).KnowledgebaseArticles)
				}
			}
			
			# Création d'un nouvel objet pour remplissage des données dans un tableau
			$myObject1 = New-Object -TypeName PSObject
			
			$myObject1 | add-member -type Noteproperty -Name Server -Value (($object1 | select -ExpandProperty FullDomainName) -replace ".FQDN", "")
			$myObject1 | add-member -type Noteproperty -Name UnkownCount -Value $object.UnknownCount
			$myObject1 | add-member -type Noteproperty -Name NotInstalledCount -Value $object.NotInstalledCount
			$myObject1 | add-member -type Noteproperty -Name NotApplicable -Value $object.NotApplicableCount
			$myObject1 | add-member -type Noteproperty -Name DownloadedCount -Value $object.DownloadedCount
			$myObject1 | add-member -type Noteproperty -Name InstalledCount -Value $object.InstalledCount
			$myObject1 | add-member -type Noteproperty -Name InstalledPendingRebootCount -Value $object.InstalledPendingRebootCount
			$myObject1 | add-member -type Noteproperty -Name FailedCount -Value $object.FailedCount
			$myObject1 | add-member -type Noteproperty -Name ComputerTargetId -Value $object.ComputerTargetId
			$myObject1 | add-member -type Noteproperty -Name NeededCount -Value ($NeededUpdate | measure).count
			$myObject1 | add-member -type Noteproperty -Name Failed -Value $FailedUpdateReport
			$myObject1 | add-member -type Noteproperty -Name Needed -Value $NeededUpdateReport
			$myObject1 | add-member -type Noteproperty -Name KBNumber -Value $KBNumber -Force
			
			# Remplissage du tableau
			$SummaryStatus += $myObject1
			
			# Récupération des valeurs du tableau
			$ServerName = $myObject1.server
			$ServerName = $ServerName.Split('.')[0]
			$ServerName = $ServerName.ToUpper()
			$NeededCount = $myObject1.NeededCount
			$NotInstalled = $myObject1.NotInstalledCount
			$NeedReboot = $myObject1.InstalledPendingRebootCount
			$KBNumber = $myObject1.KBNumber
			$UpdateName = $myObject2.Update2
			
			#Collecte des infos sur les KB
			$WSUSUpdate = Get-PSWSUSUpdate | Select * | Where {$_.KnowledgebaseArticles -eq $KBNumber}
			
			foreach ($GetWSUSUpdateInfo in $WSUSUpdate) {
			
				$NumeroMS = $GetWSUSUpdateInfo.SecurityBulletins
			}
			
			if ([string]::IsNullOrWhiteSpace($NumeroMS)) {
				$NumeroMS = "N/A"
			}
			
			# Ecriture des données dans le fichier
			Try {
				"$ServerName;$NeededCount;$NotInstalled;$NeedReboot;KB$KBNumber;$NumeroMS;$UpdateName" | add-content -Path "[REPERTOIRE]\WSUSUpdate.txt"
			}
			Catch {
				echo "`t[!!]Impossible d'écrire dans le fichier WSUSUpdate.txt"
			}
		}
	}
}
