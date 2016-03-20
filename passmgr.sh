#!/bin/sh
PASSMGRDATAFILE=/tmp/pwfile.gpg
# This will be a named pipe, that we use with read to block GPG from running twice in some cases.
export PASSMGRLOCKPIPE=/tmp/passmgr.LOCK
PASSMGRTEMPFILE=
# Sanitized user search pattern
PASSMGRUSERPTN=
# Base pattern for record matching
PASSMGRBEGINPTN='\*\*\*[\w\d.\-,?!_\047" ]*?'
# the user provided pattern will be inserted between these two
PASSMGRENDPTN='[\w\d.\-,?!_\047" ]*\*\*\*(.|\n)*?---ENDOFENTRY---'
# An entry would look like the following in the password database file
# ***<entryname>***
# login: <login>
# password: <password>
# NOTES: <any note>
# ---ENDOFENTRY---

# Error codes:
# 1 Illegal number of parameters.
# 2 Invalid command.
# 3 No passsword data file.
# 4 User entry contains invalid characters.
# 5 Archive decryption failed.
# 6 GPG command not detected.

# Print script usage information
usage()
{
  echo "Usage: passmgr addpass OR passmgr readpass|rmpass <name>"
}
# Check if GPG is present and which version (1|2)
determine_gpg_cmd()
{
  if command -v gpg >/dev/null 2>&1 ; then
    PASSMGRGPGCMD=gpg
  elif command -v gpg2 >/dev/null 2>&1 ; then
    PASSMGRGPGCMD=gpg2
  else
    echo "ERROR 6 Unable to find GPG. Check if GPG is installed and it is in your PATH."
    exit 6
  fi
}
# Check if the encyrpted file is already present
check_pwfile()
{
  if [[ -f  $PASSMGRDATAFILE ]]; then
    echo "Password data file found."
  else
    echo "No password data file is found. EXITING."
    exit 3
  fi
}
# Replacing single/double quotes with octal representation
sanitize_pattern()
{
  # ' -> \047  ,   " -> \042
  PASSMGRUSERPTN=$(echo $1 | sed "s/'/\\\047/g" | sed "s/\"/\\\042/g")
}
verify_user_input()
{
  if [[ $passmgrentryname =~ "^[a-zA-Z0-9 .!?:;\-,\047\042]+$" ]]; then
    echo "Entry name OK."
  else
    echo "Entry name not OK. You can only use word character, digits, punctuation and quotation."
    exit 4
  fi
}

# TASKS

# Add password entry to encrypted pw store
add_pass()
{
  # If the password file exists already, we need
  # to add the entry to that. (This flag is checked in the vim custom command.)
  if [[ -f  $PASSMGRDATAFILE ]]; then
    export PASSMGRMODEFLAG=1
  else
    export PASSMGRMODEFLAG=0
  fi 
  echo "Specify password entry name:"
  read passmgrentryname
  echo -e $"***$passmgrentryname***\nlogin:\npassword:\nNOTES:\n---ENDOFENTRY---" | vim - -n  -i "NONE" 
}
rm_pass()
{
  #gpg -d < $PASSMGRDATAFILE | pcregrep -i -M "$PASSMGRBEGINPTN$PASSMGRUSERPTN$PASSMGRENDPTN"
  local PASSMGRDATA=`gpg -d < $PASSMGRDATAFILE`
  # echo "$PASSMGRDATA"
  # 1 check if there is unique match (strict)
  # 2 if there is, remove entry
  # 3 if match is not unique OR there is no match, list similar entries
  local REGEX="\*\*\*""$1""\*\*\*"
  if [[ $PASSMGRDATA =~ $REGEX ]]; then
    echo "Match."
  fi
}
# Read matching pw records
read_pass()
{
  check_pwfile
  # Replace single quotes with octet notation and store it in PASSMGRUSERPTN
  sanitize_pattern $1
  # Allowed characters in entry name: word characters, digits, punctuation, quotation. 
  gpg -d  < $PASSMGRDATAFILE | pcregrep -i -M "$PASSMGRBEGINPTN$PASSMGRUSERPTN$PASSMGRENDPTN"
}
# Encrypt password data received from vi session and merge with existing data if required.
save_encrypted()
{
  # If there is already a password file existing
  if [[ $PASSMGRMODEFLAG -eq 1 ]];then
    PASSMGRCURRENT=$(cat -)
    # We decrypt the exisiting data 
    PASSMGRARCHIVE=$(gpg -d /tmp/pwfile.gpg)
    # If decryption failed; eg. passphrase was not OK
    if [[ "$?" -ne 0 ]]; then
      echo "Decryption of archive password file failed. Verify passphrase."
      exit 5
    else
      # Concat existing data with the new and encrypt
      echo -e "$PASSMGRARCHIVE\n$PASSMGRCURRENT" | gpg -c --cipher-algo AES256 -o /tmp/pwfile.gpg
    fi
  else
    # Encrypt current data only
    cat - | gpg -c --cipher-algo AES256 -o /tmp/pwfile.gpg
  fi
}
# Verify that number of params is correct
# $1 number of params received
# $2 allowed number of params
check_parnum()
{
  if [[ "$1" -ne "$2" ]]; then
  echo "Illegal number of parameters."
  usage
  exit 1
fi
}
# "Main"
determine_gpg_cmd
# Set GPG_TTY env variable if not set or empty 
: ${GPG_TTY:=`tty`}
# Dispatcher
case "$1" in
  addpass)
    check_parnum $# 1
    add_pass 
    ;;
  rmpass)
    check_parnum $# 2
    rm_pass $2
    ;;
  readpass)
    check_parnum $# 2
    read_pass $2
    ;;
  editpass)
    echo "Not implemented."
    ;;
  --saveEnc)
    check_parnum $# 1
    cat - | save_encrypted
    ;;
  *)
    echo "Invalid command."
    usage
    exit 2
    ;;
esac


