# EDA Server Operator Release Guide

This document provides step-by-step instructions for releasing a new version of the EDA Server Operator. It includes tagging a new release, building and pushing images, and updating release artifacts.

## Release Workflow

### 1. Trigger the Release GitHub Action

The release process is automated through a GitHub Action (GHA) workflow. You can trigger this workflow manually via the GitHub UI.

- Navigate to the 'Actions' tab in the GitHub repository.
- Select the 'Stage Release' workflow.
- Click on 'Run workflow' dropdown.
- Enter the new version number (e.g., `1.2.3`) in the 'Release Version' input box.
- Click 'Run workflow'.

### 2. Monitor the Workflow

- Monitor the workflow for completion.
- The workflow will handle:
  - Tagging the release.
  - Building and pushing operator image for multiple platforms.
  - Generating the `operator.yaml` file.
  - Creating a draft release and attaching the `operator.yaml` as an artifact.

### 3. Publish the Release

Once the draft release is created, you need to publish it:

- Go to the 'Releases' section in the GitHub repository.
- Open the draft release created by the GitHub Action.
- Review and edit the release notes as necessary. Add notable changes, deprecation warnings, and useful upgrade information for users.
- Once satisfied, publish the release. This will trigger the 'Promote Operator Release' GHA, which will publish the operator image to quay.io as well as build and push the bundle and catalog images.

### 4. Post-Release Checks

- Ensure that the images are correctly tagged on Quay.
- Verify that the `operator.yaml` file is attached to the release and is correct.

## Troubleshooting

If you encounter issues during the release process:

- Check the GitHub Action logs for any errors or warnings.
- Verify that all prerequisites are met.
- For more specific issues, refer to the workflow file `.github/workflows/stage.yml` for insights.

## Notes

- Do not manually tag or create releases; always use the automated workflow.
- Ensure that you're familiar with the semantic versioning guidelines when assigning a version number.
