#!/bin/sh

# Setze PATH-Variable
PATH=/usr/local/bin:/usr/bin:/bin

# Definiere Variablen
BACKUP_DIR=/var/lib/docker/backups
SOURCEFOLDER=/var/lib/docker/volumes
BACKUPTIME=$(date +%Y-%m-%d_%H-%M-%S)
DESTINATION=$BACKUP_DIR/$BACKUPTIME.tar.gz
LOGFILE=$BACKUP_DIR/backup.log
REMOTE_BACKUP_DIR=/home/USER/backups
REMOTE_SERVER=USER@SERVERIP

# Funktion zum Schreiben in die Logdatei und Konsole
log() {
    echo "$1" | tee -a $LOGFILE
}

# Erstelle oder leere die Logdatei
echo "Backup-Log für $BACKUPTIME" > $LOGFILE

# Starte Logging
log "Starte Docker-Backup-Prozess..."

# Stoppe alle laufenden Docker-Container
log "Stoppe alle laufenden Docker-Container..."
docker stop $(docker ps -q) > /dev/null 2>&1
log "Docker-Container gestoppt."

# Erstelle das Zielverzeichnis, falls es nicht existiert
log "Erstelle Zielverzeichnis für Backup, falls erforderlich..."
mkdir -p $BACKUP_DIR

# Erstelle ein tar.gz-Archiv des Docker-Volumes
log "Erstelle Backup-Archiv von Docker-Volumes..."
(cd $SOURCEFOLDER && tar -cpzf $DESTINATION .)
log "Backup-Archiv erstellt: $DESTINATION"

# Starte alle Docker-Container wieder
log "Starte alle Docker-Container neu..."
docker start $(docker ps -a -q) > /dev/null 2>&1
log "Docker-Container neu gestartet."

# Lösche Backups, die älter als 7 Tage sind
log "Lösche Backups, die älter als 7 Tage sind..."
find $BACKUP_DIR -mtime +7 -type f -delete
log "Alte Backups gelöscht."

# Kopiere das Backup zu Strato Server
log "Übertrage Backup zu Strato Server..."
scp $DESTINATION $REMOTE_SERVER:$REMOTE_BACKUP_DIR
log "Backup auf Strato Server übertragen."

# Überprüfe die Integrität des Backups mittels Hash
log "Überprüfe die Integrität des Backups..."
# Berechne den Hash der lokalen Backup-Datei
LOCAL_HASH=$(sha256sum $DESTINATION | awk '{print $1}')

# Berechne den Hash der entfernten Backup-Datei
REMOTE_HASH=$(ssh $REMOTE_SERVER "sha256sum $REMOTE_BACKUP_DIR/$BACKUPTIME.tar.gz" | awk '{print $1}')

# Vergleiche die beiden Hashes
if [ "$LOCAL_HASH" = "$REMOTE_HASH" ]; then
    log "Backup erfolgreich übertragen und verifiziert."

    # Lösche Backups auf dem Strato Server, die älter als 14 Tage sind
    log "Lösche Backups auf Strato Server, die älter als 14 Tage sind..."
    ssh $REMOTE_SERVER "find $REMOTE_BACKUP_DIR -mtime +14 -type f -delete"
    log "Alte Backups auf Strato Server gelöscht."
else
    log "Fehler: Backup-Überprüfung fehlgeschlagen!"
fi
