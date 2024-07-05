#!/bin/bash

last_analysis_stop_time=last_analysis_stop_time.txt
raw_results_dir=results
analysis_dir=analysis

attestation_known_apis_suffix=attestation_known_apis.tsv
attestation_known_origins_suffix=attestation_known_origins.json
rws_known_origins_suffix=rws_known_origins.json

rm -r $analysis_dir && mkdir -p $analysis_dir

#get file storing filename of where last analysis stopped
if [[ -z "$S3_ANALYSIS_BUCKET" ]];then
    echo "S3_ANALYSIS_BUCKET undefined, assuming local run: not grabbing $last_analysis_stop_time from s3"
else
    aws s3 cp s3://$S3_ANALYSIS_BUCKET/$last_analysis_stop_time $last_analysis_stop_time
fi

#parse timestamp and convert format for date to understand
last_timestamp=$(cat $last_analysis_stop_time | sed 's/-/ /g' | sed 's/_/-/g' | sed 's/-/:/g3')
stop_time=$(date --date "$last_timestamp" +'%s')

echo "Start Analysis last timestamp was: $last_timestamp"

if [[ -z "$S3_DATA_BUCKET" ]];then
    echo "S3_DATA_BUCKET undefined, assuming local run: not grabbing crawl results from s3"
else
    echo "Copying well known generic files from S3 bucket"
    #get files from S3 bucket
    aws s3 cp s3://$S3_DATA_BUCKET/$attestation_known_apis_suffix ${analysis_dir}/${attestation_known_apis_suffix}
    aws s3 cp s3://$S3_DATA_BUCKET/$attestation_known_origins_suffix ${analysis_dir}/${attestation_known_origins_suffix}
    aws s3 cp s3://$S3_DATA_BUCKET/$rws_known_origins_suffix ${analysis_dir}/${rws_known_origins_suffix}

    #obtain filenames of objects in s3 buckets
    s3_filenames=$(aws s3 ls s3://$S3_DATA_BUCKET | awk '{print $4}' | sed -n s/'\([0-9_-]*\).tar.zst/\1/p')
    #loop through filanmes to grab only the new ones since last analysis
    while IFS= read -r filename
    do
        #parse timestamp and convert format for date to understand
        filename_timestamp=$(echo $filename | sed 's/-/ /g' | sed 's/_/-/g' | sed 's/-/:/g3')
        filename_time=$(date --date "$filename_timestamp" +'%s')

        if [ $filename_time -gt $stop_time ]
        then
            echo "Copying $filename_timestamp.tar.zst from S3 bucket"
            aws s3 cp s3://$S3_DATA_BUCKET/$filename_timestamp.tar.zst - | tar --zstd -xf -C $raw_results_dir/
        fi
    done <<< "$s3_filenames"
fi

#for loop on results folder, check again if time is greater, if so, run
#analysis, and update times
for crawl_filename in $raw_results_dir/*
do
    crawl_filetime=$(echo "${crawl_filename##*/}") #remove folder prefix
    #parse timestamp and convert format for date to understand
    crawl_timestamp=$(echo $crawl_filetime | sed 's/-/ /g' | sed 's/_/-/g' | sed 's/-/:/g3')
    crawl_time=$(date --date "$crawl_timestamp" +'%s')

    if [ $crawl_time -gt $stop_time ]
    then
        ./post_crawl_analysis.sh $crawl_filetime
         #update stop timestamp, keep going
        stop_time=$crawl_time
        echo $crawl_filetime > $last_analysis_stop_time
    fi
done

#update file storing filename of where last analysis stopped
if [[ -z "$S3_ANALYSIS_BUCKET" ]];then
    echo "S3_ANALYSIS_BUCKET undefined, assuming local run: not updating $last_analysis_stop_time to s3"
else
    aws s3 cp $last_analysis_stop_time s3://$S3_ANALYSIS_BUCKET/$last_analysis_stop_time
fi

