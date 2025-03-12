#!/usr/bin/env bash

usage () {

  echo ""
  echo "  Unregister Azure resource providers"
  echo "  ------------------------------------------------------------"
  echo ""
  echo "  USAGE: ./unregister-azure-providers.sh <providers-file>"
  echo ""
  echo "    Unregisters Azure resource providers that are defined in a"
  echo "    text file."
  echo ""
  echo "    Example:"
  echo ""
  echo "    aio-azure-resource-providers.txt"
  echo "    ------------------------------"
  echo "    Microsoft.ApiManagement"
  echo "    Microsoft.Web"
  echo "    Microsoft.DocumentDB"
  echo "    Microsoft.OperationalInsights"
  echo ""
  echo "    ./unregister-azure-providers.sh aio-azure-resource-providers.txt"
  echo ""
  echo "  USAGE: ./unregister-azure-providers.sh --help"
  echo ""
  echo "    Prints this help."
  echo ""
}

str_len () {
  str=$1

  echo ${#str}
}

# Prints the provider name followed by a number of dots to the terminal screen. The 
# \033[0K CSI sequence clears any prior content at the location and then prints the 
# provider name and dots. This is to allow for in-place refreshes of the registration 
# state on the terminal screen.
#
# https://en.wikipedia.org/wiki/ANSI_escape_code#Control_Sequence_Introducer_commands
# \033[nK - Erases part of the line. If n is 0 (or missing), clear from cursor to the end 
# of the line. If n is 1, clear from cursor to beginning of the line. If n is 2, clear entire 
# line. Cursor position does not change.
print_provider_name () {
  provider=$1

  provider_name_len=$(str_len "$provider")
  dot_len=$((max_len_provider_name-provider_name_len+5))
  echo -ne "\033[0K$provider "
  printf '.%.0s' $(seq 1 $dot_len)
  echo -n " "
}

# Print the provider state "Registered" with white text on dark red background
# to the terminal screen.
#
# https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
# \033[38;5;15m - foreground color - white
# \033[48;5;1m - background color - dark red
# \033[m - reset to normal
print_registered_state () {
  echo -e "\033[38;5;15m\033[48;5;1m Registered \033[m"
}

# Print the provider state "NotRegistered" with black text on dark green background
# to the terminal screen.
#
# https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
# \033[38;5;0m - foreground color - black
# \033[48;5;2m - background color - dark green
# \033[m - reset to normal
print_not_registered_state () {
  echo -e "\033[38;5;0m\033[48;5;2m NotRegistered \033[m"
}

# Print the provided provider state with white text on dark grey background
# to the terminal screen.
#
# https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
# \033[38;5;15m - foreground color - white
# \033[48;5;243m - background color - dark grey
# \033[m - reset to normal
# https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
print_state () {
  state=$1
  echo -e "\033[38;5;15m\033[48;5;243m $state \033[m"
}

# Moves the cursor up n lines to the first line of provider names and states. This allows
# the script to overwrite the provider name and state so that the terminal screen appears 
# to refresh the state values in-place.
#
# https://en.wikipedia.org/wiki/ANSI_escape_code#Control_Sequence_Introducer_commands
# \033[nF	- Moves cursor to beginning of the line n (default 1) lines up. 
move_cursor_to_first_line () {
  number_of_lines=$1
  echo -ne "\033[${number_of_lines}F"
}

# Check input parameters for correct usage
if [ $# -ne 1 ]; then
  usage
  exit 1
elif [ "$1" == "--help" ]; then
  usage
  exit 0
elif [[ ! -f $1 ]]; then
  echo -e "\033[38;5;15m\033[48;5;1m File ${1} provided, does not exist. \033[m"
  usage
  exit 1
fi

delay_in_seconds=5
max_len_provider_name=0
elapsed_time_start=$(date +%s)

# Read azure resource providers from text file into associative array 
# with state of Registered
declare -A providers
while IFS= read -r line || [[ "$line" ]]; do
  providers[$line]="Registered"
  provider_name_len=$(str_len "$line")
  if [ "$provider_name_len" -gt "$max_len_provider_name" ]; then
    max_len_provider_name=$provider_name_len
  fi
done < "${1}"

# Get list of all registered azure resource providers
mapfile -t registered_providers < <(az provider list --query "sort_by([?registrationState=='Registered'].{Provider:namespace}, &Provider)" --out tsv)

# Build a sorted list of azure resource providers to register
mapfile -t sorted_required_providers < <(for key in "${!providers[@]}"; do echo "$key"; done | sort)

# Unregister the providers in the list that are not already registered
for provider in "${sorted_required_providers[@]}"; do 
  
  print_provider_name "$provider"

  if [ "$(echo "${registered_providers[@]}" | grep "$provider" )" != "" ]; then
    
    print_registered_state
    az provider unregister --namespace "$provider" > /dev/null 2>&1

  else
    
    print_not_registered_state
    providers[$provider]="NotRegistered"

  fi
done

total_number_of_providers=${#providers[@]}
registered_count=$total_number_of_providers

# Print the updated state of each of the provider registrations
while [ "$registered_count" -gt 0 ]
do
  move_cursor_to_first_line "$total_number_of_providers"
  for provider in "${sorted_required_providers[@]}"; do 

    if [ "${providers[$provider]}" == "NotRegistered" ]; then
      state="NotRegistered"
    else
      state=$(az provider show --namespace "$provider" --query 'registrationState' --output tsv)
    fi

    print_provider_name "$provider"
    if [ "$state" = "NotRegistered" ] || [ "$state" = "Unregistered" ]; then
      ((registered_count--))
      print_not_registered_state
      providers[$provider]="NotRegistered"
    elif [ "$state" = "Registered" ]; then
      print_registered_state
    else
      print_state "$state"
    fi

  done

  if [ "$registered_count" -gt 0 ]; then
    sleep $delay_in_seconds
    registered_count=$total_number_of_providers
  fi
done

elapsed_time_end=$(date +%s)
elapsed_time=$(( elapsed_time_end - elapsed_time_start ))
echo -e "\nElapsed time - $(date -d@${elapsed_time} -u +%Hh:%Mm:%Ss)\n"
