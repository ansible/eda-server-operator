# EDA Application Settings


Here is an example of how to configure settings for the EDA application via the EDA custom resource. This will override the default application settings if set.

```yaml
---
apiVersion: eda.ansible.com/v1alpha1
kind: EDA
metadata:
  name: eda
spec:
  ...
  extra_settings:
    - setting: EDA_APP_LOG_LEVEL
      value: "DEBUG"

```



## Commonly Customized Settings

Below is a table of the setting name, default value, and a description of it's purpose:

| Setting Name             | Default Value  | Description                                     |
|--------------------------|----------------|-------------------------------------------------|
| EDA_APP_LOG_LEVEL  | "INFO"           | Log level           |
