#!/bin/bash

#Defaults
File="~/todo.md"
ShowDue=0
Archive=0
CompleteQuery=0
ToggleBold=0

usage()
{
   cat << EOF
SYNOPSIS
   usage plaindo.sh [OPTIONS]  task

DESCRIPTION
   Utility to interact with a plain text todo file via the command line. It
   allows you to add tasks, and so some simple operations. More complex
   editing can be done with your text editor (see -e option).

   The plain-text todo file is assumed to have the format:

   # Project1
      - Task 1
      - Task 2
   # Project2
      - Task 1
      X Task 2

   Withouth options, it adds a task to the todo file (see option -f). If a
   string of format @project or +project is present in the task, the task
   is filed under that project. If no project specified, the task is filed
   under project "INBOX". Matching is case insensitive, and only first part of
   project name needs to match. So if there is a project "# AABBCC" in the file,
   +AA or @AA in the task will match that, as long as it's unique. Spaces in
   project names in the file are allowed (e.g. "project 1 part 1"), but not when
   adding a project to a task through the + or @ tag. So be careful with spaces.
   
   If no arguments and options are specified, the contents of the todo
   file are shown

   OPTIONS:
   -a
      Archive completed tasks, i.e. lines starting with X or x instead
      of -. Tasks are moved to file done.md in same directory as the
      todo file
   -b
      Toggle the bold status of the task that matches QUERY. Only a sinle task can match
      Search is case sensitive. Task, excluding the leading -, is wrapped in *. If task is
      already bold, both * are removed.
   -e
      Edit the file in vim
   -f TODO FILE
      Use a todo file other than the default ~/todo.md
   -h
      Show this help
   -a
      Archive done todo's (marked with X) to done.md in the same directory
      as the todo file
   -d
      Show tasks with due date, i.e. have a tag due:YYYY-MM-DD
   -c QUERY
      Completes the task (replacing - with X) that matches QUERY. Only a
      single task can match. Search is case sensitive

CREDITS & COPYRIGHTS
    Copyright (C) 2016 Ronald Kaptein
    This software is distributed under the GPLv3, see https://www.gnu.org/licenses/gpl-3.0.html

SEE ALSO
    https://bitbucket.org/ronaldk/plaindo-cli
EOF
}

while getopts “f:hedacb” OPTION
do
   case $OPTION in
      f)
         File=$OPTARG
         ;;
      h)
         usage
         exit
         ;;
      e)
         vim $File
         exit
         ;;
      d)
         ShowDue=1
         ;;
      a)
         Archive=1;
         ;;
      c)
         CompleteQuery=1
         ;;
      b)
         ToggleBold=1
         ;;
      ?)
         usage
         exit
         ;;
   esac
done
shift $((OPTIND-1))


if [ "$ShowDue" == "1" ];then 
   DueTasks=`cat $File |grep due | sed 's/[ ]*\(.*\)due:\([0-9-]*\)\(.*\)/\2 \1 \3/g'`
   N=`grep due: $File`
   if [ "$N" == "" ]; then
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
sed 's/.*== FUTURE ==.*/             == TODAY ==/g'
   exit
fi

if [ "$Archive" == "1" ]; then
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
   exit
fi

if [ "$CompleteQuery" == "1" ]; then
   Query=`echo "$@" `
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
   exit
fi

if [ "$ToggleBold" == "1" ]; then
   Query=`echo "$@" `
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
   exit
fi

Task=$@

if [ "$Task" == "" ]; then
   BoldText=`echo -e '\033[41m\033[37m'`
   NormalText=`echo -e '\033[0m'`
   sed "s/^\([ ]*[-xX] \)\(\*.*\)$/\1$BoldText\2$NormalText/g" $File
   NTodo=`grep "^[ ]*-[ ]*.*" $File | wc -l`
   NDone=`grep "^[ ]*[xX][ ]*.*" $File | wc -l`
   if [ "$NDone" == "0" ]; then
      echo "$NTodo active tasks"
   elif [ "$NDone" == "1" ]; then
      echo "$NTodo active tasks and $NDone done task (use -a to archive)"
   else
      echo "$NTodo active tasks and $NDone done tasks (use -a to archive)"
   fi
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
