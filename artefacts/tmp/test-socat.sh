#!/bin/sh

# Location of socat tunnel
DEST_HOST="k8s.io"
DEST_PORT="80"
LOCAL_HOST="127.0.0.1"
LOCAL_PORT="1234"

echo
echo " * Starting socat ..."

socat TCP4-LISTEN:$LOCAL_PORT,fork,reuseaddr TCP4:$DEST_HOST:$DEST_PORT &
sleep 1

echo " * Testing socat tunnel ..."

# Using pre-existing alpine tools for test (ie. not curl)
RESPONSE=$( echo -ne "HEAD / HTTP/1.0\r\n\r\n" | \
  nc -w 2 $LOCAL_HOST $LOCAL_PORT | \
  head -1 )

# Check for response
if [ -z "$RESPONSE" ]; then
  echo "error: no response detected"
  exit 1
fi

# Validate response
RESP_HEAD=$( echo "$RESPONSE" | grep "301 Moved Permanently" )

if [ -z "$RESP_HEAD" ]; then
  echo "error: unexpected response: $RESPONSE"
  exit 1
fi

echo " * Test successful."
echo
