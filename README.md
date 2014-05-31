# mysql-migrate-db

This script allow you to migrate a MySQL based database including the user
permissions from that database. The dumps are send via an ssh connection between
two hosts or directly via an unencrypted MySQL connection.

## usage

Modify the configuration file of the source and destination database. And maybe
if required the ssh user and host. You should work on the source machine if you
like to use ssh.

### configuration

The configuration file is named `mysql-migrate-db.conf.sh` because it only contains
bash variables.

```bash
# source MySQL database
src_host='localhost'
src_user='root'
src_pass=

# destination MySQL database
dst_host='localhost'
dst_user='root'
dst_pass=

# ssh connection information (optional)
ssh_host=''
ssh_user=''
```

### parameters

```bash
./mysql-migrate-db.sh [database] [user]
```
