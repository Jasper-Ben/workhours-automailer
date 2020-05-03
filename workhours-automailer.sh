#!/bin/bash


# Copyright 2020 Jasper Ben Orschulko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished
# to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


################################# SETTINGS ########################################

# extend with your own holidays
export HOLIDAYS=( )

# pre-entered dates are the legal holidays in Berlin for 2020
export LEGAL_HOLIDAYS=( "01.05.2020" "08.05.2020" "21.05.2020" "31.05.2020" "01.06.2020" "03.10.2020" "24.12.2020" "25.12.2020" "26.12.2020" "31.12.2020" )

# add sick dates
export SICK_DAYS=( )

# change workhours for single days (also works for weekends) syntax: 01.01.2020=6, where the last number is the hours worked (supports float, e.g. 5,5 or 5.5)
export DIVERGENT_DAYS=( )

################################# SCRIPT STARTS ###################################

set -e

command -v curl >/dev/null || { echo "Error: Please install curl" >&2; exit 1; }
locale -a | grep -q -E '^de_DE$' || { echo 'Error: Please make the de_DE locale available on your system (e.g. "sudo locale-gen de_DE").' >&2; exit 1; }

print_help(){
    echo "$0 [OPTIONS] -s '<URL>' -u '<ID>' -p '<PASSWORD>' -f '<EMAIL>' -t '<EMAIL>' -n '<FROM_NAME>'"
    echo "REQUIRED ARGUMENTS:"
    echo "  -t '<EMAIL>'                sets the E-Mail address of the receiver"
    echo "  -f '<EMAIL>'                sets the E-Mail address of the sender"
    echo "  -s '<URL>'                  sets the URL of the SMTP Server"
    echo "  -u '<ID>'                   set the SMTP login ID"
    echo "  -p '<PASSWORD>'             sets the SMTP login Password"
    echo "  -n '<FROM_NAME>'            sets the Signature Name of the Employee"
    echo "OPTIONAL ARGUMENTS:"
    echo "  -i                          allow for untrusted TLS certificates"
    echo "  -d                          dry run, overwrites receiver mail with sender mail for test-purposes"
    echo "  -c                          send a copy of the mail to the sender as BCC"
    echo "  -h                          prints this help"
}

validate_date(){
    echo "$1" | grep -q -E '^[0-9]{2}\.[0-9]{2}\.[0-9]{4}$' || return 1
}

iterate_holidays(){
    for holiday in "${HOLIDAYS[@]}"; do
        validate_date "$holiday" || { echo "Warning: Invalid date $holiday found in HOLIDAYS. Skipping..." >&2; continue; }
        [[ "$(date -d "last-monday +$day day" +%d.%m.%Y)" != "$holiday" ]] || (("$(date -d "last-monday +$day day" +%u)" > 5)) || return 1
    done
}

iterate_legal_holidays(){
    for legal_holiday in "${LEGAL_HOLIDAYS[@]}"; do
        validate_date "$legal_holiday" || { echo "Warning: Invalid date $legal_holiday found in LEGAL_HOLIDAYS. Skipping..." >&2; continue; }
        [[ "$(date -d "last-monday +$day day" +%d.%m.%Y)" != "$legal_holiday" ]] || (("$(date -d "last-monday +$day day" +%u)" > 5)) || return 1
    done
}

iterate_sickdays(){
    for sick in "${SICK_DAYS[@]}"; do
    validate_date "$sick" || { echo "Warning: Invalid date $sick found in SICK_DAYS. Skipping..." >&2; continue; }
        [[ "$(date -d "last-monday +$day day" +%d.%m.%Y)" != "$sick" ]] || return 1
    done
}

iterate_divdays() {
    for div in "${DIVERGENT_DAYS[@]}"; do
        validate_date "$(echo "$div" | sed -E 's/=.*//g')" || { echo "Warning: Invalid date in $div found in DIVERGENT_DAYS. Skipping..." >&2; continue; }
        echo "$div" | grep -q -E '=[0-9]+((,|\.)[0-9]+)?$' || { echo "Warning: Invalid hours in $div found in DIVERGENT_DAYS. Skipping..." >&2; continue; }
        [[ "$(date -d "last-monday +$day day" +%d.%m.%Y)" != "$(echo "$div" | sed -E 's/=.*//g')" ]] || echo "$div" | sed -E 's/.*=//g'
    done

}

# handle arguments
while getopts "s:u:p:t:f:n:idhc" arg; do
    case "$arg" in
        h)
            print_help
            exit 0
            ;;
        d)
            export DRY_RUN=1;;
        s)
            export SERVER="$OPTARG";;
        t)
            export TO="$OPTARG";;
        f)
            export FROM="$OPTARG";;
        u)
            export USER="$OPTARG";;
        p)
            export PASSWORD="$OPTARG";;
        i)
            export INSECURE="--insecure";;
        n)
            export FROM_NAME="$OPTARG";;
        c)
            export COPY=1;;
        *)
            echo "Error: Bad argument $arg" >&2
            echo "Usage:"
            print_help
            exit 1
            ;;
    esac
