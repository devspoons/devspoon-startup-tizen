#!/bin/bash

while :
do 
    echo "* if your project path has sub-level, you should be insert as \\\/A\\\/B\\\/C"
    echo -n "Enter the project path >"
    read project_path
    echo  "Entered the project path: $project_path"
    if [[ "$project_path" != "" ]]; then
        break
    fi
done 

while :
do 
    echo -n "Enter the project name >"
    read project_name
    echo  "Entered the project name: $project_name"
    if [[ "$project_name" != "" ]]; then
        break
    fi
done 

sed 's/project_path/'$project_path'/g' sample_run > $project_name'1'.temp
sed 's/project_name/'$project_name'/g' $project_name'1'.temp > run.sh

rm *.temp
