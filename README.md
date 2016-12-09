

# Getting started with Django on Kubernetes with  Google Container Engine and Minikube

Since this project demonstrates deploying Postgres and Redis to the cluster, it's slightly involved. For a simpler
example of Django on Container Engine/Kubernetes, try 

    https://github.com/GoogleCloudPlatform/python-docs-samples/tree/master/container_engine/django_tutorial

which also deploys Django to Kubernetes but uses a CloudSQL managed MySQL database, 
no cache, no secrets, and does not demonstrate autoscaling.

This project also demonstrates how to run the project on a local Kubernetes
cluster using Minikube. 

This repository is an example of how to run a [Django](https://www.djangoproject.com/) 
app on Google Container Engine. It was created to go with a slide deck created here.


This project walks through setting up this project on a Google Container 
Engine Kubernetes cluster. These  instructions should 
work on other Kubernetes platforms with some adjustments and should also 
deploy on other Kubernetes providers besides Google Container. Specifically, 
cluster creation steps, disks, load balancers,  cloud storage options, and 
node autoscalers should get replaced by their equivalents on your platform. 
 
This project demonstrates how to create a PostgreSQL database and Redis cache
  within your cluster. It also contains an image to simulate load on your 
  cluster to demonstrate autoscaling. The app is inspired by the 
[PHP-Redis Guestbook example](https://github.com/kubernetes/kubernetes/tree/master/examples/guestbook/php-redis).

Please submit any code or doc issues to the issue tracker!

## Container Engine vs Minikube

Originally, this project focused only on how to run the project on Container
Engine. As a followup, instructions for how to run the project on a local
Kubernetes cluster using [minikube](https://github.com/kubernetes/minikube) 
 have been added. Minikube has several advantages. It's free, it works offline,
 but it still emulates a local Kubernetes cluster.
 
Since Minikube fully emulates a Kubernetes cluster, only a few small changes
need to be made when deploying the project. Notably:

* The PostgreSQL Deployment requires a Persistent Volume Claim. The Persistent
Volume that is bound to is different. For Container Engine, it's bound to a 
GCE Persistent Disk. For Minikube, it's bound to a directory on your local 
machine (hostMount)

* Images for Container Engine are stored on Google Container Registry. Minikube
is not easily able to authenticate and pull these images, so instead, you use
`eval $(minikube docker-env)` to share the Docker daemon with Minikube. Images
you build with `docker build` will then be available to Minkube. Note that
the default imagePullPolicy will be 'Always' for any images without tags,
 so imagePullPolicy has been explicitly set to IfNotPresent for all the images.
 
* We use [jinja2 CLI](https://github.com/mattrobenolt/jinja2-cli)
  to template the configs, allowing Minikube or GKE specific parts to be
  included conditionally.


## Makefile

Several commands listed below are provided in simpler form via the Makefile. 
Many of them use the GOOGLE_CLOUD_PROJECT environment variable, which will be picked up from your gcloud config. Make sure you set this to the correct project,

    gcloud config set project <your-project-id>

There are more Makefiles in sub-directories to help build and push specific images.

## Jinja Templates

This project uses the [jinja 2 CLI](https://github.com/mattrobenolt/jinja2-cli) 
to share templates between the GKE config and Minikube config.

Run:

     pip install -r requirements-dev.txt
     
to install the CLI. At that point, you can see `minikube_jinja.json` and 
`gke_jinja.json` as examples of variables you need to poplate to generate the
templates.
 
     make template

will use the json variables to create the templates.

## Container Engine Pre-requisites

1. Install [Docker](https://www.docker.com/).
 
1. Create a project in the [Google Cloud Platform Console](https://console.cloud.google.com).

1. [Enable billing](https://console.cloud.google.com/project/_/settings) for your project.

1. [Enable APIs](https://console.cloud.google.com/flows/enableapi?apiid=compute_component,datastore,pubsub,storage_api,logging,plus) 
for your project. The provided link will enable all necessary APIs, but if you wish to do so manually you will need 
Compute, Datastore, Pub/Sub, Storage, and Logging. Note: enabling the APIs can take a few minutes.

1. [Initialise the Container Engine for the project](https://console.cloud.google.com/kubernetes/list) 

1. If on OSX or Linux then install the [Google Cloud SDK](https://cloud.google.com/sdk):

        curl https://sdk.cloud.google.com | bash 

    or if on Windows then use the Google Cloud Shell (because kubectl doesn't work yet on Windows) which you can start
    from the [Google Cloud Platform Console](https://console.cloud.google.com).

1. (Re-)Initialise the settings to set the compute zone:

        gcloud init

1. Create a cluster for the bookshelf application

        gcloud container clusters create guestbook --scopes "https://www.googleapis.com/auth/userinfo.email","cloud-platform" --num-nodes 2
        gcloud container clusters get-credentials guestbook
    
The get-credentials commands initializes the kubectl CLI tool with the cluster you just created.    

Alternatively, you can use the Makefile:
    
    make create-cluster
    
### Minkube Prerequisites 

Please see the [minikube project](https://github.com/kubernetes/minikube) for
installation instructions. Note that if you're using Docker for Mac, you 
 should specify the correct driver when you start Minikube.
 
    minikube start --vm-driver=xhyve

Or set this permamently with:

    minikube config set vm-driver=xhyve

### A note about cost

The --num-nodes flag in the cluster create specifies how many instances are created. Container Engine orchestrator is 
free up to 5 instances, but you will pay for the instances themselves, so to minimize costs just create 1 node.
 
 At the end of the tutorial, run 
 
    gcloud container clusters delete guestbook
    gcloud compute disks delete pg-data
    
or

    make delete
    
To delete the cluster and not get charged for continued use. Deleting resources you are not using is especially 
important if you run the autoscaling example to create many instances.
  
## Running PostgreSQL and Redis

The Django app depends on a PostgreSQL and Redis service. While this README explains how to deploy those services within
the Kubernetes cluster. Looking in mysite/settings.py,
you can see the app looks for several environment variables. 

The first environment variable `NODB`, if set to 1, uses a SQLite database and an in-memory cache, allowing the app to 
run without connecting to a real database. This is useful to test the app locally without Postgres/Redis, or deploy it 
to Kubernetes without Postgres/Redis. Instead, it will use a local SQLite file and in-memory cache. In the Kubernetes 
cluster, each container will have its own SQLite database and memory-cache, so the persistence and cache storage of the 
values will not be shared between containers so will not be right. The `NODB` setting is just to help debug 
incrementally and should be turned off.

The Jinja templates also contain a "has_db" variable which optionally attaches
the database password secrets to the guestbook pod. If NODB is eanbled, make
sure your templates are generated with "has_db" set to false, and set it
to true otherwise.

## Running without a database/cache and without Kubernetes

Enter the guestbook directory
    
    cd guestbook

First make sure you have Django installed. It's recommended you do so in a  
[virtualenv](https://virtualenv.pypa.io/en/latest/). The requirements.txt contains just the Django dependency.

    pip install -r requirements.txt

The app can be run locally the same way as any other Django app. 

    # disable Postgres and Redis until we set them up
    export NODB=1
    python manage.py runserver

# Deploying To Google Container Engine or Minikube (Kubernetes)

## Build the Guestbook container

Within the Dockerfile, `NODB` is turned on or off. Once you have deployed PostgreSQL or Redis, you can disable this 
flag. If you deploy those services within Kubernetes, the environment variables will be automatically populated. 
Otherwise you should set the environment variables manually using ENV in the Dockerfile.

Before the application can be deployed to Container Engine, you will need 
to build the image: 

    cd guestbook
    # Make sure NODB is enabled and set to 1 in the Dockerfile if you still haven't setup Postgres and REDIS.
    export GOOGLE_CLOUD_PROJECT=$(gcloud config list project --format="value(core.project)")
    docker build -t gcr.io/$GOOGLE_CLOUD_PROJECT/guestbook .

### Container Engine

For GKE, you would then push the image to [Google Container Registry](https://cloud.google.com/container-registry/). 

    gcloud docker push gcr.io/$GOOGLE_CLOUD_PROJECT/guestbook

or alternatively:

     make push

### Minikube

For Minikube, you don't push the image. Instead, simply make sure that when 
you build the image, you are using the Minikube docker daemon:

    $ eval $(minikube docker-env)
    # docker build -t gcr.io/$GOOGLE_CLOUD_PROJECT/guestbook

## Deploy to the application

## Deploying the frontend guestbook to Kubernetes

Once the image is built, it can be deployed in a Kubernetes pod. 
`kubernetes_configs/guestbook/` contains the 
Deployment templates to spin up Pods with this image, as well as a Service with 
an  external load balancer. However,
the frontend depends on secret passwords for the database, so before it's deployed, a Kubernetes Secret resource with
your database passwords must be created.

    kubectl apply -f kubernetes_config/guestbook/guestbook_gke.yaml
    
or on Minikube:
    
    kubectl apply -f kubernetes_config/guestbook/guestbook_minikube.yaml
 
### Create Secrets

Even if `NODB` is enabled, the frontend replication controller is configured to use the Secret volume, so it must
be created in your cluster first.
 
Kubernetes [Secrets](http://kubernetes.io/v1.1/docs/user-guide/secrets.html) are used to store the database password.
They must be base64 encoded and store in `kubernetes_configs/db.password.yaml`. A template containing an example config
is created, but your actual Secrets should not be added to source control. 
 
In order to get the base64 encoded password, use the base64 tool
 
     echo mysecretpassword | base64 
     
Then copy and paste that value into the appropriate part of the Secret config
in `kubernetes_configs/postgres/postgres.yaml.jinja`
 
In the Postgres and Guestbook deployments, these Secrets are mounted onto their 
pods if "has_db" is set to true in the Jinja variables. In their Dockerfile 
they are read into environment variables.
 
### Create the guestbook Service and Deployment

Once the resources are created, there should be 3 `frontend` pods on the cluster. To see the pods and ensure that 
they are running:

    kubectl get pods
    
To get more information about a pod, or dig into why it's having problem starting, try
  
    kubectl describe pod <pod-id>

If the pods are not ready or if you see restarts, you can get the logs for a particular pod to figure out the issue:

    kubectl logs <pod-id>

Once the pods are ready, you can get the public IP address of the load balancer:

    kubectl get services frontend

You can then browse to the external IP address in your browser to see the bookshelf application.

Alternatively on Minikube, there is no external IP, so instead run:

    minikube service

When you are ready to update the replication controller with a new image you built, the following command will do a 
rolling update

    export GOOGLE_CLOUD_PROJECT=$(gcloud config list project --format="value(core.project)")
    kubectl rolling-update frontend --image=gcr.io/${GOOGLE_CLOUD_PROJECT}/guestbook:latest
    
which can also be done with the `make update` command. If you encounter problems with the rolling-update, then
check the events:
 
    kubectl get events

It can happen that the nodes don't have enough resources left. A manual scaling down of the replication controller can
help (see above) or you can resize the cluster to have an additional node:

    gcloud container clusters resize guestbook --size 3
    
Give it a few minutes to provision the node, then try the rolling update again.

## Create the Redis cluster

Since the Redis cluster has no volumes or secrets, it's pretty easy to setup:

    kubectl apply -f kubernetes_configs/redis/redis.yaml

This creates a redis-master read/write service and redis-slave service. The images used are configured to properly 
replicate from the master to the slaves.

There should only be one redis-master pod, so the replication controller configures 1 replicas. There can be many
redis-slave pods, so if you want more you can do:

    kubectl scale deployment redis-slave --replicas=5

## Create PostgreSQL

### Container Engine

PostgresSQL will need a disk backed by a Volume to run in Kubernetes. For this example, we create a persistent disk
using a GCE persistent disk:

    gcloud compute disks create pg-data --size 200GB

or

    make disk

Edit `kubernetes_configs/postgres/postgres.yaml.jinja` volume name to match the 
name of the disk you just created, if different.

For Postgres, the secrets need to get populated and a script to initialize the database needs to be added, so a image
should be built:

    cd kubernetes_configs/postgres/postgres_image
    make build
    make push

### Minikube

Create the directory to mount:

    sudo mkdir /data/pv0001/
    sudo chown $(whoami) /data/pv001

### Creating the image, PVC, and deployment 
 
    cd kubernetes_config/postgres/postgres_image
    make build
    make push 

Finally, you should be able to create the PostgreSQL service and pod.

    kubectl apply -f kubernetes_configs/postgres/postgres_gke.yaml

or on Minikube:
 
    kubectl apply -f kubernetes_configs/postgres/postgres_minikube.yaml


Only one pod can read and write to a GCE disk, so the PostgreSQL replication controller is set to control 1 pod. 
Don't scale more instances of the Postgres pod. 
    
### Re-Deploy The Frontend and Run Migrations

Now that the database and redis service are created, you should rebuild the frontend guestbook image with `NODB`
disabled.

    cd guestbook
    # edit Dockerfile to comment out NODB
    make build
    make push

With this new image, the replication controller should be updated. One way is to do a rolling update

    make update
    
This will safely spin down the old images and replace it with the new image. However, for development purposes
it can be quicker to scale the controller to 0 and then back up.
 
     kubectl scale --replicas=0 rc/frontend
     kubectl scale --replicas=3 rc/frontend

Finally, the Django migrations must be run to create the table. This can also be accomplished with kubectl-exec, this
time with the frontend pod. However, make sure your frontend-pod is actually talking to the database. If you earlier
built the image with `NODB`, rebuild it with `NODB` commented out. Then you can run the migrations:

    export FRONTEND_POD_NAME=$(kubectl get pods | grep frontend -m 1 | awk '{print $1}')
	  kubectl exec ${FRONTEND_POD_NAME} -- python /app/manage.py makemigrations
	  kubectl exec ${FRONTEND_POD_NAME} -- python /app/manage.py migrate

or:
 
    make migrations

### Serve the static content

When DEBUG is enabled, Django can serve the files directly from that folder. Currently, the app is configured
 to serve static content from the files that way to simplify development. For production purposes, you should disable
  the DEBUG flag and serve static assets from a CDN. 

The application uses [Google Cloud Storage](https://cloud.google.com/storage) to store static content. You can 
alternatively use a CDN of your choice. Create a bucket for your project:

    gsutil mb gs://<your-project-id>
    gsutil defacl set public-read gs://<your-project-id>

or 

    make create-bucket

Collect all the static assets into the static/ folder.

    python manage.py collectstatic

Upload it to CloudStorage using the `gsutil rsync` command

    gsutil rsync -R static/ gs://<your-gcs-bucket>/static 

Now your static content can be served from the following URL:

    http://storage.googleapis.com/<your-gcs-bucket/static/

Change the `STATIC_URL` in mysite/settings.py to reflect this new URL by uncommenting
the appropriate line and replacing `<your-cloud-bucket>`


### Load Testing and Autoscaling (beta feature)

Please note that autoscaling is a beta feature.

load_test_image provides a super minimal load generator - it hits a CPU intensive endpoint in a loop with curl. First
build the image:

    cd load_testing_image
    make build
    make push

Then create the Replication Controller and scale some clients: 

    kubectl apply -f kubernetes_configs/load_tester.yaml
    kubectl scale rc load --replicas=20

to generate load. Then

    make autoscaling

will create both Node autoscaling (gcloud) and Pod autoscaling (Kubernetes Horizontal Pod Autoscaling).

Again, by default this will scale to 10 nodes whcih you will be charged for, so pleaes disable autoscaling and scale 
the nodes back down or delete the cluster if you don't want to pay for sustained use of the 10 instances.

For more sophisticated load testing with Kubernetes, see:

https://cloud.google.com/solutions/distributed-load-testing-using-kubernetes

## Issues

Please use the Issue Tracker for any issues or questions.

## Contributing changes

* See [CONTRIBUTING.md](CONTRIBUTING.md)

## Additional Reading

For another popular Django/Kubernets project + blog post, see:

https://harishnarayanan.org/writing/kubernetes-django/

This project was originally made for a talk/blog post series.

https://speakerdeck.com/waprin/deploying-django-on-kubernetes

and you can watch the talk here:

https://www.youtube.com/watch?v=HKKUgWuIZro

There is now also an associated Medium series where I go into more detail about why you would run
Django on Kubernetes and how to follow this README:

https://medium.com/google-cloud/deploying-django-postgres-redis-containers-to-kubernetes-9ee28e7a146

part 2:
https://medium.com/@waprin/deploying-django-postgres-and-redis-containers-to-kubernetes-part-2-b287f7970a33


## Licensing

* See [LICENSE](LICENSE)

This project is owned by Google Copyright 2016 but is not an official 
Google-product nor officially maintained or  supported by Google.
