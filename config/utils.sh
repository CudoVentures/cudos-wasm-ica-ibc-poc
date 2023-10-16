function sed_in_place() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i "" "$@"
    else
        sed -i "$@"
    fi
}

function loading() {
    local message="$1"
    local total_seconds="$2"
    echo -ne "\033[32m$message\033[0m"
    for (( i=0; i<total_seconds; i++ )); do
        echo -n "."
        sleep 1
    done
    echo ""
}

function info() {
    local message="$1"
    echo -ne "\033[34m$message\033[0m"
    echo ""
    sleep $AVG_BLOCK_TIME
}

function error() {
    local message="$1"
    echo -ne "\033[31m$message\033[0m"
    echo ""
}

export -f sed_in_place
export -f loading
export -f info
export -f error
