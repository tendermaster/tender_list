# frozen_string_literal: true

require 'httparty'

class ApiController < ActionController::API
  # include ApplicationHelper

  def download_file_get
    render plain: 'v1'
  end

  def generate_file_url(file_path, file_name)
    Signer.presigned_url(
      :get_object,
      bucket: 'sigmatenders',
      key: 'dev/' + file_path,
      expires_in: 10 * 60,
      response_content_disposition: "attachment;filename=#{file_name}"
    )
    # "a"
  rescue Aws::Errors::ServiceError => e
    puts "Couldn't create presigned URL for #{bucket.name}:#{object_key}. Here's why: #{e.message}"
  end

  def download_file
    # verify recaptacha and check file existence
    # recaptacha
    response = HTTParty.post('https://www.google.com/recaptcha/api/siteverify', body: {
      secret: ENV['RECAPTCHA_SECRET_KEY'],
      response: params['token']
    })
    # pp response
    if response['success'] && response['score'].to_f > 0.5 && response['action'] == 'download_file'
      #   send s3 url
      file_path = params['file_path']
      begin
        file_name = Attachment.find_by({ file_path: file_path })&.file_name
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false
        }
      end
      signed_url = self.generate_file_url(file_path, file_name)

      render json: {
        success: true,
        download_url: signed_url
      }
    else
      render json: {
        success: false
      }
    end

    # pp response

    # pp params['file_path']
    # render plain: params['file_path']
    # signed_url = helpers.generate_file_url(params['file_path'])
    # redirect_to signed_url, allow_other_host: true
    # render plain: response
  end
end
