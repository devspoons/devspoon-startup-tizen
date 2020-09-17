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


sed 's/project_path/'$project_path'/g' sample_run > run.sh