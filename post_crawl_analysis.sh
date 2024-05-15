#!/bin/bash

results_dir=results
if [ "$#" -ne 1 ] || ! [ -d "${results_dir}/$1" ]; then
  echo "Usage: $0 TIMESTAMP_CRAWL_DIR" >&2
  exit 1
fi

timestamp=$1
results_crawl_dir=${results_dir}/${timestamp}

# ATTESTATION
attestation_dir=${results_crawl_dir}/attestation
attestation_origins=${results_crawl_dir}/attestation_origins.txt
attestation_apis_suffix=attestation_apis.tsv
attestation_apis=${results_crawl_dir}/${attestation_apis_suffix}

attestation_known_origins=${results_dir}/attestation_known_origins.json
attestation_known_origins_tmp=${results_dir}/attestation_known_origins.json.tmp
attestation_known_apis=${results_dir}/attestation_known_apis.tsv

if [ -f $attestation_apis ]; then
    rm $attestation_apis
fi

if [ -f $attestation_origins ]; then
    rm $attestation_origins
fi
echo -e "enrollment_site\tplatform\tapi" > $attestation_apis
for entry in ${attestation_dir}/*
do
    #extract origins of enrollment_site
    jq -r '.privacy_sandbox_api_attestations[0] | .enrollment_site' $entry >> $attestation_origins
    #extract enrollment_site platform and apis from attestation files (only latest entry in attestation file)
    jq -r '(.privacy_sandbox_api_attestations[0] | [ .enrollment_site ]  + (.platform_attestations[] | [.platform] + (.attestations | objects | keys[] as $k | [$k]))) | @tsv' $entry >> $attestation_apis

done
# keep unique apparitions
sort -u $attestation_origins -o $attestation_origins
sort -u $attestation_apis -o $attestation_apis

#update json of known origins for next crawl/public
while read -r LINE
do
    #jq update timestamp or insert into array if not present (assumption: post
    #analysis script is run in sequential order, i.e., no check if timestamp
    #higher than current one saved)
    jq -r --arg ORIGIN "$LINE" --arg TIMESTAMP "$timestamp" '.known_origins |=  (map(.origin) | index($ORIGIN)) as $idx | if $idx then .[$idx]["latest_crawled"] = $TIMESTAMP else . + [{"origin": $ORIGIN, "latest_crawled": $TIMESTAMP}] end' $attestation_known_origins > $attestation_known_origins_tmp
    rm $attestation_known_origins
    mv $attestation_known_origins_tmp $attestation_known_origins
done < $attestation_origins


#update list of apis to release publicly
if [ -f $attestation_known_apis ]; then
    rm $attestation_known_apis
fi
echo -e "enrollment_site\tplatform\tapi\ttimestamp" > $attestation_known_apis
#parse know origins for attestation, iterate through
jq -r '.known_origins[] | [.origin] + [.latest_crawled] | @tsv' $attestation_known_origins | while IFS=$'\t' read domain date; do

    if [ -d "${results_dir}/$date" ]; then
        cat ${results_dir}/$date/${attestation_apis_suffix} | grep $domain | while IFS=$'\t' read d p a; do
            echo -e "$d\t$p\t$a\t$date" >>$attestation_known_apis
        done
    fi
done

# keep unique apparitions
sort -u $attestation_known_apis -o $attestation_known_apis


#RWS
rws_dir=${results_crawl_dir}/rws

rws_primary=${results_crawl_dir}/rws_primary.txt
rws_associatedSites=${results_crawl_dir}/rws_associatedSites.txt
rws_serviceSites=${results_crawl_dir}/rws_serviceSites.txt
rws_ccTLDs=${results_crawl_dir}/rws_ccTLDs.txt

rws_known_origins=${results_dir}/rws_known_origins.json
rws_known_origins_tmp=${results_dir}/rws_known_origins.json.tmp

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
#extract origins from RWS files
for entry in ${rws_dir}/*
do
    jq -r '.primary' $entry >> $rws_primary
    jq -r 'select(.associatedSites != null) | .associatedSites[]' $entry >> $rws_associatedSites
    jq -r 'select(.serviceSites != null) | .serviceSites[]' $entry >> $rws_serviceSites
    jq -r 'select(.ccTLDs != null) | .ccTLDs | objects | .[] | .[]' $entry >> $rws_ccTLDs
done
#keep unique apparitions
sort -u $rws_primary -o $rws_primary
sort -u $rws_associatedSites -o $rws_associatedSites
sort -u $rws_serviceSites -o $rws_serviceSites
sort -u $rws_ccTLDs -o $rws_ccTLDs

rws_files=($rws_primary $rws_associatedSites $rws_serviceSites $rws_ccTLDs)
for file in "${rws_files[@]}"; do
    while read -r LINE
    do
        #jq update timestamp or insert into array if not present
        jq -r --arg ORIGIN "$LINE" --arg TIMESTAMP "$timestamp" '.known_origins |=  (map(.origin) | index($ORIGIN)) as $idx | if $idx then .[$idx]["latest_crawled"] = $TIMESTAMP else . + [{"origin": $ORIGIN, "latest_crawled": $TIMESTAMP}] end' $rws_known_origins > $rws_known_origins_tmp
        rm $rws_known_origins
        mv $rws_known_origins_tmp $rws_known_origins
    done < $file
done



# rws_github_origins=${results_crawl_dir}/rws_github_origins.txt
# rws_diff_on_github=${results_crawl_dir}/rws_diff_on_github.txt
# rws_diff_not_on_github=${results_crawl_dir}/rws_diff_not_on_github.txt

# diff $rws_origins $rws_github_origins | grep ">" | sed 's/^> //g' > $rws_diff_on_github
# diff $rws_origins $rws_github_origins | grep "<" | sed 's/^< //g' > $rws_diff_not_on_github
