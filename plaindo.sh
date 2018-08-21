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

usage()
{
   cat << EOF
SYNOPSIS
   usage plaindo.sh [OPTIONS] ACTION [ARGUMENTS]

DESCRIPTION
   Utility to interact with a plain text todo file via the command line. It
   allows you to add tasks, and so some simple operations. More complex
   editing can be done with your text editor.

   The plain-text todo file is assumed to have the format:

   # Project1
      - Task 1
      - Task 2
   # Project2
      - Task 1
      X Task 2

   If no arguments and options are specified, the contents of the todo
   file are shown

   OPTIONS:
   -c 
      Do not use color/bold in output (slightly faster)
   -f TODO FILE
      Use a todo file other than the default ~/todo.md
   -h
      Show this help
   -t 
 Do not print totals when using list (slower)
 
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
      under project "INBOX". Matching is case insensitive, and only first part of
      project name needs to match. So if there is a project "# AABBCC" in the file,
      +AA or @AA in the task will match that, as long as it's unique. Spaces in
      project names in the file are allowed (e.g. "project 1 part 1"), but not when
      adding a project to a task through the + or @ tag. So be careful with spaces.
   bold | b QUERY
      Toggle the bold status of the task that matches QUERY. Only a sinle task can match
      Search is case sensitive. Task, excluding the leading -, is wrapped in *. If task is
      already bold, both * are removed.
   edit | e
      Edit the file in vim
   showdue | due
      Show tasks with due date, i.e. have a tag due:YYYY-MM-DD
   list | ls
      Show the content of the todo file
   help
      show help
    

CREDITS & COPYRIGHTS
    Copyright (C) 2016-2017 Ronald Kaptein
    This software is distributed under the GPLv3, see https://www.gnu.org/licenses/gpl-3.0.html

SEE ALSO
    https://github.com/ronaldkaptein/plaindo.sh
EOF
}

function list()
{
   if [[ $PrintColor == 1 ]]; then
     BoldText=`echo -e '\e[44m'`
     DoneText=`echo -e '\e[0;35m'`
     TitleText=`echo -e '\e[4;33m'`
     NormalText=`echo -e '\e[0m'`
     cat $File | sed "s/^\([ ]*[-xX] \)\(\*.*\)$/\1$BoldText\2$NormalText/g" | sed "s/^\([ ]*[xX] .*\)$/$DoneText\1$NormalText/g" | sed "s/^\([ ]*[#].*\)$/$TitleText\1$NormalText/g"
   else
     cat $File
   fi
   if [[ $PrintTotals == 1 ]]; then
     NTodo=`grep "^[ ]*-[ ]*.*" $File | wc -l`
     NDone=`grep "^[ ]*[xX][ ]*.*" $File | wc -l`
     if [ "$NDone" == "0" ]; then
       echo "$NTodo active tasks"
     elif [ "$NDone" == "1" ]; then
       echo "$NTodo active tasks and $NDone done task (use -a to archive)"
     else
       echo "$NTodo active tasks and $NDone done tasks (use -a to archive)"
     fi
   fi
}

function complete()
{
   Query=`echo "$@" `
   if [[ "$Query" == ""  ]]; then
      usage
      exit
   fi
   echo Q $Query
   SearchResult=`grep "$Query" $File`
   if [ "$SearchResult" == "" ]; then
      echo Nothing found...
   else
      Count=`echo "$SearchResult" | wc -l`
      if [ "$Count" -gt "1" ]; then
         echo $Count matches found, please specify unique query
      else
         LineNumber=`grep -n "$Query" $File | cut -d ":" -f 1`
         sed -i "s/\([ ]*\)-\(.*\)\($Query\)\(.*\)/\1X\2\3\4/g" $File
         echo Replaced
         echo "$SearchResult"
         echo with
         sed -n "s/\([ ]*\)X\(.*\)\($Query\)\(.*\)/\1X\2\3\4/p" $File
         echo on line $LineNumber
      fi
   fi
}

function archive()
{
   ArchiveDir=`dirname $File`
   ArchiveFile=`echo $ArchiveDir/done.md`
   Date=`date +%Y-%m-%d`
   Done=`sed -n "s/^[ ]*[xX][ ]*\(.*\)/$Date \1/p" $File `
   if [ "$Done" == "" ]; then
      echo No completed tasks found in $File
   else
      Count=`echo "$Done" | wc -l `
      echo "$Done" >> $ArchiveFile
      sed -i -e '/^[ ]*[xX][ ]*.*/d' $File
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

   Count=`grep -i -E "^#[ ]*$Project" $File | wc -l`
   if [ "$Count" -eq "0" ]; then
      echo "Project \"$Project\" not found, please add it to $File first"
      exit
   elif [ "$Count" -gt "1" ]; then
      echo "Multiple matches for project \"$Project\", please fix in $File"
      exit
   else
      if [ "$Project" != "INBOX" ]; then
         Task=`echo $Task | sed -n "s/\(^.*\)\( $ProjectSymbol$Project\)\(.*\)/\1\3/p"`
      fi
      Project=`grep -i -E "^#[ ]*$Project.*" $File`
      echo Adding to project \"$Project\": $Task
      sed -i "s/^\($Project\)/\1\n   - $Task/i" $File > tmp.txt
   fi
}

function bold()
{
   Query=`echo "$@" `
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
         #Check whether line is already bold:
         BoldTest=`sed -n "/\([ ]*\)[-xX ] \*.*$Query.*\*[ ]*$/p" $File`
         if [ "$BoldTest" == "" ]; then
            sed -i "s/\([ ]*\)\([-xX] \)\(.*\)\($Query\)\(.*\)/\1\2*\3\4\5*/g" $File
         else
            sed -i "s/\([ ]*\)\([-xX] \)\*\(.*\)\($Query\)\(.*\)\*[ ]*/\1\2\3\4\5/g" $File
         fi
         echo Replaced
         echo "$SearchResult"
         echo with
         sed -n "s/\([ ]*\)\([-xX] \)\(.*\)\($Query\)\(.*\)/\1\2\3\4\5/p" $File
         echo on line $LineNumber
      fi
   fi
}

function showdue()
{
   DueTasks=`sed -n 's/[ ]*\(.*\)due:\([0-9-]*\)\(.*\)/\2 \1 \3/p' $File `
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

while getopts “f:hct” OPTION
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
   bold | b)
       bold $arguments
       exit
       ;;
    do|d )
       complete $arguments
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
