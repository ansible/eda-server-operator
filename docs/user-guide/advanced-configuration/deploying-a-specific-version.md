## Deploying a specific version of EDA

There are a few variables that are customizable for eda the image management.

| Name                   | Description               | Default                                 |
| ---------------------- | ------------------------- | --------------------------------------  |
| image                  | Path of the image to pull | quay.io/ansible/eda-server              |
| image_version          | Image version to pull     | latest                                  |
| image_web              | Path of the image to pull | quay.io/ansible/eda-ui                  |
| image_web_version      | Image version to pull     | latest                                  |
| image_pull_policy      | The pull policy to adopt  | IfNotPresent                            |
| image_pull_secrets     | The pull secrets to use   | None                                    |
| redis_image            | Path of the image to pull | redis                                   |
| redis_image_version    | Image version to pull     | latest                                  |
| postgres_image         | Path of the image to pull | postgres                                |
| postgres_image_version | Image version to pull     | latest                                  |

Example of customization could be:

```yaml
---
spec:
  ...
  image: myorg/my-custom-eda
  image_version: latest
  image_web: myorg/my-custom-eda
  image_web_version: latest
  image_pull_policy: Always
  image_pull_secrets:
    - pull_secret_name
```

  > **Note**: The `image` and `image_version` style variables are intended for local mirroring scenarios. Please note that using a version of EDA other than the one bundled with the `eda-server-operator` is **not** supported even though it will likely work and can be useful for pinning a version. For the default values, check the [main.yml](https://github.com/ansible/eda-server-operator/blob/main/roles/eda/defaults/main.yml) file.


### Configuring an image pull secret

1. Log in with that token, or username/password, then create a pull secret from the docker/config.json

```bash
docker login quay.io -u <user> -p <token>
```

2. Then, create a k8s secret from your .docker/config.json file. This pull secret should be created in the same namespace you are installing the EDA Operator.

```bash
kubectl create secret generic redhat-operators-pull-secret \
  --from-file=.dockerconfigjson=.docker/config.json \
  --type=kubernetes.io/dockerconfigjson
```

3. Add that image pull secret to your EDA spec

```yaml
---
spec:
  image_pull_secrets:
    - redhat-operators-pull-secret
```
