# well-known-crawler-analysis

Analysis code for the well-known-crawler.

## Dependencies

A `Dockerfile` is provided under `.devcontainer/`; for direct integration with
VS Code or to manually build the image and deploy the Docker container, follow
the instructions in this [guide](https://gist.github.com/yohhaan/b492e165b77a84d9f8299038d21ae2c9).

## Environment Variables
```
S3_DATA_BUCKET: The s3 bucket where the crawl raw results are saved.
S3_ANALYSIS_BUCKET: The s3 bucket where the analysis results are saved.
S3_PUBLIC_BUCKET: The s3 bucket where to save some of the results for public access.
```

## Usage

```bash
./crawl_crux.sh
```


```bash
# extract known origins
./post_crawl_analysis.sh $crawl_time

#upload known origins for attestation and RWS + api list
aws s3 cp ${attestation_known_origins} s3://$S3_DATA_BUCKET/$attestation_known_origins
aws s3 cp ${rws_known_origins} s3://$S3_DATA_BUCKET/$rws_known_origins
aws s3 cp attestation_known_apis.tsv s3://$S3_DATA_BUCKET/attestation_known_apis.tsv
```