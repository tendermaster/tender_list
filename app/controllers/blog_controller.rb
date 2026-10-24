# frozen_string_literal: true

class BlogController < ApplicationController
  def index
    @posts = BlogPost.all
    set_public_cache(cdn_ttl: 1.hour)
  end

  def show
    @post = BlogPost.find(params[:slug])
    return record_not_found if @post.nil?

    set_public_cache(cdn_ttl: 6.hours)
  end
end
