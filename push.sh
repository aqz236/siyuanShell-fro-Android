#!/system/bin/sh
# 思源笔记数据备份脚本
################### 备份模式配置区 ###################


BackupMode="2"
# 🦊暂只支持全量备份，不用做修改
# 切换 增量 / 全量 备份
# 1为 [增量备份] ，2为 [全量备份]


StorageMode="2" 
# 切换 备份数据包存放方式
# 1为上传到 [阿里云盘] ，2为上传到 [本地]

packageExclude="widgets"
# 打包排除项
# 手机端建议把插件都屏蔽打包，因为插件占用空间较大，数量小而且多，严重影响速率。 若仍想完整打包，可以将其修改为任意非空字符串，比如widgets666。

SiyuanDataPath="/storage/emulated/0/Android/data/org.b3log.siyuan/files/siyuan/data/"
# 思源data目录，无需进行修改

################### 网盘配置区 ###################


AliRefreshToken="32位英文数字"
# 阿里云盘 RefreshToken
# 🐰 (此项通常不需要填写，在手机上安装并登录阿里云盘app后，脚本便会自动获取此项，用于登录阿里云盘)

DirName="我的思源备份" 
# 可自定义网盘中存放备份数据包的文件夹名称


################### 本地配置区 ###################


store_path="/data/media/0/siyuan_backup/" 
# 云存储暂存目录  无需进行修改，脚本里都写死了

store_local_path="/data/media/0/siyuan_local_backup/"
# 本地存储目录，无需进行修改，脚本里都写死了


################### 其他自定义配置区 ###################


CheckWifiState="0"
# 1为开启，0为关闭
# 开启后，在已连接WiFi且WiFi有网络的情况下脚本才会进行备份


OutputLogMode="1"
# 1为仅输出执行日志到屏幕，2为同时输出执行日志到屏幕与脚本同目录下的BackupLog.txt

############################################



# 初始化命令
[[ `whoami` != 'root' ]] && echo -e "\n脚本需要 ROOT权限 才可以正常运行哦~\n" && exit
[[ $0 == *'bin.mt.plus/temp'* ]] && echo -e "\n请不要直接在压缩包内运行脚本，先将压缩包内的所有文件解压到一个文件夹后再执行哦~\n" && exit
cd "`dirname "$0"`"
sh_path=`pwd`
sh_path=`readlink -f "$sh_path"`
sh_path=${sh_path/'/storage/emulated/'/'/data/media/'}

