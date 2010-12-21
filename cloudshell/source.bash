function .cloud.setup {
  if [ -z "${CLOUDSHELL_ROOT}" ] ; then
    echo set the CLOUDSHELL_ROOT environment variable in your .bashrc
    return 1
  fi
  if [ -f ${CLOUDSHELL_ROOT}/ssh_known_hosts ] ; then
    rm ${CLOUDSHELL_ROOT}/ssh_known_hosts
  fi
  if [ ${CLOUDSHELL_ROOT}/identity/cloudrc ] ; then
    . ${CLOUDSHELL_ROOT}/identity/cloudrc
  fi
  return 0
}

# connect via ssh
function .cloud.shell {
  .cloud.setup || return 1
  hostname=$1
  if [ -z "$hostname" ] ; then
    echo "usage: cloud shell HOST"
    echo "(use \"cloud lookup\" to list hosts)"
    return 1
  fi
  ip=`.cloud.lookup ${hostname}`
  if [ $? -ne 0 ] ; then
    echo "Unable to lookup host ${hostname}"
    echo $ip
    return 1
  fi
  # move into the root directory, since ssh_config IdentityFiles are relative
  (cd $CLOUDSHELL_ROOT && ssh -F ${CLOUDSHELL_ROOT}/ssh_config ubuntu@${ip})
  return $?
}

function .cloud.launch {
  .cloud.setup || return 1
  args="$*"
  ami=`echo $args | grep ami-`
  if [ -z "$ami" ] ; then
    echo Specify an image to launch
    echo available images
    echo "----------------"
    euca-describe-images | awk '{print $2 "  " $3}' | grep ami
    return 1
  fi
  has_keypair=`echo $args | egrep '(\-k\>)|--keypair'`
  if [ -z "$has_keypair" ] ; then
    if [ -z "$CLOUD_KEYPAIR" ] ; then
      echo "Specify --keypair or set CLOUD_KEYPAIR"
      return 1
    fi
    args="-k $CLOUD_KEYPAIR $args"
  fi
  echo "euca-run-instances $args"
  euca-run-instances $args
  return $?
}

function .cloud.alias {
  alias=$1
  ip=$2

  if [ -z "$alias" ] || [ -z "$ip" ] ; then
    echo "USAGE: cloud alias HOSTREF IP"
    return 1
  fi

  hostfile=${CLOUDSHELL_ROOT}/hosts.txt
  echo "$alias         $ip" >>  $hostfile
  return 0
}

function .cloud.exec {
  .cloud.setup || return 1

  hostname=$1
  if [ -z "$hostname" ] ; then
    echo "Provide hostname/alias as argument"
    echo use \"cloud shell\" to see a list of hosts
    return
  fi
  shift

  ip=`.cloud.lookup $hostname`
  if [ $? -ne 0 ] ; then
    echo "Unable to lookup host ${hostname}"
    echo $ip
    return 1
  fi

  # move into the root directory, since ssh_config IdentityFiles are relative
#  echo "[${ip}] ${@}"
  (cd $CLOUDSHELL_ROOT && ssh -F ${CLOUDSHELL_ROOT}/ssh_config ubuntu@${ip} sudo -i "$@")
  return $?
}

function .cloud.script {
  .cloud.setup || return 1

  hostname=$1
  if [ -z "$hostname" ] ; then
    echo "usage: cloud script host script (use \"cloud shell\" to list hosts)"
    return
  fi
  shift

  command=$1
  if [ -z "$command" ] || [ ! -f "${CLOUDSHELL_ROOT}/commands/${command}" ]
  then
    echo usage: cloud script host script
    echo scripts are stored in ${CLOUDSHELL_ROOT}/commands/
    return 1
  fi
  shift

  ip=`.cloud.lookup ${hostname}`
  if [ $? -ne 0 ] ; then
    echo "Unbale to lookup host ${hostname}"
    echo $ip
    return 1
  fi

  base=`basename $command`
  args="$@"
  .cloud.send ${hostname} /tmp commands/${command}
#  echo "[${ip}] ${base} ${args}"
  (cd $CLOUDSHELL_ROOT && ssh -F ssh_config ubuntu@${ip} "cd /tmp && chmod +x ${base} && sudo -i /tmp/${base} ${args}")
  return $?
}

