#!/bin/bash

ONEPASSWORD_VAULT=$DOTENVOP_VAULT
ONEPASSWORD_ACCOUNT_SUBDOMAIN=$DOTENVOP_ACCOUNT
ONEPASSWORD_ACCOUNT_EMAIL=$DOTENVOP_EMAIL
ONEPASSWORD_ACCOUNT_URL="https://$ONEPASSWORD_ACCOUNT_SUBDOMAIN.1password.eu"

check_op() {
  if ! command -v op &> /dev/null; then
    echo "op could not be found, please install the 1Password CLI first"
    return 1
  fi
}

check_op_signin() {
  if op get account 2>&1 >/dev/null | grep -q ERROR; then
    eval "$(op signin "$ONEPASSWORD_ACCOUNT_SUBDOMAIN")"
    if op get account 2>&1 >/dev/null | grep -q ERROR; then
      printf "\nPlease run:\n\nop signin %s\n\n" "$ONEPASSWORD_ACCOUNT_URL $ONEPASSWORD_ACCOUNT_EMAIL"
      exit 1;
    fi
  fi
}

document_filename() {
  echo "[$PROJECT] $ENVIRONMENT"
}

dot_env_filename() {
  echo "[$PROJECT] .env.$ENVIRONMENT"
}

usage() {
  cat << EOT

  usage $0 [-h] get|create|edit -p project -e environment -v vault

  MANDATORY
    get                            : print 1Password file to stdout
    create [-f local_dot_env_path] : create a new 1Password entry with local_dot_env_path
    edit   [-f local_dot_env_path] : update the existing local_dot_env_path 1Password entry

  OPTIONS
    -h show this usage
    -p specify project
    -e specify environement (production/staging)
    -v specify vault (overrides ONEPASSWORD_VAULT)
    
EOT
}

handle_response() {
  readonly response=$1
  
  [[ "$response" != *ERROR* ]] && printf "\n\n%s\n\n" "$response" && exit 0

  if [[ "$response" == *"doesn't seem to be a vault in this account"* ]]; then
    printf "\nVault \"$VAULT\" does not exist. Available vaults are:\n\n%s\n" "$(op list vaults --cache | jq -r '.[].name')"
    exit 1
  fi

  echo "Unknown response: $response"
  exit 1
}

main() {
  check_op
  check_op_signin

  if [ -z "$ACTION" ] || [ -z "$PROJECT" ] || [ -z "$ENVIRONMENT" ]; then usage; exit 1; fi
  [[ -z "$VAULT" ]] && VAULT=$ONEPASSWORD_VAULT

  [[ -z "$DOCUMENT_NAME" ]] && DOCUMENT_NAME="$(dot_env_filename)"

  if [ "$ACTION" = get ]; then
    response=$(printf "%s\n\n" "$(op "$ACTION" document "$DOCUMENT_NAME" --vault "$VAULT" 2>&1)")
  elif [ "$ACTION" = create ]; then
    response=$(op "$ACTION" document "$LOCAL_DOT_ENV" --filename "$DOCUMENT_NAME" --vault "$VAULT" 2>&1)
  elif [ "$ACTION" = edit ]; then
    response=$(op "$ACTION" document "$DOCUMENT_NAME" "$LOCAL_DOT_ENV" --filename "$DOCUMENT_NAME" --vault "$VAULT" 2>&1)
  fi

  handle_response "$response"
}

ACTION=""
LOCAL_DOT_ENV=""
PROJECT=""
ENVIRONMENT=""
VAULT=""
DOCUMENT_NAME=""

[[ $# -eq 0 ]] && usage && exit 1

if [[ $1 == "get" ]] || [[ $1 == "create" ]] || [[ $1 == "edit" ]] ; then
  ACTION="$1"
  shift
else
  usage
  exit 1
fi

while getopts "hf:p:e:v:n:" opt; do
  case $opt in
    f) LOCAL_DOT_ENV="$OPTARG"
    ;;
    h) 
      usage
      exit 0
    ;;
    p) PROJECT="$(echo "$OPTARG" | tr "[:lower:]" "[:upper:]")"
    ;;
    e) ENVIRONMENT="$OPTARG"
    ;;
    v) VAULT="$OPTARG"
    ;;
    n) DOCUMENT_NAME="$OPTARG"
    ;;
    \?) 
      echo "Invalid option -$OPTARG" >&2
      usage
      exit 1
    ;;
  esac
done

shift $((OPTIND-1))

main


