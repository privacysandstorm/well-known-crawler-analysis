#!/bin/bash

raw_results_dir=results
analysis_dir=analysis

if [ "$#" -ne 1 ] || ! [ -d "${raw_results_dir}/$1" ]; then
  echo "Usage: $0 TIMESTAMP_CRAWL_DIR" >&2
  exit 1
fi

timestamp=$1

echo "Start analysis for $timestamp"

raw_results_crawl_dir=${raw_results_dir}/${timestamp}
analysis_crawl_dir=${analysis_dir}/${timestamp}

mkdir -p $raw_results_crawl_dir $analysis_crawl_dir

#RWS
rws_dir=${raw_results_crawl_dir}/rws

rws_known_origins_suffix=rws_known_origins.json

rws_known_origins=${analysis_dir}/${rws_known_origins_suffix}
rws_known_origins_tmp=${analysis_dir}/${rws_known_origins_suffix}.tmp

rws_primary=${analysis_crawl_dir}/rws_primary.txt
rws_associatedSites=${analysis_crawl_dir}/rws_associatedSites.txt
rws_serviceSites=${analysis_crawl_dir}/rws_serviceSites.txt
rws_ccTLDs=${analysis_crawl_dir}/rws_ccTLDs.txt

# ATTESTATION
attestation_dir=${raw_results_crawl_dir}/attestation

attestation_crawl_apis_suffix=attestation_crawl_apis.tsv
attestation_known_apis_suffix=attestation_known_apis.tsv
attestation_known_origins_suffix=attestation_known_origins.json

attestation_known_origins=${analysis_dir}/${attestation_known_origins_suffix}
attestation_known_origins_tmp=${analysis_dir}/${attestation_known_origins_suffix}.tmp
attestation_known_apis=${analysis_dir}/${attestation_known_apis_suffix}

attestation_crawl_apis=${analysis_crawl_dir}/${attestation_crawl_apis_suffix}
attestation_crawl_origins=${analysis_crawl_dir}/attestation_crawl_origins.txt

##############
## RWS
##############
#extract origins from RWS files for current crawl
if [ -f $rws_primary ]; then
    rm $rws_primary
fi
if [ -f $rws_associatedSites ]; then
    rm $rws_associatedSites
fi
if [ -f $rws_serviceSites ]; then
    rm $rws_serviceSites
fi
if [ -f $rws_ccTLDs ]; then
    rm $rws_ccTLDs