done

# make sure neccessary variables exist
vars=("TO" "FROM" "FROM_NAME" "SERVER" "USER" "PASSWORD")
for var in "${vars[@]}"; do
    [ -n "${!var}" ] || { echo "Error: Missing Argument $var" >&2; exit 1; }
done

# if the current day is younger than 17 hours, only list up to yesterday
export DAYS
if (("$(date +%H)" < "17")); then
    DAYS="(($(date +%u)-1))"
# list the whole week so far, including today
else
    DAYS="$(date +%u)"
fi
(( DAYS > 1 )) || { echo "Warning: No working hours to record yet. Aborting..." >&2; exit 0; }

# generating mail content
FILE_NAME="auto_mail_$(date +%Y%m%d_%H%M%S)"

cat >/tmp/"$FILE_NAME".html <<EOF
<h3>Arbeitszeiterfassung im Homeoffice für $FROM_NAME</h3>
<h4>Kalenderwoche $(date +%W)</h4>

<p>In der laufenden Woche waren meine (bisherigen) Arbeitszeiten im Homeoffice wie folgt:</p>

<table style="width:100%; border:1px solid black; border-collapse: collapse;">
    <tr style="background-color: black; color: white;">
        <th style="border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;">Datum</th>
        <th style="border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;">Arbeitszeit in Stunden</th>
        <th style="border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;">Pause in Minuten</th>
    </tr>
EOF

export day=0
while ((day<DAYS)); do
    hours="$(iterate_divdays)"
    [[ -z "$hours" ]] || { echo "<tr><th style=\"border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;\">$(LANG=de_DE date -d "last-monday +$day day" +"%A, %d.%m.%Y")</th><th style=\"border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;\">$hours</th><th style=\"border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;\">30</th></tr>" >> /tmp/"$FILE_NAME".html; export day=$((day+1)); continue; }

    iterate_holidays || { echo "<tr><th style=\"border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;\">$(LANG=de_DE date -d "last-monday +$day day" +"%A, %d.%m.%Y")</th><th style=\"border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;\">U</th><th style=\"border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;\">-</th></tr>" >> /tmp/"$FILE_NAME".html; export day=$((day+1)); continue; }

    iterate_legal_holidays || { echo "<tr><th style=\"border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;\">$(LANG=de_DE date -d "last-monday +$day day" +"%A, %d.%m.%Y")</th><th style=\"border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;\">-</th><th style=\"border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;\">-</th></tr>" >> /tmp/"$FILE_NAME".html; export day=$((day+1)); continue; }

    iterate_sickdays || { echo "<tr><th style=\"border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;\">$(LANG=de_DE date -d "last-monday +$day day" +"%A, %d.%m.%Y")</th><th style=\"border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;\">K</th><th style=\"border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;\">-</th></tr>" >> /tmp/"$FILE_NAME".html; export day=$((day+1)); continue; }

    (( day < 5 )) && echo "<tr><th style=\"border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;\">$(LANG=de_DE date -d "last-monday +$day day" +"%A, %d.%m.%Y")</th><th style=\"border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;\">8</th><th style=\"border: 1px solid black; border-collapse: collapse; padding: 15px; text-align: left;\">30</th></tr>" >> /tmp/"$FILE_NAME".html
    export day=$((day + 1))
done

cat >>/tmp/"$FILE_NAME".html <<EOF
</table>

<p>Ich bestätige hiermit, mich an die Vorgaben des <a href="http://www.gesetze-im-internet.de/arbzg/">Arbeitszeitgesetzes</a> gehalten zu haben.</p>
<br>
<p>$FROM_NAME</p>
EOF

# sending the mail
[[ "$DRY_RUN" = "1" ]] && export TO="$FROM"
[[ "$COPY" = "1" ]] && export COPY="--mail-rcpt $FROM"
curl -sS "$INSECURE" smtp://"$SERVER":587 --mail-from "$FROM" --mail-rcpt "$TO" "$COPY" --ssl -u "$USER":"$PASSWORD" -T <(echo -e "From: $FROM\nTo: $TO\nSubject: $FROM_NAME Arbeitszeit Home Office KW$(date +%W)\nContent-Type: text/html; charset="utf8"\n\n$(cat /tmp/"$FILE_NAME".html)") || { echo "Error: Could not send mail. Aborting..." >&2; exit 1; }
rm -f /tmp/"$FILE_NAME".html

exit 0
