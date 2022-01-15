#!/usr/bin/env bash

# 打印每行命令
set -x

backup_dir="/data/backup"
mysql_pass="123456"
date_str=$(date +%F)
sudo mkdir -p "${backup_dir}"

# mysql备份
sudo find $backup_dir/mysql* -mindepth 1 -mtime +30 -delete -print
sql_file="/tmp/mysql-${date_str}.sql"
zip_file="/tmp/mysql-${date_str}.zip"
sudo mysqldump --all-databases --single-transaction --quick --lock-tables=false -u root -p${mysql_pass} >"${sql_file}"
sudo zip -9 -r "${zip_file}" "${sql_file}"
sudo cp "${zip_file}" "${backup_dir}" -f
sudo rm "${sql_file}" -f
sudo rm "${zip_file}" -f
echo "备份mysql成功"

# redis备份
sudo find $backup_dir/redis* -mindepth 1 -mtime +10 -delete -print
redis_dump_file="/var/lib/redis/dump.rdb"
redis_tmp_file="/tmp/dump.rdb"
redis_zip_file="/tmp/redis-${date_str}.zip"
sudo cp "${redis_dump_file}" "${redis_tmp_file}"
sudo zip -9 -r "${redis_zip_file}" "${redis_tmp_file}"
sudo cp "${redis_zip_file}" "${backup_dir}" -f
sudo rm "${redis_zip_file}" -f
sudo rm "${redis_tmp_file}" -f
echo "备份redis成功"

# 备份webdav目录
sudo find $backup_dir/hkwebdav* -mindepth 1 -mtime +5 -delete -print
webdav_dir="/webdav"
webdav_file="${backup_dir}/hkwebdav_${date_str}.zip"
sudo zip -9 -r "${webdav_file}" "${webdav_dir}"
echo "备份本地webdav目录成功"

# rclone同步到webdav前，文件的mtime是很旧的，不可以根据mtime删除文件