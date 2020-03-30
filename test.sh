#!/bin/bash
echo Running for tests $1
testCommands="-r human --loglevel error -y"
if [ "$1" == "all" ]; then
    sfdx force:apex:test:run -l RunLocalTests -c $testCommands
else
    sfdx force:apex:test:run -n $1 $testCommands
fi