## Trusting a Custom Certificate Authority

In cases which you need to trust a custom Certificate Authority, there are few variables you can customize for the `eda-server-operator`.

Trusting a custom Certificate Authority allows the EDA to access network services configured with SSL certificates issued locally, such as cloning a project from from an internal Git server via HTTPS. If it is needed, you will likely see errors like this when doing project syncs:

```bash
fatal: unable to access 'https://private.repo./mine/ansible-rulebook.git': SSL certificate problem: unable to get local issuer certificate
```


| Name                             | Description                              | Default |
| -------------------------------- | ---------------------------------------- | --------|
| bundle_cacert_secret             | Certificate Authority secret name        |  ''     |
Please note the `eda-server-operator` will look for the data field `ldap-ca.crt` in the specified secret when using the `ldap_cacert_secret`, whereas the data field `bundle-ca.crt` is required for `bundle_cacert_secret` parameter.

Example of customization could be:

```yaml
---
spec:
  ...
  bundle_cacert_secret: <resourcename>-custom-certs
```

Create the secret with CLI:

* Certificate Authority secret

```
# kubectl create secret generic <resourcename>-custom-certs \
    --from-file=ldap-ca.crt=<PATH/TO/YOUR/CA/PEM/FILE>  \
    --from-file=bundle-ca.crt=<PATH/TO/YOUR/CA/PEM/FILE>
```


Alternatively, you can also create the secret with `kustomization.yaml` file:

```yaml
....

secretGenerator:
  - name: <resourcename>-custom-certs
    files:
      - bundle-ca.crt=<path+filename>
    options:
      disableNameSuffixHash: true
      
...
```

