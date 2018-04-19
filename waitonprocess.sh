#!/bin/sh
# inspired by https://github.com/suchja/wix-toolset

echo "Start waiting on finish of $@"
while pgrep "$@" > /dev/null; do
    echo "... waiting"
    sleep 3;
done
echo "$@ completed"
