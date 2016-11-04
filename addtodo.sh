#!/bin/bash

#Defaults
File="~/todo.md"

usage()
{
   cat << EOF
   usage addtodo.sh [-eh] [-f todofile]  task

   Adds task to todofile. If a string of format @project is present
   in the task, the task is filed under that project. If not project
   specified, the task is filed under project "INBOX". Matching is 
   case insensitive
   
   Project in the file are defined by line starting with #, followed
   by the project name. The project name cannot contain spaces.

   if task is not specified, content of todofile is shown. Option 
   -e edits the file in vim.

   if todofile is not specified, it is set to ~/todo.md
EOF
}

while getopts “f:he” OPTION
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
      ?)
         usage
         exit
         ;;
   esac
done
shift $((OPTIND-1))

Task=$@

if [ "$Task" == "" ]; then
   cat $File
   exit
fi

BackupFile=$File.bak
cp $File $BackupFile

Project=`echo $@ | sed -n 's/^.*@\([^ ]*\).*$/\1/p'`

if [ "$Project" == "" ]; then
   Project="INBOX"
fi

Count=`grep -i -E "^#[ ]*$Project" $File | wc -l`
if [ "$Count" -eq "0" ]; then
   echo "Project @$Project not found, please add it to $File first"
   exit
elif [ "$Count" -gt "1" ]; then
   echo "Multiple matches for project @$Project, please fix in $File"
   exit
else
   if [ "$Project" != "INBOX" ]; then
      Task=`echo $Task | sed -n "s/\(^.*\)\( @$Project\)\(.*\)/\1\3/p"`
   fi
   echo Adding to project @$Project: $Task
   gawk -i inplace -v proj="$Project" -v task="   - $Task" 'BEGIN{IGNORECASE=1} $0 ~ proj { print; print task; next }1' $File
fi



