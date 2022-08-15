#!/system/bin/sh
# 思源数据恢复脚本
################### 恢复模式配置区 ###################


RecoveryMode="2"
#切换 数据包的获取方式
# 1为从 [阿里云盘] 中获取，2为从 [本地] 中获取

updateType="1"
# 更新方式，1为自动，2为手动
# 自动方式，会选择本地/云存储中最新的数据包下载并以全量模式更新。手动方式，以交互的方式选择备份存储区域、数据包

# 手动模式
# MT文件管理器 执行脚本后，点一下右下角的 Im 即可弹出键盘进行输入


################### 网盘配置区 ###################


AliRefreshToken="32位英文数字"
# 阿里云盘 RefreshToken
# 🐰 (此项通常不需要填写，在手机上安装并登录阿里云盘app后，脚本便会自动获取此项，用于登录阿里云盘)


DirName="我的思源备份" 
# 网盘中存放有数据包的文件夹名称


################### 本地配置区 ###################


recovery_path="/storage/emulated/0/siyuan_local_backup/"
# 本地备份模式中存放有数据包的路径
# 不用进行修改


################### 其他自定义配置区 ###################



############################################



# 初始化命令
[[ `whoami` != 'root' ]] && echo -e "\n脚本需要 ROOT权限 才可以正常运行哦~\n" && exit
[[ $0 == *'bin.mt.plus/temp'* ]] && echo -e "\n请不要直接在压缩包内运行脚本，先将压缩包内的所有文件解压到一个文件夹后再执行哦~\n" && exit
cd "`dirname "$0"`"
sh_path=`pwd`
sh_path=`readlink -f "$sh_path"`
sh_path=${sh_path/'/storage/emulated/'/'/data/media/'}


# 配置busybox / curl / bc 开始
[[ ! -d "${sh_path}/command" ]] && echo -e "\n 找不到脚本运行所需依赖！请尝试前往 https://czj.lanzoux.com/b0evzleqh 重新下载脚本压缩包后，将压缩包内文件解压至同一目录下~\n" && exit
BusyboxTest='mkdir awk sed head rm cp date ls cat tr md5sum sort uniq seq touch split base64 sha1sum wc mv killall'
for Test in $BusyboxTest ; do ln -fs "${sh_path}/command/bin/busybox" "${sh_path}/command/bin/${Test}" ;done
[[ -n $LD_LIBRARY_PATH ]] && OldLib=":$LD_LIBRARY_PATH"
chmod -R 0777 "${sh_path}/command/" && export LD_LIBRARY_PATH=${sh_path}/command/lib${OldLib} && export PATH=${sh_path}/command/bin:$PATH
# 配置busybox / curl / bc 结束

