#!/usr/bin/env bash

# 打印每行命令
set -x

backup_dir="/data/backup"
mysql_pass="123456"
date_str=$(date +%F)

function delete_files_n_days_ago() {
	# 根目录，最好用绝对地址
	dir_path=$1
	# 例如，+7表示7天前的文件，-7表示7天内的文件
	n_days=$2
	echo "${dir_path}目录，${n_days}天的文件"
	sudo find "${dir_path}" -type f -mtime "${n_days}"
	echo "开始删除"
	sudo find "${dir_path}" -type f -mtime "${n_days}" -delete
}

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

# 备份data目录
data_dir="/repo/py-aiohttp-admin/data"
tmp_dir="/tmp/data"
zip_file="${backup_dir}/admin-data-${date_str}.zip"
if [ -d "${data_dir}" ]; then
	echo "开始备份data目录: $data_dir"
	sudo rm $tmp_dir/* -f
	sudo mv $data_dir/* $tmp_dir/
	sudo zip -r -9 "$zip_file" $tmp_dir/*
	sudo rm $tmp_dir/* -f
	echo "备份成功，文件： ${zip_file}"
fi


# 删除30天前的文件
# delete_files_n_days_ago "${backup_dir}" "+30"
