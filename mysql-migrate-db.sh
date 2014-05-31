#!/bin/bash
# Migrate an MySQL based database including the user who have access to another
# host. Have also the possibility to use an ssh tunnel.

script_path=$(dirname $(readlink -f $BASH_SOURCE))
source ${script_path}/mysql-migrate-db.conf.sh
