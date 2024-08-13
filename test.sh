

function printSuccess {
cat <<"EOF"
 ____                              
/ ___| _   _  ___ ___ ___  ___ ___ 
\___ \| | | |/ __/ __/ _ \/ __/ __|
 ___) | |_| | (_| (_|  __/\__ \__ \
|____/ \__,_|\___\___\___||___/___/

EOF
}
function printFailed {
cat <<"EOF"
 _____     _ _          _ 
|  ___|_ _(_) | ___  __| |
| |_ / _` | | |/ _ \/ _` |
|  _| (_| | | |  __/ (_| |
|_|  \__,_|_|_|\___|\__,_|

EOF
}


HELM_CHART=$(dialog \
    --backtitle "Helm Chart Testing"  \
    --title "Select Chart"  \
    --cancel-label "Exit" \
    --menu "Select the Helm Chart to test" 25 50 20 \
    "1" "Plane-CE" \
    "2" "Plane-Enterprise" \
    3>&1 1>&2 2>&3)


if [ "$HELM_CHART" == "1" ]; then
    helm template plane-ce-app-$(date +%s) charts/plane-ce -n myns > test-ce.yaml
    if [ $? -eq 0 ]; then
        clear
        printSuccess
    else
        printFailed
    fi
elif [ "$HELM_CHART" == "2" ]; then
    helm template plane-enterprise-app-$(date +%s) charts/plane-enterprise -n myns > test-enterprise.yaml
    if [ $? -eq 0 ]; then
        clear
        printSuccess
        code test-enterprise.yaml
    else
        printFailed
    fi
else
    exit 0
fi
