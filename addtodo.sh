#!/bin/bash

#Defaults
File="~/todo.md"
ShowDue=0
Archive=0

usage()
{
   cat << EOF
   usage addtodo.sh [OPTIONS]  task

   Adds task to todofile. If a string of format @project or +project
   is present
   in the task, the task is filed under that project. If not project
   specified, the task is filed under project "INBOX". Matching is 
   case insensitive
   
   Project in the file are defined by line starting with #, followed
   by the project name. The project name cannot contain spaces.

   If no arguments and options are specified, the contents of the todo
   file are shown

   OPTIONS:
   -a
      Archive completed tasks, i.e. lines starting with X or x instead
      of -. Tasks are moved to file done.md in same directory as the
      todo file
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
      Show tasks with due date 
EOF
}

while getopts “f:heda” OPTION
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
$Tomorrow   == FUTURE ==" | sort
   exit
fi

if [ "$Archive" == "1" ]; then
   ArchiveDir=`dirname $File`
   ArchiveFile=`echo $ArchiveDir/done.md`
   Date=`date +%Y-%m-%d`
   #Done=`grep -i "^[ ]*X.*" $File |sed -e "'s/^/$Date/'`
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


Task=$@

if [ "$Task" == "" ]; then
   cat $File
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
   echo Adding to project \"$Project\": $Task
   gawk -i inplace -v proj="$Project" -v task="   - $Task" 'BEGIN{IGNORECASE=1} $0 ~ proj { print; print task; next }1' $File
fi



