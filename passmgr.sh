#!/bin/sh
PASSMGRDATAFILE=/tmp/pwfile.gpg
# This will be a named pipe, that we use with read to block GPG from running twice in some cases.
export PASSMGRLOCKPIPE=/tmp/passmgr.LOCK
PASSMGRTEMPFILE=
# 0=unset, 1=addpass to existing file
PASSMGRMODEFLAG=0
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

# Print script usage information
usage()
{
  echo "Usage: passmgr addpass OR passmgr readpass|rmpass <name>"
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
      echo "$PASSMGRARCHIVE$PASSMGRCURRENT" | gpg -c --cipher-algo AES256 -o /tmp/pwfile.gpg
    fi
  else
    # Encrypt current data only
    cat - | gpg -c --cipher-algo AES256 -o /tmp/pwfile.gpg
  fi
}

# "Main"
if [[ "$#" -ne 2 && ( "$#" -ne 1 || "$1" -ne "addpass" ) ]]; then
  echo "Illegal number of parameters."
  usage
  exit 1
fi
# In case no lock pipe is created we create one.
if [[ ! -p  $PASSMGRLOCKPIPE ]]; then
    mkfifo $PASSMGRLOCKPIPE
fi
# Set GPG_TTY env variable if not set or empty 
: ${GPG_TTY:=`tty`}
# Dispatcher
case "$1" in
  addpass)
    add_pass
    ;;
  rmpass)
    echo "Not implemented."
    ;;
  readpass)
    read_pass $2
    ;;
  editpass)
    echo "Not implemented."
    ;;
  --saveEnc)
    cat - | save_encrypted
    ;;
  *)
    echo "Invalid command."
    usage
    exit 2
    ;;
esac


