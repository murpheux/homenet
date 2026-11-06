OP_RUN := op run --env-file=op.env --
TF     := terraform
VARS   := TF_VAR_elastic_password TF_VAR_kibana_system_password \
          TF_VAR_kibana_encryption_key TF_VAR_filebeat_password

.PHONY: init fmt validate lint create-secrets check-secrets bootstrap wait-es plan apply destroy

init:
	$(TF) init -input=false

fmt:
	$(TF) fmt -recursive

validate:
	$(TF) validate

lint: fmt validate

# One-time: 1Password item "homenet-elk" with generated 32-character values (never shown).
create-secrets:
	bash ../scripts/create-op-item.sh private homenet-elk elastic-password kibana-system-password kibana-encryption-key filebeat-password

# Shape of the op.env secrets (length, whitespace, hash-like, duplicates); values never printed.
check-secrets:
	$(OP_RUN) bash ../scripts/describe-secrets.sh $(VARS)

# First deploy only: Elasticsearch must be up before the elasticstack provider can manage
# users, so start it on its own, then wait for it to answer (15 min: image pull plus the
# first-start 7.17 -> 8.19 upgrade). On timeout the wait script prints task errors and logs.
ES_URL := http://scarlet:9200

bootstrap:
	$(OP_RUN) $(TF) apply -input=false -auto-approve -target=module.elasticsearch
	bash ../scripts/wait-for-service.sh softcraftotto $(ES_URL) 900

# Re-check Elasticsearch without applying (same output as bootstrap's wait).
wait-es:
	bash ../scripts/wait-for-service.sh softcraftotto $(ES_URL) 60

# No saved plan file: a tfplan would contain the passwords in plaintext.
plan:
	$(OP_RUN) $(TF) plan -input=false

apply:
	$(OP_RUN) $(TF) apply -input=false -auto-approve

# Removes every service, secret, user and the network, and DELETES the es_data volume
# (all indices) and Kibana's volume. Prompts for "yes".
destroy:
	@echo "WARNING: deletes the Elasticsearch data volume (es_data) and every index in it."
	$(OP_RUN) $(TF) destroy