main(){
# 配置busybox / curl / bc 开始
[[ ! -d "${sh_path}/command" ]] && echo -e "\n 找不到脚本运行所需依赖！请尝试前往 https://czj.lanzoux.com/b0evzleqh 重新下载脚本压缩包后，将压缩包内文件解压至同一目录下~\n" && exit
BusyboxTest='mkdir awk sed head rm cp du date ls cat tr md5sum sort uniq seq touch split base64 sha1sum wc mv killall'
for Test in $BusyboxTest ; do ln -fs "${sh_path}/command/bin/busybox" "${sh_path}/command/bin/${Test}" ;done
[[ -n $LD_LIBRARY_PATH ]] && OldLib=":$LD_LIBRARY_PATH"
chmod -R 0777 "${sh_path}/command/" && export LD_LIBRARY_PATH=${sh_path}/command/lib${OldLib} && export PATH=${sh_path}/command/bin:$PATH
# 配置busybox / curl / bc 结束


# 云存储操作封装 开始
source "${sh_path}/command/bin/CloudLocalFunction"
ReadJson(){ echo -ne "$1" | grep -Po '\K[^}]+' | grep -Po '\K[^,]+' | grep -Po '"'$2'"[" :]+\K[^"]+';}
ReadXml(){ echo -ne "$1" | grep -E -o -e '<'$2'>.+</'$2'>' | sed 's/<'$2'>//g' | sed 's/<\/'$2'>//g';}
cut_string(){ str=`echo "$1" | sed s/[[:space:]]//g` ; str=${str#*$2} ; str=${str%%$3*} ; echo "$str";}
RmTmpExit(){ rm -rf /data/media/0/siyuan_backup/ ; killall -s CONT org.b3log.siyuan >> /dev/null 2>&1 ; 
cd "${sh_path}/command/bin" && ls -1 -F "${sh_path}/command/bin" | grep -E '[@$]' | awk '{sub(/.{1}$/,"")}1' | xargs rm -rf ; exit;}
EchoYello(){ echo -e "\033[33m${1}\033[0m";}
# 云存储操作封装 结束


# 检测配置区错误 开始
[[ $StorageMode != 1 ]] && [[ $StorageMode != 2 ]] && echo -e "\n备份数据包存放方式设置错误，仅支持设置为1或2，请修改后重新执行.....\n" && RmTmpExit
CheckNumber(){ [[ $1 != $3 ]] && [[ $1 != $4 ]] && echo -e "\n${2}设置错误，仅支持设置为${3}或${4}，请修改后重新执行.....\n" && RmTmpExit;}
CheckNumber "$CheckWifiState" '检查WiFi状态开关' "0" "1"
CheckNumber "$BackupMode" '备份模式' "1" "2"
CheckNumber "$OutputLogMode" '输出执行日志模式' "1" "2"
# 检测配置区错误 结束


# 检测WiFi状态 开始
if [[ $CheckWifiState == 1 ]];then
 while [[ `cat /sys/class/net/wlan0/operstate` == "down" ]];do
 echo "未连接WiFi，10分钟后重新检测..." ; sleep 600s
 done;fi
# 检测WiFi状态 结束


# 检测网络 开始
if [[ $StorageMode != 2 ]];then
network_state=`curl -sIL -w "%{http_code}\n" -o /dev/null "http://www.baidu.com" `
[[ $network_state != "200" ]] && EchoYello "\n连接网络失败！备份中止.....\n" && RmTmpExit;fi
echo "网络已连接"
# 检测网络 结束

# 处理上次备份 开始
# 云存储只保留上一次备份，本地存储不清除备份，只清除解压出来的文件
if [[ $StorageMode == "1" ]];then
rm -rf /data/media/0/siyuan_backup/* && mkdir -p /data/media/0/siyuan_backup/
elif [[ $StorageMode == "2" ]];then
rm -rf /data/media/0/siyuan_local_backup/data && mkdir -p /data/media/0/siyuan_backup/;fi
# 处理上传备份 结束


# 提示语 开始
clear
dividingLine="\033[36m----------------------------------------\033[0m"
[[ $BackupMode == "1" ]] && modeName='增量' || modeName='全量'

[[ $StorageMode == "1" ]] && AliLogin && echo -e "\n${dividingLine}\n\n [阿里云盘] ${modeName}备份模式\n\n${dividingLine}\n" && uploadMode="AliUpload" && uploadMessage="\n正在自动上传备份数据包至阿里云盘....." && uploadSuccessMessage(){ echo -e "全部上传完成！您可以在阿里云盘 /${DirName}/${wxId[$i]}的备份数据/微信聊天记录备份(${modeName}) 中查看您的备份文件～\n\n${dividingLine}\n";}

[[ $StorageMode == "2" ]] && echo -e "${dividingLine}\n\n [本地] ${modeName}备份模式\n备份完成！备份文件所在路径：\n/data/media/0/siyuan_local_backup/\n${dividingLine}\n" && uploadMode="LocalMove" 
# 提示语 结束


# 强制停止思源 开始 （不关app也可备份）
#killall -s STOP org.b3log.siyuan >> /dev/null 2>&1
# 强制停止思源 结束


# 打包data 开始
#保存上一次提交的数据到本地，方便后续本地回滚(云存储方式，本地只保留上一次备份)
backupTime=$(date "+%Y-%m-%d_%H.%M.%S")
packageData() {
if [[ $StorageMode == "1" ]];then
mkdir -p /data/media/0/siyuan_backup/ &&
 cd /storage/emulated/0/Android/data/org.b3log.siyuan/files/siyuan/data/ && tar -zcf /data/media/0/siyuan_backup/${backupTime}_full.tar.gz * --exclude=$packageExclude
elif [[ $StorageMode == "2" ]];then
mkdir -p "${store_local_path}/思源备份数据/思源备份(${modeName})/" &&
cd /storage/emulated/0/Android/data/org.b3log.siyuan/files/siyuan/data/ && tar -zcf "${store_local_path}/思源备份数据/思源备份(${modeName})/${backupTime}_full.tar.gz" * --exclude=$packageExclude;fi
}
packageData
# 打包data 结束


# 备份 开始
# 创建文件夹 开始
if [[ $StorageMode == "1" ]];then
AliCreateDir "$DirName" 'root' 
UserDirId=`ReadJson "$NewDir" 'file_id'`
AliCreateDir '思源备份数据' "$UserDirId"
WxNicknameDir=`ReadJson "$NewDir" 'file_id'`
AliCreateDir '思源备份('$modeName')' "$WxNicknameDir"
WxRootDirId=`ReadJson "$NewDir" 'file_id'`
# TODO:多级目录，区分文件

# 本地备份
elif [[ $StorageMode == "2" ]];then
store_path=`readlink -f "$store_local_path" | sed 's:/storage/emulated/:/data/media/:g'`
WxRootDirId="${store_local_path}/思源备份数据/思源备份(${modeName})"
mkdir -p "$WxRootDirId";fi
# 创建文件夹 结束

# 上传 开始
$uploadMode '_full' $WxRootDirId
# 上传 结束

# 删除分片 开始
if [[ $StorageMode == "1" ]];then
rm -rf /storage/emulated/0/siyuan_backup/SplitFiles;fi
# 删除分片 结束
# 备份结束
}


main && echo "备份完成"
