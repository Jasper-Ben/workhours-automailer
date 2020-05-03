# workhours-automailer
##### Ein Service zum Automatisieren von Arbeitszeit Benachrichtigung.

## Hintergrund
Um sich rechtlich abzusichern hat mein Arbeitgeber in Covid-19 Zeiten eine neue Policy eingeführt, welche besagt dass die Arbeitszeiten im Homeoffice wöchentlich per E-Mail an den Vorgesetzten gemeldet werden müssen. Um diesen bürokratischen Mehraufwand (zusätzlich zu bereits vorhandenem Timetracking) zu vermeiden, habe ich den Vorgang mit diesem Script so gut es geht automatisiert.


## Verwendung
```
./workhours-automailer.sh [OPTIONS] -s '<URL>' -u '<ID>' -p '<PASSWORD>' -f '<EMAIL>' -t '<EMAIL>' -n '<FROM_NAME>'
REQUIRED ARGUMENTS:
  -t '<EMAIL>'                sets the E-Mail address of the receiver
  -f '<EMAIL>'                sets the E-Mail address of the sender
  -s '<URL>'                  sets the URL of the SMTP Server
  -u '<ID>'                   set the SMTP login ID
  -p '<PASSWORD>'             sets the SMTP login Password
  -n '<FROM_NAME>'            sets the Signature Name of the Employee
OPTIONAL ARGUMENTS:
  -i                          allow for untrusted TLS certificates
  -d                          dry run, overwrites receiver mail with sender mail for test-purposes
  -c                          send a copy of the mail to the sender as BCC
  -h                          prints this help
```

Beim Ausführen des Programmes eine Table generiert und an die definierte Empfängeradresse gesendet. Diese Tabelle beinhaltet standardmäßig die vertraglich/gesetzlich vorgeschriebenen 8 Arbeitsstunden und 30 Pausenminuten für jeden bisherigen Tag der Arbeitswoche (inklusive des aktuellen Tages falls bereits nach 17:00 Uhr). Durch Arbeitszeitverlagerung entstehende Abweichungen in den Arbeitszeiten (funktioniert auch für Wochenendarbeit), Urlaubs- und Krankheitstage können in den vordefinierten Arrays am Anfang des
Skriptes eingetragen werden. Optimalerweise bietet es sich daher in der Regel an, das Script über einen systemd timer / cronjob an einem Freitag Abend laufen zu lassen.


## Reife des Scripts
Ich gebe keine Garantien für die Vollständigkeit oder korrekte Funktion des Scriptes (siehe MIT Lizenz), es wurden allerdings bereits einige Szenarien simuliert, ohne dass Fehlverhalten auffällig geworden wäre. 
