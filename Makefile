.PHONY: up destroy fmt validate

up:
	terraform init
	terraform plan
	terraform apply -auto-approve

destroy:
	terraform destroy -auto-approve

fmt:
	terraform fmt -recursive

validate:
	terraform validate
