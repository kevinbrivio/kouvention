#!/bin/sh

# Missing arguments
if [ -z "$1" ]; then
  echo "Missing arguments: [staging|production]"
  exit 128
fi

# Invalid arguments
case "$1" in
"staging") echo "Running staging"
;;
"production") echo "Running production"
;;
*)
  echo "Invalid arguments [staging|production]"
  exit 1
;;
esac

eval "flutter run --flavor $1 --dart-define ENV=$1"