fi
for entry in ${rws_dir}/*
do
    jq -r '.primary' $entry >> $rws_primary
    jq -r 'select(.associatedSites != null) | .associatedSites[]' $entry >> $rws_associatedSites
    jq -r 'select(.serviceSites != null) | .serviceSites[]' $entry >> $rws_serviceSites
    jq -r 'select(.ccTLDs != null) | .ccTLDs | objects | .[] | .[]' $entry >> $rws_ccTLDs
done
#keep unique apparitions only
sort -u $rws_primary -o $rws_primary
sort -u $rws_associatedSites -o $rws_associatedSites
sort -u $rws_serviceSites -o $rws_serviceSites
sort -u $rws_ccTLDs -o $rws_ccTLDs

# update general known origins file
if [ ! -f $rws_known_origins ]; then
    echo -e '{"known_origins": []}' > $rws_known_origins
fi
rws_files=($rws_primary $rws_associatedSites $rws_serviceSites $rws_ccTLDs)
for file in "${rws_files[@]}"; do
    while read -r LINE
    do
        #jq update timestamp or insert into array if not present (assumption: post
        #analysis script is run in sequential order, i.e., no check if timestamp
        #higher than current one saved)
        jq -r --arg ORIGIN "$LINE" --arg TIMESTAMP "$timestamp" '.known_origins |=  (map(.origin) | index($ORIGIN)) as $idx | if $idx then .[$idx]["latest_crawled"] = $TIMESTAMP else . + [{"origin": $ORIGIN, "latest_crawled": $TIMESTAMP}] end' $rws_known_origins > $rws_known_origins_tmp
        rm $rws_known_origins
        mv $rws_known_origins_tmp $rws_known_origins
    done < $file
done

##############
## ATTESTATION
##############
# extract attestation origins and apis for current crawl
if [ -f $attestation_crawl_apis ]; then
    rm $attestation_crawl_apis
fi
if [ -f $attestation_crawl_origins ]; then
    rm $attestation_crawl_origins
fi
echo -e "enrollment_site\tplatform\tapi" > $attestation_crawl_apis
for entry in ${attestation_dir}/*
do
    #extract origins of enrollment_site
    jq -r '.privacy_sandbox_api_attestations[0] | .enrollment_site' $entry >> $attestation_crawl_origins
    #extract enrollment_site platform and apis from attestation files (only latest entry in attestation file)
    jq -r '(.privacy_sandbox_api_attestations[0] | [ .enrollment_site ]  + (.platform_attestations[] | [.platform] + (.attestations | objects | keys[] as $k | [$k]))) | @tsv' $entry >> $attestation_crawl_apis

done
# keep unique apparitions only
sort -u $attestation_crawl_origins -o $attestation_crawl_origins
sort -u $attestation_crawl_apis -o $attestation_crawl_apis

# update general known origins file and list of apis
if [ ! -f $attestation_known_origins ]; then
    echo -e '{"known_origins": []}' > $attestation_known_origins
fi
if [ ! -f $attestation_known_apis ]; then
    echo -e "enrollment_site\tplatform\tapi\ttimestamp" > $attestation_known_apis
fi
while read -r LINE
do
    #jq update timestamp or insert into array if not present (assumption: post
    #analysis script is run in sequential order, i.e., no check if timestamp
    #higher than current one saved)
    jq -r --arg ORIGIN "$LINE" --arg TIMESTAMP "$timestamp" '.known_origins |=  (map(.origin) | index($ORIGIN)) as $idx | if $idx then .[$idx]["latest_crawled"] = $TIMESTAMP else . + [{"origin": $ORIGIN, "latest_crawled": $TIMESTAMP}] end' $attestation_known_origins > $attestation_known_origins_tmp
    rm $attestation_known_origins
    mv $attestation_known_origins_tmp $attestation_known_origins

    #update api list, by removing if match domain to update with latest result
    sed -i "\,$LINE,d" $attestation_known_apis
    cat $attestation_crawl_apis | grep $LINE | while IFS=$'\t' read domain platform api; do
        echo -e "$domain\t$platform\t$api\t$timestamp" >>$attestation_known_apis
    done

done < $attestation_crawl_origins
# keep unique apparitions
sort -u $attestation_known_apis -o $attestation_known_apis


##############
# S3 upload
##############

if [[ -z "$S3_DATA_BUCKET" ]];then
    echo "S3_DATA_BUCKET undefined, not uploading results"
else
    #upload known origins for attestation and RWS + api list
    aws s3 cp $attestation_known_origins s3://$S3_DATA_BUCKET/$attestation_known_origins_suffix
    aws s3 cp $rws_known_origins s3://$S3_DATA_BUCKET/$rws_known_origins_suffix
    aws s3 cp $attestation_known_apis s3://$S3_DATA_BUCKET/$attestation_known_apis_suffix
fi

if [[ -z "$S3_PUBLIC_BUCKET" ]];then
    echo "S3_PUBLIC_BUCKET undefined, not uploading results"
else
    #upload known origins for attestation and RWS + api list
    aws s3 cp $attestation_known_origins s3://$S3_PUBLIC_BUCKET/well-known-crawler/$attestation_known_origins_suffix
    aws s3 cp $rws_known_origins s3://$S3_PUBLIC_BUCKET/well-known-crawler/$rws_known_origins_suffix
    aws s3 cp $attestation_known_apis s3://$S3_PUBLIC_BUCKET/well-known-crawler/$attestation_known_apis_suffix
fi

if [[ -z "$S3_ANALYSIS_BUCKET" ]];then
    echo "S3_ANALYSIS_BUCKET undefined, not uploading results"
else
    #upload analysis folder to s3
    cd $analysis_dir
    tar --zstd -c $timestamp | aws s3 cp - s3://$S3_ANALYSIS_BUCKET/$timestamp.tar.zst
    cd ..
fi

echo "Analysis Finished for $timestamp"