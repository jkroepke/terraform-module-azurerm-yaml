.PHONY: clean generate

clean:
	rm -rf ../*_generated.tf

generate: schema.json
	gomplate -t templates/_helper.tmpl -d terraform=./schema.json --exclude _* --exclude README.md --input-dir=templates --output-map='../{{ .in | strings.ReplaceAll ".tf.tmpl" ".tf" }}'

format:
	terraform fmt ../*_generated.tf

.terraform:
	terraform init

schema.json: .terraform
	terraform providers schema -json > schema.json


all: generate format
