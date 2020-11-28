# dotenv-op

![Lint](https://github.com/Kinoba/dotenv-op/workflows/Lint/badge.svg)

Small utility to help our team work with all our projects dotenv files.

## Requirements 

- A 1Password account
- 1Password CLI (https://support.1password.com/command-line-getting-started/)

## Getting started

### Homebrew

```
brew install kinoba/dotenv-op/dotenv-op
```

### Manually

- Change the following script variables according to your situation:

```
ONEPASSWORD_VAULT="[VAULT_NAME]"
ONEPASSWORD_ACCOUNT_SUBDOMAIN="[1P Account name]"
ONEPASSWORD_ACCOUNT_URL="https://$ONEPASSWORD_ACCOUNT_SUBDOMAIN.1password.eu"
ONEPASSWORD_ACCOUNT_EMAIL="[yourmeail@domaine.com]@$ONEPASSWORD_ACCOUNT_SUBDOMAIN.fr"
```

- Place this script wherever you want in your PATH

## Usage

### Get a dotenv

```
dotenv-op get -p project_name -e production
```

### Create a dotenv

```
./dotenv-op create -p project_name -e production -f /path/to/your/project_name/.env.production
```

### Edit a dotenv

```
./dotenv-op edit -p project_name -e production -f /path/to/your/project_name/.env.production
```

