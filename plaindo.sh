#!/bin/bash

#Defaults
File="~/todo.md"
ShowDue=0
Archive=0
CompleteQuery=0
ToggleBold=0
DefaultAction='list'
DefaultArguments=''
PrintColor=1
PrintTotals=0
CheckBoxFormat="- [ ]"

usage()
{
  less << EOF
SYNOPSIS
   usage plaindo.sh [OPTIONS] ACTION [ARGUMENTS]

DESCRIPTION
   Utility to interact with a plain text todo file via the command line. It
   allows you to add tasks, and so some simple operations. More complex
   editing can be done with your text editor.

   The plain-text todo file is assumed to have the format:

   # Project1
      [] Task 1
      [ ] Task 2
   # Project2
      - [] Task 1
      - [x] Task 2

   The checkbox can contain a space, and a dash is allowed to be in front. 

   If no arguments and options are specified, the contents of the todo
   file are shown

   OPTIONS:
   -b CHECKBOX FORMAT
      Format of checkbox to use in front of task, e.g "[]", "[ ]" or "- [ ]" 
      Default is "- [ ]"
   -c 
      Do not use color/bold in output (slightly faster)
   -f TODO FILE
      Use a todo file other than the default ~/todo.md
   -h
      Show this help
   -t 
      Print totals when using list (slower)


   ACTIONS:
   archive
      Archive completed tasks, i.e. lines starting with X or x instead
      of -. Tasks are moved to file done.md in same directory as the
      todo file
    do QUERY
      Completes the task (replacing - with X) that matches QUERY. Only a
      single task can match. Search is case sensitive
   add|a TASK
      Adds TASK to the todo file (see option -f). If a
      string of format @project or +project is present in the task, the task
      is filed under that project. If no project specified, the task is filed
      under project "INBOX". Matching is case insensitive, and only part of
      project name needs to match. So if there is a project "# AA BB CC" in the file,
      +AA, @AA and +BB in the task will match that, as long as it's unique. Spaces in
      project names in the file are allowed (e.g. "project 1 part 1"), but not when
      adding a project to a task through the + or @ tag. So be careful with spaces.
   prio1 | p1 | prio2 | p2 | prio3 | p3 QUERY
      Toggle priority 1,2 or 3 of the task that matches QUERY, using [1], [2] or [3]
   wait| w QUERY
      Toggle the waiting for status of the task that matches QUERY, replacing [] with [w].
   clear| c QUERY
      Removes the status of the task that matches QUERY, replacing [*] with []
   status| s STATUS QUERY
      Toggle the status of the task that matches QUERY, replacing [] with [STATUS].
   edit | e
      Edit the file in vim
   showdue | due
      Show tasks with due date, i.e. have a tag due:YYYY-MM-DD
   list | ls QUERY
      Show the content of the todo file. If QUERY is specified, only the tasks specifying
      QUERY are shown (projects are always shown)
   help
      show help


CREDITS & COPYRIGHTS
    Copyright (C) 2016-2020 Ronald Kaptein
    This software is distributed under the GPLv3, see https://www.gnu.org/licenses/gpl-3.0.html

SEE ALSO
    https://github.com/ronaldkaptein/plaindo.sh
EOF
}

function list()
{
  Search=$@
  if [[ "$Search" == ""  ]]; then
    Text=`cat $File`
  else
    Text=`fgrep -h -e "$Search" -e "# " $File`
  fi

  if [[ $PrintColor == 1 ]]; then
    HighPrioText=`echo -e '\e[1;31m'`
    DoneText=`echo -e '\e[1;30m'`
    LowPrioText=`echo -e '\e[0;31m'`
    Prio2Text=`echo -e '\e[0;36m'`
    TitleText=`echo -e '\e[4;33m'`
    NormalText=`echo -e '\e[0m'`
    echo "$Text" | sed "s/^\([ \t-]*\[1\].*\)$/$HighPrioText\1$NormalText/g" | 
      sed "s/^\([ \t-]*\[[ ]\][ ]*(1).*\)$/$HighPrioText\1$NormalText/g" | 
      sed "s/^\([ \t-]*\[[xX]\] .*\)$/$DoneText\1$NormalText/g" | 
      sed "s/^\([ \t-]*\[[wW3]\] .*\)$/$LowPrioText\1$NormalText/g" | 
      sed "s/^\([ \t-]*\[[ ]\][ ]*(3).*\)$/$LowPrioText\1$NormalText/g" | 
      sed "s/^\([ \t-]*\[2\] .*\)$/$Prio2Text\1$NormalText/g" | 
      sed "s/^\([ \t-]*\[[ ]\][ ]*(2).*\)$/$Prio2Text\1$NormalText/g" | 
      sed "s/^\([ \t-]*[#].*\)$/$TitleText\1$NormalText/g"
  else
     echo "$Text"
  fi
  if [[ $PrintTotals == 1 ]]; then
    NTodo=`echo "$Text" | grep "^[ \t-]*\[[^x]\][ ]*.*" | wc -l`
    NDone=`echo "$Text" | grep "^[ \t-]*\[[x]\][ ]*.*"  | wc -l`
    if [ "$NDone" == "0" ]; then
      echo "$NTodo active tasks"
    elif [ "$NDone" == "1" ]; then
      echo "$NTodo active tasks and $NDone done task (use archive to remove)"
    else
      echo "$NTodo active tasks and $NDone done tasks (use archive to remove)"
    fi
  fi
}

function archive()
{
  ArchiveDir=`dirname $File`
  ArchiveFile=`echo $ArchiveDir/done.md`
  Date=`date +%Y-%m-%d`
Done=`sed -n "s/^[ \t-]*\[[xX]\][ ]*\(.*\)/$Date \1/p" $File `
if [ "$Done" == "" ]; then
  echo No completed tasks found in $File
else
  Count=`echo "$Done" | wc -l `
  echo "$Done" >> $ArchiveFile
  sed -i -e '/^[ \t-]*\[[xX]\][ ]*.*/d' $File
  echo "Moved $Count todo's to $ArchiveFile"
fi
}

