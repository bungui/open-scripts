#!/usr/bin/env bash

# 打印每行命令
set -x

backup_dir="/data/backup"
mysql_pass="123456"
date_str=$(date +%F)
sudo mkdir -p "${backup_dir}"

# mysql备份
sql_file="/tmp/mysql-${date_str}.sql"
zip_file="/tmp/mysql-${date_str}.zip"
sudo mysqldump --all-databases --single-transaction --quick --lock-tables=false -u root -p${mysql_pass} >"${sql_file}"
sudo zip -9 -r "${zip_file}" "${sql_file}"
sudo cp "${zip_file}" "${backup_dir}" -f
sudo rm "${sql_file}" -f
sudo rm "${zip_file}" -f
echo "备份mysql成功"

# redis备份
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
webdav_dir="/webdav"
webdav_filename="hkwebdav_${date_str}.zip"
webdav_tmp_file="/tmp/${webdav_filename}"
webdav_file="${backup_dir}/${webdav_filename}"

sudo zip -9 -r "${webdav_tmp_file}" "${webdav_dir}"
sudo cp "$webdav_tmp_file" "$webdav_file"
sudo rm "$webdav_tmp_file"
echo "备份本地webdav目录成功"

# 需要等待一段时间，因为上传到webdav后，mtime才会是最新的
sleep 600
find "$backup_dir" -mindepth 1 -mtime +10 -delete -print
echo "删除10天前的文件，并打印删除文件路径"