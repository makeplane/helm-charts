

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

function openFile() {
    local file_path="${1:-.}"
    
    # Function to check process ancestry for editor names
    check_parent_process() {
        local pid=$1
        local count=0
        while [ $count -lt 10 ]; do  # Check up to 10 levels up
            local parent_cmd=$(ps -p $pid -o comm=)
            if echo "$parent_cmd" | grep -qi "cursor"; then
                echo "cursor"
                return 0
            elif echo "$parent_cmd" | grep -qi "windsurf"; then
                echo "windsurf"
                return 0
            elif echo "$parent_cmd" | grep -qi "code"; then
                echo "code"
                return 0
            fi
            
            # Get parent PID
            pid=$(ps -p $pid -o ppid=)
            if [ $pid -le 1 ]; then
                break
            fi
            ((count++))
        done
        echo "unknown"
    }

    # Get the editor from process tree
    local current_editor=$(check_parent_process $$)
    
    case "$current_editor" in
        "cursor")
            cursor "$file_path"
            ;;
        "windsurf")
            windsurf "$file_path"
            ;;
        "code")
            code "$file_path"
            ;;
        *)
            # Fallback to checking installed editors
            if command -v cursor &> /dev/null; then
                cursor "$file_path"
            elif command -v windsurf &> /dev/null; then
                windsurf "$file_path"
            elif command -v code &> /dev/null; then
                code "$file_path"
            else
                echo "No compatible text editor found. Please install VS Code, Windsurf, or Cursor."
                return 1
            fi
            ;;
    esac
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
        openFile test-ce.yaml
    else
        printFailed
    fi
elif [ "$HELM_CHART" == "2" ]; then
    helm template plane-enterprise-app-$(date +%s) charts/plane-enterprise -n myns > test-enterprise.yaml
    if [ $? -eq 0 ]; then
        clear
        printSuccess
        openFile test-enterprise.yaml
    else
        printFailed
    fi
else
    exit 0
fi
