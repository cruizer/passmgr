#!/bin/bash
PASSMGRDATAFILE=/tmp/pwfile.gpg
# Sanitized user search pattern
PASSMGRUSERPTN=
# Base pattern for record matching
PASSMGRBEGINPTN='\*\*\*[\w\d.\-,?!_\047" ]*?'
# the user provided pattern will be inserted between these two
PASSMGRENDPTN='[\w\d.\-,?!_\047" ]*\*\*\*(.|\n)*?---ENDOFENTRY---'
# end of entry pattern only matching until end of title line.
PASSMGRENDTITLEPTN='[\w\d.\-,?!_\047" ]*\*\*\*'
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
# 7 check_pwfile called with illegal arg
# 8 save_encrypted called with illegal arg
# 9 call_vim called with illegal mode arg

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
# Modes:
# - exit if not found: check_pwfile hard
# - if found, return 0, otherwise 1: check_pwfile soft
check_pwfile()
{
  if [[ -f  $PASSMGRDATAFILE ]]; then
    echo "Password data file found."
    return 0
  else
    if [[ "$1" = "hard" ]]; then
      echo "ERROR 3 No password data file is found. EXITING."
      exit 3
    elif [[ "$1" = "soft" ]]; then
      return 1
    else
      echo "check_pwfile: Called with illegal argument."
      exit 7
    fi
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
# Find entry that has a title that matches exactly.
find_exact_match()
{
  # RE matching the title of an entry.
  local REGEX="\*\*\*$1\*\*\*"
  local DATA=$2
  if [[ $DATA =~ $REGEX ]]; then
    echo "Matched: ""$BASH_REMATCH"
    return 1
  else
    # If no exact match is found we show the similar entries.
    echo "No exact match found."
    echo "Similar entries are:"
    echo "$DATA" | pcregrep -i "$PASSMGRBEGINPTN$1$PASSMGRENDTITLEPTN"
    return 0
  fi
}

ask_yes_no()
{
  echo $1" (y/n)"
  local userconfirm=x
  while [[ "$userconfirm" != "y" && "$userconfirm" != "n" ]]; do
    read userconfirm
    if [[ "$userconfirm" = "y" ]]; then
      return 1
    elif [[ "$userconfirm" = "n" ]]; then
      return 0
    else
      echo "You response is invalid. Please respond (y)es or (n)o."
    fi
  done
}
# call_vim <mode>
call_vim()
{
  local mode=$1
  if [[ "$mode" = "append" || "$mode" = "replace" ]]; then
    # Location of the passmgr script
    local scriptlocation="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/passmgr.sh"
    vim - -n --cmd \
    "let g:PassMgrSaveMode = '$mode' | let g:PassMgrScriptLocation = '$scriptlocation'" -i "NONE"
  else
    echo "ERROR 9: call_vim mode arg should be *append* or *replace*."
    exit 9
  fi
  
}
# TASKS

# Add password entry to encrypted pw store.
add_pass()
{
  echo "Specify password entry name:"
  read passmgrentryname
  echo -e $"***$passmgrentryname***\nlogin:\npassword:\nNOTES:\n---ENDOFENTRY---" \
  | call_vim "append"
}
# Remove entry from encrypted pw store.
rm_pass()
{
  local PASSMGRDATA=`$PASSMGRGPGCMD -d < $PASSMGRDATAFILE`
  # re matching the full entry (required for removal)
  local REGEXFULL="\*\*\*$1\*\*\*(.|\n)*?---ENDOFENTRY---"
  find_exact_match $1 $PASSMGRDATA
  # If find_exact_match found a match 
  if [[ $? -eq 1 ]]; then
    ask_yes_no "Do you want to remove this entry?"
    if [[ $? -eq 1 ]]; then
      echo "$PASSMGRDATA" | pcregrep -v -M "$REGEXFULL" \
      | $PASSMGRGPGCMD -c --cipher-algo AES256 -o /tmp/pwfile.gpg
    else
      echo "Remove aborted."
      exit 0
    fi
  fi  
}
# Read matching pw records
read_pass()
{
  check_pwfile "hard"
  # Replace single quotes with octet notation and store it in PASSMGRUSERPTN
  sanitize_pattern $1
  # Allowed characters in entry name: word characters, digits, punctuation, quotation. 
  $PASSMGRGPGCMD -d  < $PASSMGRDATAFILE | pcregrep -i -M \
  "$PASSMGRBEGINPTN$PASSMGRUSERPTN$PASSMGRENDPTN"
}
edit_pass()
{
  local PASSMGRDATA=`$PASSMGRGPGCMD -d < $PASSMGRDATAFILE`
  # re matching the full entry
  local REGEXFULL="\*\*\*$1\*\*\*(.|\n)*?---ENDOFENTRY---"
  find_exact_match $1 $PASSMGRDATA
  if [[ $? -eq 1 ]]; then
    ask_yes_no "Do you want to edit this entry?"
    if [[ $? -eq 1 ]]; then
      echo "$PASSMGRDATA" | pcregrep -M "$REGEXFULL" | call_vim "replace"
    else
      echo "Edit aborted."
      exit 0
    fi
  fi
  # 3 If there is an exact match, open it in vi
  # 4 Edit in vim
  # 5 Save entry and insert in place of the original.
}
# Encrypt password data received from vi session and merge with existing data if required.
# Modes:
# - append entry to existing data: save_encrypted append
# - replace existing entry with edited data: save_encrypted replace
# BEWARE: Any output echoed to stdout will be concealed if and when
# gpg is run. We need to look into how to go around this later.
save_encrypted()
{
  # If there is already a password file existing
  if check_pwfile "soft";then
    local REGEX="\*\*\*([^*]+)\*\*\*"
    local REGEXFULL="\*\*\*$1\*\*\*(.|\n)*?---ENDOFENTRY---"
    local PASSMGRCURRENT=$(cat -)
    local SAVEMODE=$1
    # We decrypt the exisiting data 
    local PASSMGRARCHIVE=$($PASSMGRGPGCMD -d /tmp/pwfile.gpg)
    # If decryption failed; eg. passphrase was not OK
    if [[ "$?" -ne 0 ]]; then
      echo "Decryption of archive password file failed. Verify passphrase."
      exit 5
    else
      if [[ "$SAVEMODE" = "append" ]]; then
        # Concat existing data with the new and encrypt
        echo -e "$PASSMGRARCHIVE\n$PASSMGRCURRENT" | \
        $PASSMGRGPGCMD -c --cipher-algo AES256 -o /tmp/pwfile.gpg
      elif [[ "$SAVEMODE" = "replace" ]]; then
        # echo -e "$PASSMGRARCHIVE" | sed 's//'
        if [[ $PASSMGRCURRENT =~ $REGEX ]]; then
          echo "${BASH_REMATCH[1]}"
        fi
      else
        echo "ERROR 8 save_encrypted: Unknown parameter."
        exit 8
      fi
    fi
  else
    # Encrypt current data only
    cat - | $PASSMGRGPGCMD -c --cipher-algo AES256 -o /tmp/pwfile.gpg
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
    check_parnum $# 2
    edit_pass $2
    ;;
  --saveEnc)
    check_parnum $# 2
    save_encrypted $2
    ;;
  *)
    echo "Invalid command."
    usage
    exit 2
    ;;
esac