function add()
{
  Task=$@
  if [[ "$Task" == ""  ]]; then
    usage
    exit
  fi
  BackupFile=$File.bak
  cp $File $BackupFile

  ProjectSymbol="@"
  Project=`echo $@ | sed -n 's/^.*@\([^ ]*\).*$/\1/p'`
  if [ "$Project" == "" ]; then
    ProjectSymbol="+"
    Project=`echo $@ | sed -n 's/^.*+\([^ ]*\).*$/\1/p'`
  fi

  if [ "$Project" == "" ]; then
    ProjectSymbol=""
    Project="INBOX"
  fi

  Count=`grep -i -E "^[#]*[ ]*.*$Project.*" $File | wc -l`
  if [ "$Count" -eq "0" ]; then
    echo "Project \"$Project\" not found, please add it to $File first"
    exit
  elif [ "$Count" -gt "1" ]; then
    echo "Multiple matches for \"$Project\", please specify unique query"
    exit
  else
    ActualProject=`grep -i -E "^#*[ ]*.*$Project.*" $File | sed 's/^#*[ ]*\(.*\)$/\1/g'` 
    if [ "$ActualProject" != "INBOX" ]; then
      Task=`echo $Task | sed -n "s/\(^.*\)\($ProjectSymbol$Project\)\(.*\)/\1\3/p" | sed "s/  */ /g" | sed "s/^[ ]*//g"`
    fi
    echo Adding to project $ActualProject: $Task
    ProjectLine=`grep -i -E "^[#]*[ ]*.*$Project.*" $File`
    sed -i "s/^\($ProjectLine\)/\1\n   $CheckBoxFormat $Task/i" $File
  fi
}

function changeStatus()
{
  NewStatus=`echo "$1" `
  shift
  Query=`echo "$@" `

  if [[ "$NewStatus" == "CLEAR" ]]; then
    NewStatus=""
  fi

  if [[ "$Query" == ""  ]]; then
    usage
    exit
  fi

  SearchResult=`grep "$Query" $File`
  if [ "$SearchResult" == "" ]; then
    echo Nothing found...
  else
    Count=`echo "$SearchResult" | wc -l`
    if [ "$Count" -gt "1" ]; then
      echo $Count matches found, please specify unique query
    else
      LineNumber=`grep -n "$Query" $File | cut -d ":" -f 1`
      #Check whether line has status already
      StatusTest=`sed -n "/\([ \t-]*\)\[$NewStatus\] .*$Query.*[ ]*$/p" $File`
      if [ "$StatusTest" == "" ]; then #Add status
        sed -i "s/\([ \t-]*\)\(\[.*\]\)\(.*\)\($Query\)\(.*\)/\1[$NewStatus]\3\4\5/g" $File
      else
        sed -i "s/\([ ]\t-*\)\(\[$NewStatus\]\)\(.*\)\($Query\)\(.*\)[ ]*/\1[]\3\4\5/g" $File
      fi
      echo Replaced
      echo "$SearchResult"
      echo with
      sed -n "s/\([ \t-]*\)\(\[.*\]\)\(.*\)\($Query\)\(.*\)/\1\2\3\4\5/p" $File
      echo on line $LineNumber
    fi
  fi
}

function showdue()
{
  DueTasks=`sed -n 's/[ \t-]*\(.*\)due:\([0-9-]*\)\(.*\)/\2 \1 \3/p' $File `
  if [ -z $DueTasks ]; then
    echo No tasks with due date found
    exit
  fi
  Today=`date +%Y-%m-%d`
  Tomorrow=`date -d '+1 day' +%Y-%m-%d`
  echo "$DueTasks
  == OVERDUE ==
  $Today   == TODAY ==
  $Tomorrow   == FUTURE ==" | sort |
    sed 's/.*== TODAY ==.*/             == TODAY ==/g' | 
    sed 's/.*== FUTURE ==.*/             == FUTURE ==/g'
}

#MAIN

while getopts “b:f:hct” OPTION
do
  case $OPTION in
    f)
      File=$OPTARG
      ;;
    h)
      usage
      exit
      ;;
    c)
      PrintColor=0
      ;;
    t)
      PrintTotals=1
      ;;
    b)
      CheckBoxFormat=$OPTARG
      ;;
    ?)
      usage
      exit
      ;;
  esac
done
shift $((OPTIND-1))



if [[ "$1" == "" ]]; then
  action=$DefaultAction
  arguments=$DefaultArguments
else
  action=$1
  shift
  arguments=$*
fi

case $action in 
  showdue | due)
    showdue $arguments
    exit
    ;;
  list | ls)
    list $arguments
    exit
    ;;
  add | a)
    add $arguments
    exit
    ;;
  prio1 | p1)
    changeStatus 1 $arguments
    exit
    ;;
  prio2 | p2)
    changeStatus 2 $arguments
    exit
    ;;
  prio3 | p3)
    changeStatus 3 $arguments
    exit
    ;;
  wait | w)
    changeStatus w $arguments
    exit
    ;;
  clear | c)
    changeStatus CLEAR $arguments
    exit
    ;;
  status | s)
    changeStatus $arguments
    exit
    ;;
  do|d )
    changeStatus x $arguments
    exit
    ;;
  archive)
    archive $arguments
    exit
    ;;
  edit | e )
    vim $File
    exit
    ;;
  help|h )
    usage
    exit
    ;;
  *)
    echo unknown action $action
    exit
    ;;
esac

exit
