# CloudFerry CI/CD

## 'cloudferry-functional-tests' Jenkins job

Performs set of functional tests against every new pull request into 'devel' branch of https://github.com/MirantisWorkloadMobility/CloudFerry repository

Script
    ```
    devlab/jenkins/functional_tests.sh
    ```
is to be called from job's biuld step, as follows:

!['cloudferry-functional-tests' jenkins job config snapshot](http://www.gliffy.com/go/publish/image/8657919/L.png)

## 'cloudferry-release-builder' Jenkins job

- Merges changes in 'devel' branch into 'master' branch of https://github.com/MirantisWorkloadMobility/CloudFerry (in case changes are mergeable)
- Performs functional tests against these changes
- Creates release tag for this merge.
