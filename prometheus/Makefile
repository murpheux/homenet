OP_RUN := op run --env-file=op.env --
TF     := terraform
VARS   := TF_VAR_grafana_admin_password TF_VAR_grafana_admin_email

.PHONY: init fmt validate lint check-secrets plan apply destroy

init:
	$(TF) init -input=false

fmt:
	$(TF) fmt -recursive

validate:
	$(TF) validate

lint: fmt validate

# Shape of the op.env secrets (length, whitespace, hash-like, duplicates); values never printed.
check-secrets:
	$(OP_RUN) bash ../scripts/describe-secrets.sh $(VARS)

# No saved plan file: a tfplan would contain the secrets in plaintext.
plan:
	$(OP_RUN) $(TF) plan -input=false

apply:
	$(OP_RUN) $(TF) apply -input=false -auto-approve

# Removes the services, configs, secret, network, datasources and the node-local data
# volumes (Prometheus TSDB, Grafana database, Loki chunks are DELETED). Prompts for "yes".
destroy:
	@echo "WARNING: deletes the Prometheus, Grafana and Loki data volumes on gru and cass."
	$(OP_RUN) $(TF) destroy