function .cloud.send {
  .cloud.setup || return 1

  host=$1
  shift

  ip=`.cloud.lookup ${host}`
  if [ $? -ne 0 ] ; then
    echo "Unbale to lookup host '${host}'"
    echo $ip
    return 1
  fi

  dir=$1
  shift

  if [ -z "$@" ] ; then
    echo "Usage: cloud send HOSTREF HOSTDIR FILE0 .. FILEn"
    return 1
  fi

  echo "ssh -F ssh_config $@ ubuntu@${ip}:${dir}"
  (cd $CLOUDSHELL_ROOT && scp -F ssh_config $@ ubuntu@${ip}:${dir})
  return $?
}

function .cloud.lookup {
  .cloud.setup || return 1

  hostfile=${CLOUDSHELL_ROOT}/hosts.txt
  if [ ! -f ${hostfile} ] ; then
    echo "Missing host configuration file: ${hostfile}"
    return 2
  fi

  if [ -z "$1" ] ; then
    echo "known hosts"
    echo "-----------"
    cat ${hostfile} | awk '{print $1}'
    return 1
  fi

  dataline=`cat ${hostfile} | grep $1`
  if [ -z "$dataline" ]; then
    echo "Unable to find host line from ${hostfile} for host \"${1}\""
    return 1
  fi
  echo ${dataline} | awk '{print $2}'
  return 0
}

function .cloud.id {
  .cloud.setup || return 1

  if [ -z "$1" ] ; then
    hostfile=${CLOUDSHELL_ROOT}/hosts.txt
    if [ ! -f ${hostfile} ] ; then
      echo "Missing host configuration file: ${hostfile}"
      return 2
    fi
    echo "known hosts"
    echo "-----------"
    for h in `cat ${hostfile} | awk '{print $1}'` ; do
      echo $h `.cloud.id $h`
    done
    return 1
  fi
  ip=`.cloud.lookup $1`
  if [ $? -ne 0 ] ; then
    echo "Unable to look up host $1"
    echo $ip
    return 1
  fi
  euca-describe-instances | grep $ip | awk '{print $2}'
  return $?
}

function .cloud.term {
  .cloud.setup || return 1

  if [ -z "$1" ] ; then
    echo "Usage: cloud term HOST"
    return 1
  fi
  id=`.cloud.id $1`
  if [ $? -ne 0 ] ; then
    echo "Unable to find host ID"
    return 1
  fi
  euca-terminate-instances $id
  return $?
}

function .cloud.identity {
  .cloud.setup || return 1
  if [ ! -d ${CLOUDSHELL_ROOT}/identities ] ; then
    echo "MISSING ${CLOUDSHELL_ROOT}/identities/ DIRECTORY"
    return 1
  fi
  if [ -z $1 ] ; then
    # list all identities
    curid=""
    if [ -d ${CLOUDSHELL_ROOT}/identity ] ; then
      curid=`stat -c "%N" ${CLOUDSHELL_ROOT}/identity | awk -F/ '{print $NF}' | sed -e s/.$//`
    fi
    for x in `ls ${CLOUDSHELL_ROOT}/identities` ; do
      bn=`basename $x`
      if [ "$bn" == "$curid" ] ; then
        echo -n '* '
      else
        echo -n '  '
      fi
      echo $bn
    done
    return 1
  fi
  if [ -d ${CLOUDSHELL_ROOT}/identity ] ; then
    rm ${CLOUDSHELL_ROOT}/identity
  fi
  ln -s ${CLOUDSHELL_ROOT}/identities/${1} ${CLOUDSHELL_ROOT}/identity
  # re-source configuration to reset env
  .cloud.setup
}

function cloud {
  fname=$1
  shift

  if [ -z "$fname" ] ; then
    echo unspecified command
    echo known commands
    echo "--------------"
    echo alias HOSTREF IP
    echo "exec HOSTREF CMD [ARG0 ... ARGn]"
    echo "id [HOSTREF]"
    echo "identity [SWITCHTO]"
    echo launch INSTANCE_ID
    echo "lookup [HOSTREF]"
    echo "script HOSTREF SCRIPT [ARG0 ... ARGn]"
    echo send HOSTREF HOSTDIR FILE0... FILEn
    echo shell HOSTREF
    echo term HOSTREF
    return 1
  fi

  .cloud.$fname "$@"
}

# run this once at the beginning to source cloudrc globally and to warn of error
.cloud.setup
