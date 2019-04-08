#!/bin/bash
# usage: readdataid.sh <endpoint> <namespace> <ramrole> <dataid>@<group>
## config param
endpoint=$1
namespace=$2
ramrole=$3

string=$4
ss=(${string//@/ })

dataId=${ss[0]}
group=${ss[1]}

## config param end
## get serverIp from address server
serverIp=`curl $endpoint:8080/diamond-server/diamond -s | awk '{a[NR]=$0}END{srand();i=int(rand()*NR+1);print a[i]}'`
stsresp=$(curl http://100.100.100.200/latest/meta-data/Ram/security-credentials/$ramrole -s)
accessKey=$(echo $stsresp | jq -r '.AccessKeyId')
secretKey=$(echo $stsresp | jq -r '.AccessKeySecret')
securityToken=$(echo $stsresp | jq -r '.SecurityToken')

## config sign
timestamp=`echo $[$(date +%s%N)/1000000]`
signStr=$namespace+$group+$timestamp
signContent=`echo -n $signStr | openssl dgst -hmac $secretKey -sha1 -binary | base64`
## request to get a config
curl -H "Spas-AccessKey:"$accessKey -H "Spas-Signature:"$signContent -H "timeStamp:"$timestamp -H "Spas-SecurityToken:"$securityToken "http://"$serverIp":8080/diamond-server/config.co?dataId="$dataId"&group="$group"&tenant="$namespace
