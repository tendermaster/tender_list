# frozen_string_literal: true
require 'aws-sdk-s3'

cred = {
  region: 'ap-south-1',
  access_key_id: ENV['AWS_ACCESS_KEY_ID'],
  secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
}.freeze

s3_client = Aws::S3::Client.new(
  cred
)

# https://stackoverflow.com/questions/59167380/using-aws-sdk-s3-ruby-to-generate-a-presigned-url
# https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Presigner.html

Signer = Aws::S3::Presigner.new(client: s3_client)
# signer.presigned_url(
#   :get_object,
#   bucket: 'sigmatenders',
#   key: "gem-bid.pdf",
#   expires_in: 10 * 60
# )

