#!/bin/bash

if [ -z "$1" ]; then
    echo "Using default GitHub user."
    gh_user="zhorvath83"
else
    gh_user=$1
fi

if [ -z "$2" ]; then 
    echo "No token was provided. GitHub API rate limiting could occur."
	curl_param=""
else
    gh_token=$2
	curl_param=" -H "Authorization: token $gh_token""
fi


for i in $(curl $curl_param "https://api.github.com/users/$gh_user/repos" | grep -oP '"ssh_url":\s*"\K[^"]+'); do
  git -C ~/projects clone "$i"
done


exit 0
