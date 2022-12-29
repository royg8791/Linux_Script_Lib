# Progress Bar
function progress_bar () {
  # this function will print to the screen (depending on the screen size)
  # a "Progress" bar, e.g. <Progress: [#####-------------] 23.4%>
  local length=$1
  local counter=$2

  screen_size=$(stty size|cut -d' ' -f2)
  [[ $counter -eq $length ]] && printf "%${screen_size}s" && return
  let prog=100000/${length}*${counter}

  dec=$(echo $prog|rev|cut -c3-|cut -c1|rev)
  [[ -z "$dec" ]] && dec=0
  num=$(echo $prog|rev|cut -c4-|rev)
  [[ -z "$num" ]] && num=0

  let bar_size=${screen_size}-20

  let fill=${bar_size}*${num}/100
  let empty=${bar_size}-${fill}
  fill=$(printf "%${fill}s")
  empty=$(printf "%${empty}s")
  printf "Progress [${fill// /#}${empty// /-}] ${num}.${dec}%%\r"
}

# Print in Colors
# Reset
Color_Off='\033[0m'       # Text Reset
# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White
# Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White
# Underline
UBlack='\033[4;30m'       # Black
URed='\033[4;31m'         # Red
UGreen='\033[4;32m'       # Green
UYellow='\033[4;33m'      # Yellow
UBlue='\033[4;34m'        # Blue
UPurple='\033[4;35m'      # Purple
UCyan='\033[4;36m'        # Cyan
UWhite='\033[4;37m'       # White
# Background
On_Black='\033[40m'       # Black
On_Red='\033[41m'         # Red
On_Green='\033[42m'       # Green
On_Yellow='\033[43m'      # Yellow
On_Blue='\033[44m'        # Blue
On_Purple='\033[45m'      # Purple
On_Cyan='\033[46m'        # Cyan
On_White='\033[47m'       # White
# High Intensity
IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White
# Bold High Intensity
BIBlack='\033[1;90m'      # Black
BIRed='\033[1;91m'        # Red
BIGreen='\033[1;92m'      # Green
BIYellow='\033[1;93m'     # Yellow
BIBlue='\033[1;94m'       # Blue
BIPurple='\033[1;95m'     # Purple
BICyan='\033[1;96m'       # Cyan
BIWhite='\033[1;97m'      # White
# High Intensity backgrounds
On_IBlack='\033[0;100m'   # Black
On_IRed='\033[0;101m'     # Red
On_IGreen='\033[0;102m'   # Green
On_IYellow='\033[0;103m'  # Yellow
On_IBlue='\033[0;104m'    # Blue
On_IPurple='\033[0;105m'  # Purple
On_ICyan='\033[0;106m'    # Cyan
On_IWhite='\033[0;107m'   # Whit

# exit message with error code
function error_exit () {
  exit_code=$1
  message=$2
  if [[ $exit_code -eq 2 ]]; then
    echo -e "${Red}ERROR:${Color_Off} $message\n"
  elif [[ $exit_code -eq 1 ]]; then
    echo -e "${Yellow}ERROR:${Color_Off} $message\n"
  fi
  exit $exit_code
}

function test_volumes () {
  # gather data
  volumes=$(df -h | grep "^/dev/")
  # change "Internal Field Seperator" to be New-Line "\n"
  IFS=$'\n'

  for i in $volumes; do
    percentage=$(awk '{print $5}' <<< $i | sed 's/%//')
    vol_path=$(awk '{print $NF}' <<< $i)
    if [[ $percentage -ge 95 ]]; then
      error_exit 2 "${percentage}% Usage for [${vol_path}]"
    elif [[ $percenyage -ge 90 ]]; then
      error_exit 1 "${percentage}% Usage for [${vol_path}]"
    fi
  done
}

function ftp_script_for_linux () {
  HOST="infdev"
  USER="informatica01"
  PASSWORD="Infor1q2w3e4r5t6y7u8i9o0p"

  DESTINATION='\55682_NAYAX_IICS\'

  SOURCE_PATH="/home/Informatica/INT/55682_NAYAX/EMAIL/"
  FILES="*.txt"

  cd $SOURCE_PATH
  ftp -inv $HOST <<EOF

  user $USER $PASSWORD
  cd $DESTINATION
  mput $FILES
  bye
EOF
}
