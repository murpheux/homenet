OP_RUN  := op run --env-file=op.env --
TF      := terraform
VARS    := TF_VAR_anthropic_api_key TF_VAR_claude_enterprise_api_key TF_VAR_deepseek_api_key \
           TF_VAR_openai_api_key TF_VAR_openrouter_api_key TF_VAR_gemini_api_key \
           TF_VAR_lm_studio_api_key
DOCKER  := docker --context=murpheux-scarlet
SERVICE := softcraftgenia

.PHONY: init fmt validate lint check-secrets plan apply reload status logs destroy

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

# No saved plan file: a tfplan would contain the API keys in plaintext.
plan:
	$(OP_RUN) $(TF) plan -input=false

# agentgateway.yaml and base-costs.json ship as Swarm configs, so a config change is
# just an apply: Terraform creates a new content-hashed config and rolls the service.
apply:
	$(OP_RUN) $(TF) apply -input=false -auto-approve

reload:
	$(DOCKER) service update --force --quiet $(SERVICE)

# Recent tasks with their full error text, newest first.
status:
	$(DOCKER) service ps $(SERVICE) --no-trunc --format '{{.Node}}  {{.CurrentState}}  {{.Error}}' | head -6

# Last 60 lines of agentgateway's own log: startup and config errors appear here.
logs:
	$(DOCKER) service logs --tail 60 $(SERVICE)

# Removes the service, its Swarm configs and secrets, and the state volume (SQLite:
# budgets, MCP session key are deleted). Prompts for "yes".
destroy:
	@echo "WARNING: stops the LLM gateway and deletes its SQLite state volume (budget history)."
	$(OP_RUN) $(TF) destroy
