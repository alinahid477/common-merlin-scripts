#!/bin/bash

containsElement () {
  local e match="$1"
  shift
  for e; do 
    if [[ "$e" == "$match" ]]
    then
      return 0
    else
      local e1=$(echo "$e" | xargs)
      local match1=$(echo $match | xargs)
      if [[ "$e1" == "$match1" ]]
      then
        return 0
      fi
    fi
  done
  return 1
}