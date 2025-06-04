```go
// terratest_plan_test.go
package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformAwsEc2(t *testing.T) {
	t.Parallel()

	// Random name for uniqueness
	uniqueID := random.UniqueId()
	keyPairName := fmt.Sprintf("terratest-ec2-keypair-%s", uniqueID)

	// AWS Region
	awsRegion := "us-east-1"

	// Set up the Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// Path to Terraform code
		TerraformDir: "../",

		// Variables
		Vars: map[string]interface{}{
			"aws_region":       awsRegion,
			"instance_keypair": keyPairName,
			"instance_type":    "t2.xlarge",
			"ami_id":           "ami-09eb231ad55c3963d",
			"storage_size_gb":  100,
		},

		// Environment variables
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},

		// Retry settings
		MaxRetries:         3,
		TimeBetweenRetries: 5 * time.Second,
	})

	// Clean up resources at the end of the test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Validate EC2 instance creation
	instanceID := terraform.Output(t, terraformOptions, "instance_id")
	assert.NotEmpty(t, instanceID, "Instance ID should not be empty")

	// Check that the instance is running
	instanceStatus := aws.GetInstanceStatus(t, awsRegion, instanceID)
	assert.Equal(t, "running", instanceStatus, "Instance should be in 'running' state")

	// Validate storage
	volumeID := terraform.Output(t, terraformOptions, "volume_id")
	volumeSize := aws.GetVolumeSize(t, awsRegion, volumeID)
	assert.Equal(t, int64(100), volumeSize, "EBS volume size should be 100 GB")

	// Validate tag
	instanceTags := aws.GetTagsForEc2Instance(t, awsRegion, instanceID)
	assert.Contains(t, instanceTags, "bigo", "Instance should have a 'bigo' tag")

	// Validate SSH Key Pair creation
	keyPair, err := aws.GetEc2KeyPairE(t, awsRegion, keyPairName)
	assert.NoError(t, err, "SSH Key Pair should be created and retrievable")
	assert.Equal(t, keyPair.Name, keyPairName, "SSH Key Pair name should match")
}
```

### Commit to Git

```bash
# Create test directory if it doesn't exist
mkdir -p test

# Save the Terratest Go file into the test directory
echo 'package test...

# Commit the Terratest plan to the repository
cd test
git add terratest_plan_test.go
git commit -m "Add Terratest plan for EC2 module"
git push origin main
```