.PHONY: help init plan apply destroy deploy build upload invalidate clean logs

help:
	@echo "Next.js on S3 + CloudFront CDN - Makefile Commands"
	@echo ""
	@echo "Infrastructure Management:"
	@echo "  make init                 - Initialize Terraform"
	@echo "  make plan                 - Show Terraform plan"
	@echo "  make apply                - Apply Terraform configuration"
	@echo "  make destroy              - Destroy all Terraform resources"
	@echo ""
	@echo "Application Deployment:"
	@echo "  make deploy               - Full deployment (build + upload + invalidate)"
	@echo "  make build                - Build Next.js application"
	@echo "  make upload               - Upload built files to S3"
	@echo "  make invalidate           - Invalidate CloudFront cache"
	@echo ""
	@echo "Utilities:"
	@echo "  make outputs              - Show Terraform outputs"
	@echo "  make logs                 - Show CloudFront logs"
	@echo "  make clean                - Clean build artifacts"
	@echo "  make validate             - Validate Terraform configuration"
	@echo ""

# Terraform commands
init:
	@cd terraform && terraform init

validate:
	@cd terraform && terraform validate

plan:
	@cd terraform && terraform plan -out=tfplan

apply:
	@cd terraform && terraform apply tfplan

destroy:
	@read -p "Are you sure you want to destroy all resources? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		cd terraform && terraform destroy; \
	else \
		echo "Destroy cancelled"; \
	fi

# Outputs
outputs:
	@cd terraform && terraform output

# Deployment
deploy: build upload invalidate
	@echo ""
	@echo "✓ Deployment completed!"
	@echo ""

build:
	@echo "Building Next.js application..."
	@npm run build
	@echo "✓ Build completed"

upload:
	@echo "Uploading to S3..."
	@cd terraform && \
	S3_BUCKET=$$(terraform output -raw s3_bucket_name) && \
	AWS_REGION=us-east-1 && \
	echo "Syncing files to s3://$$S3_BUCKET" && \
	aws s3 sync ./out s3://$$S3_BUCKET/ \
		--delete \
		--cache-control "public, max-age=3600" \
		--exclude "*.map" \
		--region $$AWS_REGION
	@echo "✓ Upload completed"

invalidate:
	@echo "Invalidating CloudFront cache..."
	@cd terraform && \
	DISTRIB_ID=$$(terraform output -raw cloudfront_distribution_id) && \
	INVALIDATION_ID=$$(aws cloudfront create-invalidation --distribution-id $$DISTRIB_ID --paths "/*" --region us-east-1 --query 'Invalidation.Id' --output text) && \
	echo "Invalidation created: $$INVALIDATION_ID" && \
	echo "✓ Cache invalidated"

# Utilities
logs:
	@cd terraform && \
	S3_BUCKET=$$(terraform output -raw s3_bucket_name) && \
	echo "Recent access logs from S3://$$S3_BUCKET/logs:" && \
	aws s3 ls s3://$$S3_BUCKET/logs/ --recursive | tail -20

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf out/
	@rm -rf .next/
	@echo "✓ Clean completed"

# Show application URL
url:
	@cd terraform && terraform output -raw application_url && echo ""

# Watch build (requires watching)
watch:
	@npm run dev
