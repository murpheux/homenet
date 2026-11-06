OP_RUN  := op run --env-file=op.env --
TF      := terraform
# host=ENV_VAR: the app passwords nebula-sync uses (admin logins need a 2FA code).
PIHOLES := 10.10.2.7=TF_VAR_pihole_app_password_primary 10.10.2.9=TF_VAR_pihole_app_password_replica

.PHONY: init fmt validate lint check-secrets check-auth plan apply destroy

init:
	$(TF) init -input=false

fmt:
	$(TF) fmt -recursive

validate:
	$(TF) validate

lint: fmt validate
	shellcheck scripts/*.sh

# Shape of the op.env secrets (length, whitespace, hash-like, duplicates); values never printed.
check-secrets:
	$(OP_RUN) bash ../scripts/describe-secrets.sh TF_VAR_pihole_password TF_VAR_pihole_app_password_primary TF_VAR_pihole_app_password_replica

# Confirms dns2 (primary) and dns (replica) accept the app passwords nebula-sync uses.
check-auth:
	$(OP_RUN) bash scripts/check-pihole-auth.sh $(PIHOLES)

# No saved plan file: a tfplan would contain the password in plaintext.
plan:
	$(OP_RUN) $(TF) plan -input=false

apply:
	$(OP_RUN) $(TF) apply -input=false -auto-approve

# Removes dns2, nebula-sync and the ipvlan network. Pi-hole's bind-mounted config under
# /home/murpheux/HomeNet/pihole on scarlet is kept. Prompts for "yes".
destroy:
	@echo "WARNING: takes dns2 (10.10.2.7) offline; clients fall back to dns (10.10.2.9)."
	$(OP_RUN) $(TF) destroy
