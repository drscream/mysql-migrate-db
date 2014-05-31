#!/bin/bash
# Migrate an MySQL based database including the user who have access to another
# host. Have also the possibility to use an ssh tunnel.

script_path=$(dirname $(readlink -f $BASH_SOURCE))
temp_file=$(mktemp)

# Read configuration file
[[ -f ${script_path}/mysql-migrate-db.conf.sh ]] \
	&& source ${script_path}/mysql-migrate-db.conf.sh

# Functions
function die() {
	retval=${1}; shift
	if [[ ${#} -gt 0 ]]; then
		echo "error: ${@}"
	fi
	rm ${temp_file}
	exit ${retval:-1}
}
function usage() {
	echo "${0} [sql_db] [sql_user]"
	die 0
}

# Verify variable settings
if [ -z "${src_host}" ] || [ -z "${src_user}" ] || [ -z "${src_pass}" ] || \
   [ -z "${dst_host}" ] || [ -z "${dst_user}" ] || [ -z "${dst_pass}" ]; then
	die 1 "Please make sure all config variables are set correctly"
fi
if [ -n "${ssh_host}" ] && [ -n "${ssh_user}" ]; then
	ssh_dst="${ssh_user}@${ssh_host}"
fi

# Input parameter
sql_db=${1}
sql_user=${2}

if [ -z "${sql_db}" ] || [ -z "${sql_user}" ]; then
	usage
fi

# Check source MySQL server connection
if ! mysqladmin --host="${src_host}" --user="${src_user}" \
                --password="${src_pass}" ping &>/dev/null; then
	die 2 "Couldn't connection to source MySQL server"
fi

# Be sure database you like to migrate exists on the source
if ! mysql --host="${src_host}" --user="${src_user}" --password="${src_pass}" \
           -N -B  -e"show databases;" | grep -q "^${sql_db}$"; then
	die 3 "Database doesn't exists on source MySQL server"
fi

# Create DB and user information into temp file
echo "*** create temp file with database creation and permission"
echo "CREATE DATABASE IF NOT EXISTS ${sql_db};" >> ${temp_file}

# Query mysql database for user information
mysql --host="${src_host}" --user="${src_user}" --password="${src_pass}" -B -N \
	-e "SELECT DISTINCT CONCAT('SHOW GRANTS FOR ''',user,'''@''',host,''';')
	    AS query FROM user" mysql \
	| mysql --host="${src_host}" --user="${src_user}" --password="${src_pass}" \
	| grep "${sql_user}" | sed 's:\\::g' | sed 's/Grants for .*/# &/' \
	| sed 's:$:;:g' >> "${temp_file}"
if [ ${?} -ne 0 ]; then
	die 4 "Couldn't get user information from database"
fi

# If ssh is set than copy temp file to destination server. Set also temporary
# ssh commands
if [ -n "${ssh_dst}" ]; then
	echo "*** scp temp file to destination server: ${ssh_dst}"
	scp ${temp_file} ${ssh_dst}:/tmp
	ssh_cmd="ssh ${ssh_dst}"
fi

# Import permissions and database creation on the destination server
echo "*** import database creation and permissions on destination server"
${ssh_cmd} \
	mysql --host="${dst_host}" --user="${dst_user}" --password="${dst_pass}" < \
	      "${temp_file}"
if [ ${?} -ne 0 ]; then
	die 5 "Failed to import permissions and create remote database"
fi

# Send the database to destination server
echo "*** import database ${sql_db} on destination server"
mysqldump --host="${src_host}" --user="${src_user}" --password="${src_pass}" \
	"${sql_db}" | ${ssh_cmd} mysql --host="${dst_host}" --user="${dst_user}" \
	            --password="${dst_pass}" "${sql_db}"
if [ ${?} -ne 0 ]; then
	die 5 "Failed to import database on destination server"
fi

# Remove temp file
rm ${temp_file}
