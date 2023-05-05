# terraform

## How do I deploy changes?

- ensure you're using the right `terraform` via `tfenv` and the `.terraform-version`
- `cd` to the relevant `environments` subdirectory (`staging`, `prod`, `infrastructure`)
- `terraform init` (if required)
- `terraform plan`
- `terraform apply`

To validate changes prior to commit:

- `terraform fmt -recursive`
- `terraform validate`
