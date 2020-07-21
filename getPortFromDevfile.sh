#!/bin/bash

# check for some prereq components
if ! yq --version > /dev/null 2>&1
then
    echo "Error: 'yq' command is not installed or not available on the path"
    exit 1
fi

if [ $# -gt 0 ]
then
    filename=$1
    if [ -f $filename ] 
    then 
       configfile=$filename
    fi
else
    if [ -f "./devfile.yaml" ] 
    then
        #echo "No filename specified defaulting to using './devfile.yaml'"
        configfile="devfile.yaml"
    else
        echo "Error: No filename specified and no devfile.yaml found."
        exit 1
    fi
fi

schemaVersion=$(yq r $configfile schemaVersion)
if [ "$schemaVersion" == "null" ] || [[ "$schemaVersion" =~  "2.[0-9].[0-9]" ]]
then
    echo "Error: devfile specified is not a version 2 devfile"
    exit 1
fi

num_containers=$(yq r $configfile components[*].container.name | wc -l)
if [ $num_containers -ge 0 ] 
then
    if [ $num_containers -eq 1 ] 
    then
        port=$(yq r $configfile components[0].container.endpoints[0].targetPort)
        if [ "$port" != "null" ]
        then
            echo $port
            exit 0
        else
            echo "Error: No port found in container definition"
            exit 1
        fi
    else
        # We have more than 1 container need to check the exec.command
        # to find the run kind and then the container that it is using
        num_commands=$(yq r $configfile commands[*].exec.group.kind | wc -l)
        for ((command_count=0;command_count<$num_commands;command_count++));
        do
            command_kind=$(yq r $configfile commands[$command_count].exec.group.kind)
            if [ "$command_kind" == "run" ]
            then
                # we have the container the run command is using - find the port in that container
                command_container_name=$(yq r $configfile commands[$command_count].exec.component)
                for ((container_count=0;container_count<$num_containers;container_count++));
                do
                    container_name=$(yq r $configfile components[$container_count].container.name)
                    if [ "$container_name" == "$command_container_name" ]
                    then
                        port=$(yq r $configfile components[$container_count].container.endpoints[0].targetPort)
                        if [ "$port" != "null" ]
                        then
                            echo $port
                            exit 0
                        else
                            echo "Error: No port found in container '$container_name'"
                            exit 1
                        fi
                    fi  
                done
                echo "Error: The container specified in the 'run' command is not fond"
                exit 1
            fi
        done
        echo "Error: No command of kind 'run' found. Unable to determine container to use"
        exit 1
    fi
else
    echo "Error: No containers found in $filename"
    exit 1
fi
