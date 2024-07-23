# Development Guide

There are development scripts and yaml exaples in the [`dev/`](../dev) directory that, along with the up.sh and down.sh scripts in the root of the repo, can be used to build, deploy and test changes made to the eda-server-operator.


## Build and Deploy


If you clone the repo, and make sure you are logged in at the CLI with oc and your cluster, you can run:

```
export QUAY_USER=username
export NAMESPACE=eda
export TAG=test
./up.sh
```

You can add those variables to your .bashrc file so that you can just run `./up.sh` in the future.

> Note: the first time you run this, it will create quay.io repos on your fork. You will need to either make those public, or create a global pull secret on your Openshift cluster.

To get the URL, if on **Openshift**, run:

```
$ oc get route
```

On **k8s with ingress**, run:

```
$ kubectl get ing
```

On **k8s with nodeport**, run:

```
$ kubectl get svc
```

The URL is then `http://<Node-IP>:<NodePort>`

> Note: NodePort will only work if you expose that port on your underlying k8s node, or are accessing it from localhost.

By default, the usename and password will be admin and password if using the `up.sh` script because it pre-creates a custom admin password k8s secret and specifies it on the EDA custom resource spec. Without that, a password would have been generated and stored in a k8s secret named <deployment-name>-admin-password.  

## Clean up


Same thing for cleanup, just run ./down.sh and it will clean up your namespace on that cluster


```
./down.sh
```

## Running CI tests locally


```
make lint
```

More tests coming soon...
