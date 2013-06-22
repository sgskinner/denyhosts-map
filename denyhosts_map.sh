#!/bin/bash

###############################################################################
# denyHosts_map.sh
###############################################################################
# 
# A script to scrape the denyhosts' logs and generate kml suitable for
# plotting on Google maps.
#
# usage: "$ ./denyHostsMap.sh [<outputFile> <workDir>] | [? | h | help | usage]"
# 
# Original Author: github.com/marekq/denyhosts-map
# Refactored by: github.com/sgskinner
# 
###############################################################################


# Used when script invoked with no args
DEFAULT_INPUT_FILE="/etc/hosts.deny"
DEFAULT_OUTPUT_FILE="$PWD/map.kml"


###- usage -###################################################################
#
# Function for explaining optional args when "help" or "?" are supplied to
# this script as args
#
###############################################################################
function usage {
    printf "$ ./denyHosts_map.sh [<inputFile> <outputFile>] | [? | h | help]\n"
    printf "\n"
    printf "With no args, '$DEFAULT_INPUT_FILE' will be used as the input file,\n"
    printf "and '$DEFAULT_OUTPUT_FILE' will be used as the output file.\n"
}


###- concatContent -############################################################
#
# Generic function to append $content to $outputFile.
#
# args:
# $1 == outputFile to write to
# $2 == content to write to outputFile
################################################################################
function concatContent {
    outputFile=$1
    content=$2
    printf "$content" >> $outputFile
}


####- concatHeader -############################################################
# 
# Concatenate the opening xml tags to the outputFile.
#
# args:
# $1 == outputFile
################################################################################
function concatHeader {
    outputFile=$1
    concatContent "$outputFile" '<?xml version="1.0" encoding="UTF-8"?>\n'
    concatContent "$outputFile" '<kml xmlns="http://www.opengis.net/kml/2.2">\n'
    concatContent "$outputFile" '    <Folder>\n'
    concatContent "$outputFile" '        <name>Blocked SSH hosts</name>\n'
    concatContent "$outputFile" '        <open>1</open>\n'
    concatContent "$outputFile" '        <Document>\n'
}


###- concatLocEntry -############################################################
# 
# Concatenate a single kml entry for one IP to outputFile
#
#
# args:
# $1 == outputFile
# $2 == ipAddr
# $3 == lon
# $4 == lat
# $5 == desc
################################################################################
function concatLocEntry {
    outputFile=$1
    addr=$2
    lon=$3
    lat=$4
    desc=$5

    concatContent "$outputFile" "            <Placemark>\n"
    concatContent "$outputFile" "                <name>$addr</name>\n"
    concatContent "$outputFile" "                <Point>\n"
    concatContent "$outputFile" "                    <coordinates>$lon,$lat,0</coordinates>\n"
    concatContent "$outputFile" "                    <description>$desc</description>\n"
    concatContent "$outputFile" "                </Point>\n"
    concatContent "$outputFile" "            </Placemark>\n"
}


###- concatFooter -#############################################################
# 
# Concatenate the closing xml tags to the outputFile.
#
#
# args:
# $1 == outputFile
################################################################################
function concatFooter {
    outputFile=$1
    concatContent "$outputFile" '        </Document> \n'
    concatContent "$outputFile" '    </Folder>\n'
    concatContent "$outputFile" '</kml>\n'
}


###- main -#####################################################################
# 
# The driver function for this script, args are optional, defaults listed
# below.
#
# args:
# $1 == [inputFile]  -- defaults to "/etc/hosts.deny"
# $2 == [outputFile] -- defaults to $PWD/map.xml
################################################################################
function main {
    
    # Do test for "usage" function call
    if [[ $# == 1 ]]; then
        usage
        exit 0
    fi


    # Set I/O files based on if args are given or not
    if [[ $# < 2  ]]; then
        inputFile=$DEFAULT_INPUT_FILE
        outputFile=$DEFAULT_OUTPUT_FILE
    else
        inputFile="$1"
        outputFile="$2"
    fi
   
    # Report I/O file locations
    printf "Attempting to use '$inputFile' as input, and '$outputFile' for results.\n"


    # Check to ensure the inputFile exists
    if [[ ! -f "$inputFile" ]]; then
        echo "The file '$inputFile' does not exist, exiting."
        exit 1
    fi
    
    # If output exists, delete the old file, otherwise ensure
    # dir structure is in place
    if [[ -f "$outputFile" ]]; then
        rm "$outputFile"
    else
        outputDir=`dirname $outputFile`
        mkdir -p $outputDir
    fi

    # Parse just the IP address from the log file
    ipAddrs=`egrep '^sshd.*' "$inputFile" | sed 's/sshd: //g' | sort -u`

    # Get a count so user knows what kind of wait they're in for
    count=`printf "$ipAddrs" | wc -l`
    printf "Found $count IP(s) to look up.\n"

    # If we have no IPs, exit
    if [[ $count < 1 ]]; then
        printf "Exiting.\n"
        exit 0
    fi

    # Start writing kml 
    concatHeader "$outputFile" 

    # Pull the info for each IP and write them to file
    for addr in $ipAddrs; do

        printf "Querying info for '$addr'...\n"

        # Query web for info on IP
        entry=`wget --quiet -O - http://freegeoip.net/xml/$addr`;
        
        # Parse info from xml response
        lat=`echo "$entry" | egrep Latitude | tr -d "[A-z/<> "`
        lon=`echo "$entry" | egrep Longitude | tr -d "[A-z/<> "`
        desc=`echo "$entry" | egrep CountryName | tr -d "<.*>/ " | sed s/CountryName//g`

        # Make an entry to the output for this IP if we have good coords from service
        if [[ -n "$lat" && -n "$lon" ]]; then
            concatLocEntry "$outputFile" "$addr" "$lon" "$lat" "$desc"
        fi

        # Bookkeep progress and let user know how much is left to do
        printf "Query complete, $count more IP(s) to process.\n"
        count=$((count-1))
        printf "\n"

    done
    
    # Close xml
    concatFooter "$outputFile"

    printf "KML generated to '$outputFile'; import this file into Google Earth or http://maps.google.com!\n"

}

main $@

