#!/bin/bash

host=$1
shift
name=$1
shift

if [ -z "$host" ] || [ -z "$name" ] ; then
  echo USAGE $0 HOST IMAGENAME
  exit 1
fi

cloud send $host /tmp ${CLOUDSHELL_ROOT}/identity/*
cloud script $host bundle.sh
