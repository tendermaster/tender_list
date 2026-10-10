# frozen_string_literal: true

class BlogController < ApplicationController
  def index
    @posts = BlogPost.all
    set_public_cache(browser_ttl: 15.minutes, cdn_ttl: 1.hour)
  end

  def show
    @post = BlogPost.find(params[:slug])
    return render('home/page_404', status: :not_found) if @post.nil?

    set_public_cache(browser_ttl: 30.minutes, cdn_ttl: 6.hours)
  end
end
