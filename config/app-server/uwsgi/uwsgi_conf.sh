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

let p_num=$(grep -c processor /proc/cpuinfo)*2

if [[ "$p_num" == "" ]]; then
    echo "this job can't access /proc/cpuinfo. so process number be setting as 4."
    p_num=4
fi

th_num=$p_num

echo "process number is $p_num and thread number is $th_num "

while :
do 
    echo -n "Enter the service port number >"
    read port_num
    echo  "Entered the service port number: $port_num"
    if [[ "$port_num" != "" ]]; then
        break
    fi
done 

sed 's/project_path/'$project_path'/g' sample_uwsgi.ini > $project_name'1'.temp
sed 's/project_name/'$project_name'/g' $project_name'1'.temp > $project_name'2'.temp
sed 's/p_num/'$p_num'/g' $project_name'2'.temp > $project_name'3'.temp
sed 's/th_num/'$th_num'/g' $project_name'3'.temp > $project_name'4'.temp
sed 's/port_num/'$port_num'/g' $project_name'4'.temp > uwsgi.ini

rm *.temp
