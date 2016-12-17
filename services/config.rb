coreo_aws_vpc_vpc "${VPC_NAME}" do
  action :find
  cidr "${VPC_CIDR}"
  internet_gateway true
end

coreo_aws_vpc_routetable "${PUBLIC_ROUTE_NAME}" do
  action :find
  vpc "${VPC_NAME}"
end

coreo_aws_vpc_subnet "${PUBLIC_SUBNET_NAME}" do
  action :find
  route_table "${PUBLIC_ROUTE_NAME}"
  vpc "${VPC_NAME}"
end

coreo_aws_vpc_vpc "${VPC_NAME}" do
  action :sustain
  cidr "12.0.0.0/16"
  internet_gateway true
end

coreo_aws_iam_policy "${LAMP_NAME}-route53" do
  action :sustain
  policy_name "AllowLampRoute53Entries"
  policy_document <<-EOH
{
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": "*",
      "Action": [
          "route53:*"
      ]
    }
  ]
}
  EOH
end


coreo_aws_iam_policy "${LAMP_NAME}-s3" do
  action :sustain
  policy_name "AllowLampS3Backup"
  policy_document <<-EOH
{
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
          "arn:aws:s3:::${BACKUP_BUCKET}/${REGION}/lamp/${ENV}/${LAMP_NAME}",
          "arn:aws:s3:::${BACKUP_BUCKET}/${REGION}/lamp/${ENV}/${LAMP_NAME}/*"
      ],
      "Action": [ 
          "s3:*"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::*",
      "Action": [
          "s3:ListAllMyBuckets"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [
          "arn:aws:s3:::${BACKUP_BUCKET}",
          "arn:aws:s3:::${BACKUP_BUCKET}/*"
      ],
      "Action": [
          "s3:GetBucket*", 
          "s3:List*" 
      ]
    }
  ]
}
EOH
end

coreo_aws_vpc_routetable "${LAMP_NAME}-routetable" do
  action :sustain
  vpc "${VPC_NAME}"
  number_of_tables 3
end

coreo_aws_vpc_subnet "${PRIVATE_SUBNET_NAME}" do
  action :sustain
  vpc "${VPC_NAME}"
  percent_of_vpc_allocated 25
  route_table "${LAMP_NAME}-routetable"
end

coreo_aws_iam_policy "${LAMP_NAME}-yum" do
  action :sustain
  policy_document <<-EOH
{
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
          "arn:aws:s3:::${YUM_REPO_BUCKET}",
          "arn:aws:s3:::${YUM_REPO_BUCKET}/*"
      ],
      "Action": [ 
          "s3:*"
      ]
    }
  ]
}
EOH
end

coreo_aws_iam_instance_profile "${LAMP_NAME}" do
  action :sustain
  policies ["${LAMP_NAME}-s3", "${LAMP_NAME}-route53", "${LAMP_NAME}-yum"]
end

coreo_aws_ec2_instance "${LAMP_NAME}" do
  action :define
  image_id "${LAMP_AMI}"
  size "${LAMP_SIZE}"
  security_groups ["${LAMP_NAME}"]
  role "${LAMP_NAME}"
  ssh_key "${LAMP_KEYPAIR}"
  disks [
            {
                :device_name => "/dev/xvda",
                :volume_size => 50
            }
        ]
end

coreo_aws_ec2_autoscaling "${LAMP_NAME}" do
  action :sustain
  minimum 1
  maximum 1
  server_definition "${LAMP_NAME}"
  subnet "${PRIVATE_SUBNET_NAME}"
end