# 一些方法
source "${sh_path}/command/bin/CloudLocalFunction"
ReadJson(){ echo -ne "$1" | grep -Po '\K[^}]+' | grep -Po '\K[^,]+' | grep -Po '"'$2'"[" :]+\K[^"]+';}
ReadXml(){ echo -ne "$1" | grep -E -o -e '<'$2'>.+</'$2'>' | sed 's/<'$2'>//g' | sed 's/<\/'$2'>//g';}
cut_string(){ str=`echo "$1" | sed s/[[:space:]]//g` ; str=${str#*$2} ; str=${str%%$3*} ; echo "$str";}
RmTmpExit(){ rm -rf /data/media/0/WeChat_tmp/ ; killall -s CONT com.tencent.mm >> /dev/null 2>&1 ; 
cd "${sh_path}/command/bin" && ls -1 -F "${sh_path}/command/bin" | grep -E '[@$]' | awk '{sub(/.{1}$/,"")}1' | xargs rm -rf ; exit;}
EchoYello(){ echo -e "\033[33m${1}\033[0m";}
# 一些方法

# 提示用户选择 RecoveryMode 开始
clear
[[ $RecoveryMode == "" ]] && echo -e "请选择从何处下载数据...\n\n1. 阿里云盘\n2. 本地" && echo -e "\n请输入序号后回车进行选择....." && read RecoveryMode
while [[ $RecoveryMode != 1 ]] && [[ $RecoveryMode != 2 ]];do echo -e "\033[33m\n输入错误！请重新输入！\033[0m" && read RecoveryMode ;done ;clear
# 提示用户选择 RecoveryMode 结束


# 检测错误 开始
if [[ $RecoveryMode != "2" ]];then
network_state=`curl -sIL -w "%{http_code}\n" -o /dev/null "http://www.baidu.com" `
[[ $network_state != "200" ]] && EchoYello "\n连接网络失败！备份中止.....\n" && RmTmpExit ;fi
checkEmpty(){ [[ $1 == "" ]] && echo -e "\n请先编辑 recovery.sh 中的 ${1} 项后再进行恢复噢~\n" && RmTmpExit ;}

[[ $RecoveryMode == "1" ]] && checkEmpty 'username' && checkEmpty 'password' ;clear

# 检测错误 结束



# 设置参数 开始
setParameter(){
createType="$1" ; rootDirId="$2" ; jointListType="$3" ; jsonId="$4" ; jsonName="$5" ; downloadType="$6"
}
# 设置参数 结束

# 阿里filename、fileid拼接 开始
AliJointList(){
isFirst=1 ;i=0 ;unset $4 ;while [[ -n $marker ]] || [[ $isFirst == 1 ]];do
DirList=`curl -H "content-type:application/json;charset=UTF-8" -H "authorization:${Authorization}" -d '{"drive_id":"'$DriveId'","parent_file_id":"'$1'","limit":200,"marker":"'$marker'","all":false,"fields":"*","order_by":"created_at","order_direction":"DESC"}' "https://api.aliyundrive.com/adrive/v3/file/list" -s`
marker=`ReadJson "$DirList" 'next_marker'` ; isFirst=0
[[ $5 != 'stop' ]] && [[ -z `echo "$DirList" | grep 'file_id'` ]] && EchoYello "\n找不到恢复所需数据包！恢复中止.....\n" && echo "$DirList" && RmTmpExit
tmpA=(`ReadJson "$DirList" "$2"`) ; tmpB=(`ReadJson "$DirList" "$3"`) ; j=0
while [[ $j -lt ${#tmpA[@]} ]];do eval $4[$i]='"${tmpA[$j]} ${tmpB[$j]}"' ;let i++ j++ ;done ;done
}
# 阿里filename、fileid拼接 结束

# 阿里文件下载 开始
AliDownloadFiles(){
rm -rf /data/media/0/siyuan_backup/data
mkdir -p /data/media/0/siyuan_backup/data/
fileName=`echo "$1" | awk '{print $1}'`
fileId=`echo "$1" | awk '{print $2}'`
echo "正在下载 ${fileName} ....."
getUrl=`curl -s -H "accept:application/json, text/plain, */*" -H "authorization:${Authorization}" -d '{"drive_id":"'$DriveId'","file_id":"'$fileId'"}' "https://api.aliyundrive.com/v2/file/get_download_url"`
downloadUrl=`ReadJson "$getUrl" 'url'`
saveFile=`curl -H "Referer:https://www.aliyundrive.com/" "$downloadUrl" -o "/data/media/0/siyuan_backup/data/${fileName}" --progress-bar` && State=1 || State=0
[[ $State == 0 ]] && EchoYello "\n下载失败！恢复中止.....\n\n错误返回信息如下 ： ${saveFile}" && RmTmpExit || echo "下载完成！"
}
# 阿里文件下载 结束

# 本地数据包名获取 开始
LocalJointList(){
unset $2 ; DirList=(`ls -t "$1"`)
[[ $5 != 'stop' ]] && [[ -z ${DirList[@]} ]] && EchoYello "\n找不到恢复所需数据包！恢复中止.....\n" && RmTmpExit
i=0 ;while [[ $i -lt ${#DirList[@]} ]];do eval $2[$i]='"${DirList[$i]}"' ;let i++ ;done
}
# 本地数据包名获取 结束


# 选择恢复包类型 开始
ZipType(){
unset zipType ;clear ;echo -e "${1}\n请选择恢复模式 ：\n\n0. 从 增量数据包 中更新思源数据\n1. 从 全量数据包 中更新思源数据\nq. 返回"
getChoose(){
if [[ ${1} != "" ]];then zipType="auto" && FullMode "\033[36m自动模式，默认选择全量更新\033[0m" "0" && unZip && exit 
else echo -e "\n请输入序号后回车进行选择.....";read zipType;fi

if [[ $zipType == "0" ]];then FullMode "\033[36m您选择的是 增量数据包\033[0m"
elif [[ $zipType == "1" ]];then FullMode "\033[36m您选择的是 全量数据包\033[0m"
elif [[ $zipType == "q" ]];then Nickname
elif [[ $zipType == "auto" ]];then echo "自动模式，默认进行全量更新"
else echo "\033[33m输入错误，请重新输入！\033[0m" && getChoose ;fi ;}

if [[ ${2} != "" ]];then getChoose ${2}
else getChoose;fi
}
# 选择恢复包类型 结束

# 选择需要恢复的存储路径 开始
Nickname(){
unset choose ;clear ;echo -e "${partitionMessage}\n您所有存储路径如下 ：\n"
if [[ $RecoveryMode == "1" ]];then
$createType "$DirName" "$rootDirId"
UserDirId=`ReadJson "$NewDir" "$jsonId"`
$jointListType "$UserDirId" "$jsonName" "$jsonId" 'UserListArray'
else $jointListType "$recovery_path" 'UserListArray' ;fi
i=0 ;while [[ $i -lt ${#UserListArray[@]} ]];do echo "${i}. `echo "${UserListArray[$i]}" | awk '{print $1}'`" ;let i++ ;done ;echo "q. 退出"

getChoose(){
if [[ ${1} != "" ]];then choose=${1} && echo "[自动模式] 默认选择第一个存储位置"
else echo -e "\n请输入序号后回车进行选择.....";read choose;fi

if [[ $choose == 'q' ]];then RmTmpExit
elif [[ -n `echo $choose | grep -E '[0-9]'` ]] && [[ -n ${UserListArray[$choose]} ]];then
WxNickname=`echo "${UserListArray[$choose]}" | awk '{print $1}'`
 if [[ $RecoveryMode == "1" ]];then
 WxNicknameDir=`echo "${UserListArray[$choose]}" | awk '{print $2}'`
 $jointListType "$WxNicknameDir" "$jsonName" "$jsonId" 'NicknameListArray';fi 

if [[ ${1} != "" ]];then ZipType "\033[36m您选择的是 ${WxNickname}\033[0m" "0"
else ZipType "\033[36m您选择的是 ${WxNickname}\033[0m";fi

else echo "\033[33m输入错误，请重新输入！\033[0m" && getChoose ;fi ;}

getChoose ${1}
}
# 选择需要恢复的存储路径 结束


# 从全量包中恢复 开始
FullMode(){
unset choose ;clear ;unset dbFileDate ;echo -e "${1}\n加载数据包中......\n"
if [[ $RecoveryMode == "1" ]];then
$createType '思源备份(全量)' "$WxNicknameDir" 
WxRootDirId=`ReadJson "$NewDir" "$jsonId"`
$jointListType "$WxRootDirId" "$jsonName" "$jsonId" 'WxRootDirListArray'

else $jointListType "${recovery_path}/思源备份数据/思源备份(全量)/" 'WxRootDirListArray';fi
i=0 ;j=0 ;while [[ $i -lt ${#WxRootDirListArray[@]} ]];do
tmpFileDate=`echo "${WxRootDirListArray[$i]}" | awk '{print $1}' | cut -c -19 | tr '.' ':' | tr '_' ' '`
[[ -z `echo "${dbFileDate[@]}" | grep "$tmpFileDate"` ]] && dbFileDate[$j]="$tmpFileDate" && echo -e "${j}. 恢复 ${dbFileDate[$j]} 及之前的数据" && let j++ ;let i++ ;done ;echo "q. 返回"
getChoose(){
if [[ ${1} != "" ]];then choose=0 && echo "自动模式默认选择最新版本进行更新"
else echo -e "\n请输入序号后回车进行选择.....";read choose;fi

if [[ $choose == 'q' ]];then ZipType
elif [[ -n `echo $choose | grep -E '[0-9]'` ]] && [[ -n ${WxRootDirListArray[$choose]} ]];then

if [[ $RecoveryMode == "1" ]];then
echo "开始下载数据包${WxRootDirListArray[$choose]}....."
choseTimestamp=`date -d "${dbFileDate[$choose]}" +%s`
i=0 ;while [[ $i -lt ${#WxRootDirListArray[@]} ]];do
downloadFileDate=`echo "${WxRootDirListArray[$i]}" | awk '{print $1}' | cut -c -19 | tr '.' ':' | tr '_' ' '`
fileTimestamp=`date -d "$downloadFileDate" +%s`
[[ $fileTimestamp -eq $choseTimestamp ]] && $downloadType "${WxRootDirListArray[$i]}" ;let i++ ;done

elif [[ $RecoveryMode == "2" ]];then
echo "开始从本地备份中更新${WxRootDirListArray[$choose]}....." ;fi

else echo "\033[33m输入错误，请重新输入！\033[0m" && getChoose ;fi ;}

if [[ ${2} != "" ]];then getChoose ${2}
else getChoose;fi

}
# 从全量包中恢复 结束




# 解压 && 更新 开始
unZip(){
if [[ ${RecoveryMode} == "1" ]];then
zipFiles=`ls /data/media/0/siyuan_backup/data/ | grep -E 'gz$|.001'`
if [[ -n $zipFiles ]];then echo -e "\n解压数据包中....."
for zipFile in $zipFiles ;do
cd /data/media/0/siyuan_backup/data/ && tar -zxf $zipFile >> /dev/null
[[ $? != 0 ]] && EchoYello "\n解压失败！更新中止.....\n" && RmTmpExit ;done
rm -rf /data/media/0/siyuan_backup/data/$zipFiles
echo "解压完成！"
echo "正在替换原文件（不含widgets）"
cp -rf /data/media/0/siyuan_backup/data/* /storage/emulated/0/Android/data/org.b3log.siyuan/files/siyuan/data/
echo "[云存储模式] 更新完成"
rm -rf /data/media/0/siyuan_local_backup/data;fi



elif [[ ${RecoveryMode} == "2" ]];then
echo "解压数据包中"
mkdir -p /data/media/0/siyuan_local_backup/data/
chooseFile=${WxRootDirListArray[$choose]}
cp  "/storage/emulated/0/siyuan_local_backup/思源备份数据/思源备份(全量)/$chooseFile" /data/media/0/siyuan_local_backup/data/
cd /data/media/0/siyuan_local_backup/data/ && tar -zxf $chooseFile && rm -rf $chooseFile
cp -rf /data/media/0/siyuan_local_backup/data/* /storage/emulated/0/Android/data/org.b3log.siyuan/files/siyuan/data/
echo "[本地模式] 更新完成"
rm -rf /data/media/0/siyuan_local_backup/data;fi
}
# 解压 &&更新 结束

# 传参 开始
if [[ ${RecoveryMode} == "1" ]];then
AliLogin
setParameter 'AliCreateDir' 'root' 'AliJointList' 'file_id' 'name' 'AliDownloadFiles'
elif [[ ${RecoveryMode} == "2" ]];then
recovery_path=`readlink -f "$recovery_path" | sed 's:/storage/emulated/:/data/media/:g'`
setParameter '' '' 'LocalJointList' '' '' 'LocalLn'
fi
# 传参 结束

# 获取数据包 开始
getChoose2(){
if [[ $updateType == "1" ]];then
Nickname "0"
elif [[ $updateType == "2" ]];then Nickname
else Nickname;fi;}
getChoose2
# 获取数据包 结束

if [[ $zipType != "q" ]] && [[ $choose != 'q' ]];then

# 解压 开始（自动模式下不再走此处，单独调用unZip方法）
clear
dividingLine="\033[36m----------------------------------------\033[0m"
echo -e "\n${dividingLine}\n\n [ 更新模式 ] \n\n${dividingLine}\n"

if [[ ${updateType} == "2" ]];then
unZip;fi;
# 解压 结束


echo -e "\n\n${dividingLine}\n\n\n更新完成啦！！！\n\n" ;fi
RmTmpExit
exit