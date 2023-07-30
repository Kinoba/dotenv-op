#!/bin/bash

ONEPASSWORD_VAULT=$DOTENVOP_VAULT
ONEPASSWORD_ACCOUNT_SUBDOMAIN=$DOTENVOP_ACCOUNT
ONEPASSWORD_ACCOUNT_EMAIL=$DOTENVOP_EMAIL
ONEPASSWORD_ACCOUNT_URL="https://$ONEPASSWORD_ACCOUNT_SUBDOMAIN.1password.eu"

check_op() {
  # Check if CLI is installed
  if ! command -v op &> /dev/null; then
    echo "op could not be found, please install the 1Password CLI first"
    exit 1
  fi

  # Check if CLI version is greater or equal to 2
  op_version=$(op -v)
  [[ "${op_version:0:1}" -lt 2 ]] && echo "Install or update op CLI version > 2" && exit 1
}

check_op_signin() {
  session=$(cat "$HOME/.config/op/session" 2> /dev/null)
  if ! op account get --session="$session" &> /dev/null; then
    echo ""
    signin
    session=$(cat "$HOME/.config/op/session")
    if ! op account get --session="$session" &> /dev/null; then
      printf "\nPlease run:\n\nop signin --account %s\n\n" "$ONEPASSWORD_ACCOUNT_URL $ONEPASSWORD_ACCOUNT_EMAIL"
      exit 1;
    fi
  fi
}

signin() {
  token=$(op signin -f --raw --account "$ONEPASSWORD_ACCOUNT_SUBDOMAIN")

  echo "$token" > "$HOME/.config/op/session"
}

dot_env_filename() {
  echo "[$PROJECT] .env.$ENVIRONMENT"
}

download_document_to_temp_location() {
  tmpFile=$(mktemp) || exit 1
  trap 'rm -f "$tmpFile"' EXIT

  # Download the document to a temporary location
  op document get "$DOCUMENT_NAME" \
    --vault "$VAULT" \
    --output "$tmpFile" \
     --session="$session"

  # Check if the document exists locally and has a size greater than 0
  ! [[ -s "$tmpFile" ]] && echo "Remote document could not be downloaded locally" && exit 1
}

usage() {
  cat << EOT

  usage $0 ACTION OPTIONS

  ACTION (MANDATORY)
    compare      : compare local document to the one in 1Password
    create       : create a new 1Password entry with local document
    edit         : update the existing document in 1Password based on local document
    edit-inline  : update a document directly in the terminal
    get          : print 1Password file to stdout
    help         : print this menu
    version      : print dotenv-op version

  OPTIONS
    -e specify environement (production/staging)
    -f specify local document path
    -h show this usage
    -p specify project
    -n [OPTIONAL] specify name of the document 
    -v [OPTIONAL] specify vault (overrides ONEPASSWORD_VAULT)
    
EOT
}

handle_response() {
  readonly response=$1
  
  [[ "$ACTION" = edit ]] || [[ "$ACTION" = edit-inline ]] && printf "\n%s successfully edited" "$DOCUMENT_NAME"
  ! [[ "$response" =~ .*\[ERROR\].* ]] && printf "\n\n%s\n\n" "$response" && exit 0

  if [[ "$response" == *"isn't a vault in this account"* ]]; then
    printf "\nVault \"$VAULT\" does not exist. Available vaults are:\n\n%s\n" "$(op vault list --format json --session="$session" | jq -r '.[].name')"
    exit 1
  fi

  echo "Unknown response: $response"
  exit 1
}

main() {
  if [[ "$ACTION" = version ]]; then
    echo "dotenv-op v1.1.1"
    exit 0
  fi

  check_op
  check_op_signin

  if [ -z "$ACTION" ] || [ -z "$PROJECT" ] || [ -z "$ENVIRONMENT" ]; then usage; exit 1; fi
  [[ -z "$VAULT" ]] && VAULT=$ONEPASSWORD_VAULT

  [[ -z "$DOCUMENT_NAME" ]] && DOCUMENT_NAME="$(dot_env_filename)"

  if [[ "$ACTION" = get ]]; then
    response=$(printf "%s\n\n" "$(op document "$ACTION" "$DOCUMENT_NAME" --vault "$VAULT" --session="$session" 2>&1)")
  elif [[ "$ACTION" = create ]]; then
    response=$(op document "$ACTION" "$LOCAL_DOT_ENV" --file-name "$DOCUMENT_NAME.txt" --title "$DOCUMENT_NAME" --vault "$VAULT" --session="$session" 2>&1)
  elif [[ "$ACTION" = edit ]]; then
    response=$(op document "$ACTION" "$DOCUMENT_NAME" "$LOCAL_DOT_ENV" --file-name "$DOCUMENT_NAME.txt" --title "$DOCUMENT_NAME" --vault "$VAULT" --session="$session" 2>&1)
  elif [[ "$ACTION" = edit-inline ]]; then
    download_document_to_temp_location
    ${VISUAL:-${EDITOR:-vim}} "$tmpFile"

    while true; do
      printf "\nPress\n - Y to upload the edited document\n - V to view the edited document\n - E to continue editing\n - C to cancel\n\n"
      read -rp ": " subaction
      case $subaction in
        [Yy]* ) response=$(op document edit "$DOCUMENT_NAME" "$tmpFile" --file-name "$DOCUMENT_NAME.txt" --title "$DOCUMENT_NAME" --vault "$VAULT" --session="$session" 2>&1); break;;
        [Vv]* ) cat "$tmpFile";;
        [Ee]* ) ${VISUAL:-${EDITOR:-vim}} "$tmpFile";;
        [Cc]* ) break;;
        * ) echo "";;
      esac
    done
  elif [[ "$ACTION" = compare ]]; then
    download_document_to_temp_location
    ! [[ -s "$LOCAL_DOT_ENV" ]] && printf "Local document %s not found\n" "$LOCAL_DOT_ENV" && exit 1

    # Remove new lines and white spaces before comparing the two files
    if cmp --silent <( tr -d ' \n' <"$LOCAL_DOT_ENV" ) <( tr -d ' \n' <"$tmpFile" ); then
      response="Documents are identical"
    else
      response="Documents are different"
    fi
  fi

  # Early exit if the user canceled the main action
  [[ "$subaction" == c ]] && exit 0

  handle_response "$response"
}

ACTION=""
LOCAL_DOT_ENV=""
PROJECT=""
ENVIRONMENT=""
VAULT=""
DOCUMENT_NAME=""

[[ $# -eq 0 ]] && usage && exit 1

if [[ $1 == get ]] || [[ $1 == create ]] || [[ $1 == edit ]] || [[ $1 == edit-inline ]] || [[ $1 == compare ]] || [[ $1 == version ]] ; then
  ACTION="$1"
  shift
else
  usage
  exit 1
fi

while getopts "hf:p:e:v:n:" opt; do
  case $opt in
    e) ENVIRONMENT="$OPTARG"
    ;;
    f) LOCAL_DOT_ENV="$OPTARG"
    ;;
    h) 
      usage
      exit 0
    ;;
    n) DOCUMENT_NAME="$OPTARG"
    ;;
    p) PROJECT="$(echo "$OPTARG" | tr "[:lower:]" "[:upper:]")"
    ;;
    v) VAULT="$OPTARG"
    ;;
    \?) 
      echo "Invalid option -$OPTARG" >&2
      usage
      exit 1
    ;;
  esac
done

# Remove all options specified in the while getopts loop
shift "$((OPTIND-1))"

main


