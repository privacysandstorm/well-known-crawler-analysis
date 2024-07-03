# well-known-crawler-analysis

Post analysis code for the well-known-crawler.

## Dependencies

A `Dockerfile` is provided under `.devcontainer/`; for direct integration with
VS Code or to manually build the image and deploy the Docker container, follow
the instructions in this [guide](https://gist.github.com/yohhaan/b492e165b77a84d9f8299038d21ae2c9).

## Environment Variables
- `S3_DATA_BUCKET`: The s3 bucket where the crawl raw results are saved, if
  undefined, we are assuming local run.
- `S3_ANALYSIS_BUCKET`: The s3 bucket where the analysis results are saved, if
  undefined, we are assuming local run.
- `S3_PUBLIC_BUCKET`: The s3 bucket where to save some of the results for public
  access, if undefined, we are assuming local run.

## Usage

```bash
#run analysis
./analysis.sh
```

## Gitlab CI/CD Variables

Define the following CI variables to have Gitlab CI building and pushing the
Docker image automatically so that ECS task is up to date:
- `AWS_ACCOUNT_ID`: the AWS account ID
- `AWS_REGION`: the AWS region to use
- `AWS_ACCESS_KEY_ID`: of an IAM user with the `AmazonEC2ContainerRegistryPowerUser` policy
- `AWS_SECRET_ACCESS_KEY`: of an IAM user with the `AmazonEC2ContainerRegistryPowerUser` policy

