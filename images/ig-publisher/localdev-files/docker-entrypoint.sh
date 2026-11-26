#!/bin/bash
set -e

# Change uid and gid of node user so it matches ownership of current dir
if [ "$MAP_NODE_UID" != "no" ]; then
    if [ ! -d "$MAP_NODE_UID" ]; then
        MAP_NODE_UID=$PWD
    fi

    uid=$(stat -c '%u' "$MAP_NODE_UID")
    gid=$(stat -c '%g' "$MAP_NODE_UID")
    echo "publisher ---> UID = $uid / GID = $gid"

    export USER=publisher

    usermod -u $uid publisher 2> /dev/null && {
      groupmod -g $gid publisher 2> /dev/null || usermod -a -G $gid publisher
    }
fi

# SUSHI, ig-publisher-scripts and publisher.jar ship with the image.
# UPDATE_ON_START=1 fetches the latest versions into the home directory,
# where they take precedence (this needs network access).
if [ "$UPDATE_ON_START" = "1" ]; then
    scripts=/home/publisher/bin/ig-publisher-scripts
    if [ -d "$scripts/.git" ]; then
        gosu publisher git -C "$scripts" pull -q
    else
        gosu publisher git clone -q https://github.com/HL7/ig-publisher-scripts "$scripts"
    fi
    gosu publisher npm install -g fsh-sushi
    jar=/home/publisher/.fhir/tools/publisher/publisher.jar
    gosu publisher mkdir -p "$(dirname "$jar")"
    gosu publisher curl -fsSL -o "$jar.part" \
        https://github.com/HL7/fhir-ig-publisher/releases/latest/download/publisher.jar
    gosu publisher mv "$jar.part" "$jar"
fi

# The scripts look for publisher.jar in input-cache/, the parent folder and
# $FHIR_PUBLISHER_HOME (default ~/.fhir/tools/publisher). Fall back to the
# bundled jar if none of these has one.
if [ -z "$FHIR_PUBLISHER_HOME" ] && [ -f /opt/ig-publisher/publisher.jar ] &&
   [ ! -f /home/publisher/.fhir/tools/publisher/publisher.jar ]; then
    export FHIR_PUBLISHER_HOME=/opt/ig-publisher
fi

exec gosu publisher "$@"
