# Copyright 2016 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

GOOGLE_CLOUD_PROJECT:=$(shell gcloud config list project --format="value(core.project)")
ZONE=$(shell gcloud config list compute/zone --format="value(compute.zone)")
CLUSTER_NAME=guestbook
COOL_DOWN=15
MIN=2
MAX=15
TARGET=50
DEPLOYMENT=guestbook
GUESTBOOK_POD_NAME=$(shell kubectl get pods | grep guestbook -m 1 | awk '{print $$1}' )

.PHONY: all
all: deploy

.PHONY: create-cluster
create-cluster:
	gcloud container clusters create guestbook \
		--scope "https://www.googleapis.com/auth/userinfo.email","cloud-platform" \
		--num-nodes=$(MIN)
	gcloud container clusters get-credentials guestbook

.PHONY: create-bucket
create-bucket:
	gsutil mb gs://$(GOOGLE_CLOUD_PROJECT)
	gsutil defacl set public-read gs://$(GOOGLE_CLOUD_PROJECT)

.PHONY: template
template:
	# Minikube templates
	jinja2 kubernetes_configs/guestbook/guestbook.yaml.jinja minikube_jinja.json --format=json > kubernetes_configs/guestbook/guestbook_minikube.yaml
	jinja2 kubernetes_configs/postgres/postgres.yaml.jinja minikube_jinja.json --format=json > kubernetes_configs/postgres/postgres_minikube.yaml
	# GKE templates
	jinja2 kubernetes_configs/guestbook/guestbook.yaml.jinja gke_jinja.json --format=json > kubernetes_configs/guestbook/guestbook_gke.yaml
	jinja2 kubernetes_configs/postgres/postgres.yaml.jinja gke_jinja.json --format=json > kubernetes_configs/postgres/postgres_gke.yaml

.PHONY: deploy
deploy: push template
	kubectl apply -f kubernetes_config/guestbook/guestbook_gke.yaml

.PHONY: update
update:
	kubectl rolling-update frontend --image=gcr.io/${GOOGLE_CLOUD_PROJECT}/guestbook:latest

.PHONY: disk
disk:
	gcloud compute disks create pg-data  --size 200GB

.PHONY: firewall
firewall:
	gcloud compute firewall-rules create kubepostgres --allow tcp:30061

.PHONY: autoscale-on
autoscale-on:
	AUTOSCALE_GROUP=$(shell gcloud container clusters describe $(CLUSTER_NAME) --zone $(ZONE) --format yaml | grep -A 1 instanceGroupUrls | awk -F/ 'FNR ==2 {print $$NF}')
	gcloud compute instance-groups managed set-autoscaling $(AUTOSCALE_GROUP) \
	  --cool-down-period $(COOL_DOWN) \
	  --max-num-replicas $(MAX) \
	  --min-num-replicas $(MIN) \
	  --scale-based-on-cpu --target-cpu-utilization $(shell echo "scale=2; $(TARGET)/100" | bc)
	kubectl autoscale rc $(DEPLOYMENT) --min=$(MIN) --max=$(MAX) --cpu-percent=$(TARGET)

.PHONY: migrations
migrations:
	kubectl exec $(GUESTBOOK_POD_NAME) -- python /app/manage.py migrate

.PHONY: delete
delete:
	gcloud container clusters delete guestbook
	gcloud compute disks delete pg-data
