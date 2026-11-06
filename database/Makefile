OP_RUN := op run --env-file=op.env --
TF     := terraform
VARS   := TF_VAR_mysql_root_password TF_VAR_mongo_user TF_VAR_mongo_password \
          TF_VAR_postgres_user TF_VAR_postgres_password TF_VAR_sqlserver_sa_password \
          TF_VAR_redis_password

.PHONY: init fmt validate lint check-secrets plan apply destroy destroy-services

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
	$(OP_RUN) bash ../scripts/describe-secrets.sh $(VARS)

# No saved plan file: a tfplan would contain the passwords in plaintext.
plan:
	$(OP_RUN) $(TF) plan -input=false

apply:
	$(OP_RUN) $(TF) apply -input=false -auto-approve

# Destroys EVERYTHING, including the node-local data volumes: MySQL, MongoDB,
# PostgreSQL and Redis data is deleted. Prompts for "yes". The SQL Server NFS
# directories on medusa are kept (only their volume definitions are removed).
destroy:
	@echo "WARNING: deletes the MySQL, MongoDB, PostgreSQL and Redis data volumes. Use 'make destroy-services' to keep the data."
	$(OP_RUN) $(TF) destroy

# Removes the five services and their secrets but keeps every volume and the network,
# so the next 'make apply' starts the databases on their existing data.
destroy-services:
	$(OP_RUN) $(TF) destroy -target=module.mysql -target=module.mongodb -target=module.postgresql -target=module.sqlserver -target=module.redis
