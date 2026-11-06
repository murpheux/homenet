OP_RUN := op run --env-file=op.env --
TF     := terraform

.PHONY: init fmt validate lint create-secret check-secrets db-role plan apply destroy

init:
	$(TF) init -input=false

fmt:
	$(TF) fmt -recursive

validate:
	$(TF) validate

lint: fmt validate
	shellcheck scripts/*.sh

# One-time: a 1Password item with a generated DB password (never shown or passed as an argument).
create-secret:
	op item create --vault private --category password --title homenet-tomcat --generate-password='letters,digits,32' >/dev/null && echo "created op://private/homenet-tomcat/password"

# Shape of the op.env secrets (length, whitespace, hash-like); values never printed.
check-secrets:
	$(OP_RUN) bash ../scripts/describe-secrets.sh TF_VAR_app_db_password

# Creates or resets the tomcat_user role in appdb (PostgreSQL on cass). Needs database/ up.
db-role:
	$(OP_RUN) bash scripts/create-db-role.sh

# No saved plan file: a tfplan would contain the password in plaintext.
plan:
	$(OP_RUN) $(TF) plan -input=false

apply:
	$(OP_RUN) $(TF) apply -input=false -auto-approve

# Removes the service, its configs and secret. Prompts for "yes".
destroy:
	$(OP_RUN) $(TF) destroy
