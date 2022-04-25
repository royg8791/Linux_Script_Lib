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
