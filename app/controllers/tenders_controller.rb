class TendersController < ApplicationController
  before_action :set_tender, only: %i[ show edit update destroy ]
  # These forms render on session-less public pages, so there is no session to hold
  # a CSRF token; both are anonymous lead forms guarded by reCAPTCHA instead.
  skip_forgery_protection only: [:get_relevant_tenders_post, :checklist_download]
  include ApplicationHelper

  rescue_from TenderSearch::SearchUnavailableError,
              Elastic::Transport::Transport::Errors::ServiceUnavailable,
              Elastic::Transport::Transport::Errors::BadRequest,
              Elastic::Transport::Transport::Error,
              Faraday::ConnectionFailed,
              Faraday::TimeoutError,
              Errno::ECONNREFUSED,
              Net::ReadTimeout,
              Net::OpenTimeout,
              SocketError,
              with: :handle_search_unavailable

  def home
    # root
    @todays_tender = Rails.cache.fetch('home/todays_tender')
    if @todays_tender.nil?
      if CategoryService.home_keyword_list.include?('Ngo Services')
        @todays_tender = [CategoryService.home_keyword_list[0]] + CategoryService.home_keyword_list[1..] # .sample(17)
      else
        @todays_tender = CategoryService.home_keyword_list # .sample(21)
      end
      Rails.cache.write('home/todays_tender', @todays_tender, expires_in: 1.days)
    end
  end

  def search
    raw_query = params[:q] || params[:keyword]&.tr('-', ' ')
    return redirect_to root_path if raw_query.blank?

    # Pages past the last one are crawler traffic; there are no results there
    return record_not_found if params[:page].to_i > TenderSearch::MAX_PAGE

    @query = raw_query.to_s.strip
    @query_label = @query
    @filters = TenderSearch.filters_from(params)
    @min_value = params[:min_value].to_i
    @max_value = params[:max_value].to_i
    @max_value = 10**10 if @max_value <= 0

    SearchQueryLoggerJob.perform_later(@query) if current_user.present?

    if (page = KeywordPage.for(@query))
      @query = page.to_search_query
      @query_label = page.name
    end

    @pagy, @records, cache_hit, @total = TendersController.elastic_pagy(@query, params[:page], filters: @filters)

    if @records.blank?
      @fallback_tenders = Rails.cache.fetch('search:fallback_active_tenders', expires_in: 30.minutes) do
        Tender.where("submission_close_date > ?", Time.current)
              .where(is_visible: true)
              .order(id: :desc)
              .limit(5)
              .to_a
      end
    end

    @bookmarked_ids = bookmarked_ids_for(@records.presence || @fallback_tenders)
    response.headers['X-Cache'] = cache_hit ? 'HIT' : 'MISS'
    response.headers['X-Hits'] = @pagy.count.to_s

    # Enrich active OpenTelemetry trace span with search metadata
    if defined?(OpenTelemetry::Trace)
      current_span = OpenTelemetry::Trace.current_span
      if current_span&.recording?
        current_span.add_attributes({
          'search.query' => @query,
          'search.cache_hit' => !!cache_hit,
          'search.hits' => @pagy.count,
          'search.page' => params[:page].to_i
        })
      end
    end

    if @records.present?
      set_public_cache(cdn_ttl: 2.hours)
    else
      set_public_cache(cdn_ttl: 1.minute)
    end
  end

  def search_query

  end

  # GET /search/autocomplete?q=...
  def autocomplete
    query = params[:q].to_s.strip
    results = TenderSearch.autocomplete(query)
    render json: results
  end

  def tender_show
    @tender_data = Tender.find_by({ slug_uuid: params['slug_uuid'] })
    # p @tender_data
    if @tender_data.nil?
      # redirect_to(controller: :home, action: :not_found)
      redirect_to root_path
    else

      set_public_cache(cdn_ttl: 12.hours)
      # Parsed per request: cached copies of every crawled tender filled Redis
      @tender_json = (JSON.parse(@tender_data.full_data) rescue nil) if @tender_data.full_data.present?
      @tender_json ||= {}
      @bid_result = @tender_data.parsed_bid_result if @tender_data.has_bid_result?

      # similar_tenders caches the matching ids; the rows are read fresh
      @similar_tenders = TenderSearch.similar_tenders(@tender_data, @tender_data.id, limit: 10)
    end
  end

  def tender_like
    pp params
    pp current_user
    render plain: 'OK'
  end

  # def get_relevant_tenders_success
  #   @full_message = "Form Submitted Successfully"
  # end

  def get_relevant_tenders_post
    # pp params
    #   save to file

    # File.open('dev/get_relevant_tenders_post.txt', 'w') do |file|
    #   file.write("#{params['name']},#{params['email']},#{params['mobile']},#{params['sectors']}\n")
    # end

    # CSV.open("dev/get_relevant_tenders_post.txt", "a+") do |csv|
    #   csv << [params['name'],
    #           params['email'],
    #           params['mobile'],
    #           params['sectors'],
    #           current_time
    #   ]
    # end

    unless verify_captcha
      @full_message = "Please confirm you're not a robot and try again"
      return render 'get_relevant_tenders_success'
    end

    MiscDataStore.create!(
      name: 'customized_tender_recommendations',
      data: {
        name: params['name'],
        email: params['email'],
        mobile: params['mobile'],
        sectors: params['sectors'],
        time: current_time
      },
      source: 'sidebar'
    )

    # redirect_to action: :get_relevant_tenders_success
    @full_message = 'Form Submitted Successfully'
    render 'get_relevant_tenders_success'
  end

  def checklist_download
    # return render plain: params.to_json
    @full_message = 'Please Check your email (including spam folder) to download your files'

    unless verify_captcha
      @full_message = "Please confirm you're not a robot and try again"
      return render 'get_relevant_tenders_success'
    end

    unless params[:report_type].present?
      @full_message = 'Invalid report type'
      return render 'get_relevant_tenders_success'
    end

    unless params[:email].present?
      @full_message = 'Please specify email address'
      return render 'get_relevant_tenders_success'
    end

    # validate email
    email = params[:email]
    if email.match?(URI::MailTo::EMAIL_REGEXP)
      report_data = checklist_options('get_code', params[:report_type])

      MiscDataStore.create!(
        name: 'checklist_download',
        data: {
          full_name: params['full_name'],
          email: params['email'],
          phone: params['phone'],
          report_type: params['report_type'],
          time: current_time
        },
        source: 'homepage'
      )

      if ActionMailer::Base.perform_deliveries
        CheckListDownloaderMailer.send_check_list(params[:email], report_data).deliver_later
      else
        # Mail is off (MAIL_ENABLED): show the links instead of emailing them
        @report_data = report_data
        @full_message = "Your #{report_data[:label]} files are ready"
      end
    else
      @full_message = 'Please recheck your email'
    end
    render 'get_relevant_tenders_success'
  end

  def trending_tenders
    all_keywords = [CategoryService.home_keyword_list,
                    CategoryService.get_city_list,
                    CategoryService.get_sector_list,
                    CategoryService.get_organisation_list,
                    CategoryService.get_products_list,
                    CategoryService.get_state_list].flatten

    @pagy, @items = pagy_array(all_keywords, items: 15)
    render 'tender_category_by_sector'
  end

  def tender_main_category

  end

  def tender_category_by_city
    @pagy, @items = pagy_array(CategoryService.get_city_list, items: 15)
    render 'tender_category_by_sector'
  end

  def tender_category_by_state
    @pagy, @items = pagy_array(CategoryService.get_state_list, items: 15)
    render 'tender_category_by_sector'
  end

  def tender_category_by_sector
    @pagy, @items = pagy_array(CategoryService.get_sector_list, items: 15)
    render 'tender_category_by_sector'
  end

  def tender_by_organisation
    @pagy, @items = pagy_array(CategoryService.get_organisation_list, items: 15)
    render 'tender_category_by_sector'
  end

  def tender_by_products
    @pagy, @items = pagy_array(CategoryService.get_products_list, items: 15)
    render 'tender_category_by_sector'
  end

  # def state_page
  #   @query = params['state']
  #   @min_value = params['min_value'].to_i
  #   @max_value = params['max_value'].to_i
  #
  #   if @max_value == 0 then
  #     @max_value = 10 ** 10
  #   end
  #
  #   SearchQuery.create(query: @query)
  #
  #   p "searching #{@query}"
  #
  #   collection = TendersController.search_tender(@query, @min_value, @max_value)
  #
  #   @pagy, @records = pagy(collection, items: 5)
  #
  # end
  #
  # def sector_page
  #
  #   @query = params['sector']
  #   @min_value = params['min_value'].to_i
  #   @max_value = params['max_value'].to_i
  #
  #   if @max_value == 0 then
  #     @max_value = 10 ** 10
  #   end
  #
  #   SearchQuery.create(query: @query)
  #
  #   p "searching #{@query}"
  #
  #   collection = TendersController.search_tender(@query, @min_value, @max_value)
  #
  #   @pagy, @records = pagy(collection, items: 5)
  #
  # end

  # GET /tenders or /tenders.json
  # def index
  #   @tenders = Tender.all
  # end
  #
  # # GET /tenders/1 or /tenders/1.json
  # def show
  # end
  #
  # # GET /tenders/new
  # def new
  #   @tender = Tender.new
  # end
  #
  # # GET /tenders/1/edit
  # def edit
  # end
  #
  # # POST /tenders or /tenders.json
  # def create
  #   @tender = Tender.new(tender_params)
  #
  #   respond_to do |format|
  #     if @tender.save
  #       format.html { redirect_to tender_url(@tender), notice: 'Tender was successfully created.' }
  #       format.json { render :show, status: :created, location: @tender }
  #     else
  #       format.html { render :new, status: :unprocessable_entity }
  #       format.json { render json: @tender.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end
  #
  # # PATCH/PUT /tenders/1 or /tenders/1.json
  # def update
  #   respond_to do |format|
  #     if @tender.update(tender_params)
  #       format.html { redirect_to tender_url(@tender), notice: 'Tender was successfully updated.' }
  #       format.json { render :show, status: :ok, location: @tender }
  #     else
  #       format.html { render :edit, status: :unprocessable_entity }
  #       format.json { render json: @tender.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end
  #
  # # DELETE /tenders/1 or /tenders/1.json
  # def destroy
  #   @tender.destroy
  #
  #   respond_to do |format|
  #     format.html { redirect_to tenders_url, notice: 'Tender was successfully destroyed.' }
  #     format.json { head :no_content }
  #   end
  # end

  #   def self.search_tender(query, min_value, max_value)
  #     Tender.where([
  #                    "tenders.tender_text_vector @@ websearch_to_tsquery('english', ?)
  #   and (emd between ? and ? or emd is null)
  #   and (tender_value between ? and ? or tender_value is null)
  #   and (submission_close_date > now() AT TIME ZONE 'Asia/Kolkata' or true)
  #   and is_visible = true
  # ",
  #                    query,
  #                    min_value * 0.02,
  #                    max_value * 0.02,
  #                    min_value,
  #                    max_value
  #                  ]).order(submission_close_date: :desc)
  #   end
  def self.search_tender(query, min_value, max_value)
    Tender.where([
                   "tenders.tender_text_vector @@ websearch_to_tsquery('english', ?)
      and (emd between ? and ? or emd is null)
      and (tender_value between ? and ? or tender_value is null)
      and (submission_close_date > now() AT TIME ZONE 'Asia/Kolkata' or true)
      and is_visible = true
    ",
                   query,
                   min_value * 0.02,
                   max_value * 0.02,
                   min_value,
                   max_value
                 ]).order(submission_close_date: :desc)

    # ElasticClient.search(
    #   index: 'search-v2-sigmatenders',
    #   body: {
    #     query: {
    #       multi_match: {
    #         query: 'repair',
    #         "fields": ["public_tenders_tender_id", "public_tenders_title", "public_tenders_description", "public_tenders_organisation", "public_tenders_slug_uuid", "public_tenders_page_link", "public_tenders_state"]
    #       }
    #     },
    #     sort: [{
    #              "public_tenders_submission_close_date": "desc"
    #            }]
    #   }
    # )

    #   map to db
  end

  # http://localhost:3000/search?q=chartered+accountatn
  # https://ddnexus.github.io/pagy/docs/how-to/#paginate-non-activerecord-collections
  # http://localhost:5601/app/management/data/index_management/indices/index_details?indexName=search-v2-sigmatenders&tab=overview
  # problem: page set default 20 items
  # Pagy::DEFAULT
  # https://www.elastic.co/guide/en/elasticsearch/reference/current/full-text-queries.html
  # https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-simple-query-string-query.html
  #   long tail keywords
  #
  def self.elastic_pagy(query, page_number, filters: {})
    TenderSearch.weighted_search(query, page_number, filters: filters)
  end

  private

  def handle_search_unavailable(exception)
    response.headers['Retry-After'] = '30'
    response.headers['X-Search-Status'] = 'DEGRADED_503'
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'

    # Enrich active OpenTelemetry trace span with 503 error status
    if defined?(OpenTelemetry::Trace)
      current_span = OpenTelemetry::Trace.current_span
      if current_span&.recording?
        current_span.status = OpenTelemetry::Trace::Status.error("Search backend unavailable: #{exception.message}")
        current_span.add_attributes({ 'search.status' => '503_service_unavailable' })
      end
    end

    respond_to do |format|
      format.html { render 'home/page_503', status: :service_unavailable }
      format.json { render json: { error: 'Search service temporarily unavailable', retry_after: 30 }, status: :service_unavailable }
    end
  end
end
