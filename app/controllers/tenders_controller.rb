class TendersController < ApplicationController
  before_action :set_tender, only: %i[ show edit update destroy ]
  before_action :authenticate_user!, only: [:bookmark_tender]

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

    # Tender.reindex
    @query = params['q'] || params['keyword'].gsub('-', ' ')
    @min_value = params['min_value'].to_i
    @max_value = params['max_value'].to_i

    @max_value = 10 ** 10 if @max_value == 0

    SearchQuery.create(query: @query)

    p "searching #{@query}"
    # p params
    # collection = TendersController.search_tender(@query, @min_value, @max_value)
    @pagy, @records = TendersController.elastic_pagy(@query, params[:page])

  end

  def search_query

  end

  def tender_show
    @tender_data = Tender.find_by({ slug_uuid: params['slug_uuid'] })
    # p @tender_data
    if @tender_data.nil?
      # redirect_to(controller: :home, action: :not_found)
      redirect_to root_path
    else
      @tender_json = JSON.parse(@tender_data.full_data)
    end
  end

  def bookmark_tender
    # TODO: complete bookmark
    # with turbo
    #
    # tender = Tender.find_by(slug_uuid: params[:slug_uuid])
    # if tender.present? && current_user.present?
    #   bookmark = Bookmark.find(user_id: current_user.id, tender_id: tender.id).count
    #   if bookmark
    #     bookmark.destroy!
    #     render json: { message: 'removed bookmark' }
    #   else
    #     Bookmark.create!(user_id: current_user.id, tender_id: tender.id)
    #     render json: { message: 'bookmarked tender' }
    #     format.turbo_stream { render turbo_stream: turbo_stream.replace('#test_id', 'ss') }
    #   end
    # end
    # render json: { error: 'unable to bookmark' }, status: :unprocessable_entity
  end

  def tender_like
    pp params
    pp current_user
    render plain: 'OK'
  end

  def get_relevant_tenders
  end

  def get_relevant_tenders_success

  end

  def get_relevant_tenders_post
    # pp params
    #   save to file

    # File.open('dev/get_relevant_tenders_post.txt', 'w') do |file|
    #   file.write("#{params['name']},#{params['email']},#{params['mobile']},#{params['sectors']}\n")
    # end

    current_time = TZInfo::Timezone.get('Asia/Kolkata').now.strftime("%d-%b-%Y %I:%M %p")
    # CSV.open("dev/get_relevant_tenders_post.txt", "a+") do |csv|
    #   csv << [params['name'],
    #           params['email'],
    #           params['mobile'],
    #           params['sectors'],
    #           current_time
    #   ]
    # end

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

    redirect_to action: :get_relevant_tenders_success
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
  def self.elastic_pagy(query, page_number)
    items_per_page = 5
    if page_number.nil?
      offset = 0
    else
      offset = (page_number.to_i - 1) * items_per_page
    end
    begin
      results = ElasticClient.search(
        index: 'cdc_pg_tenders.public.tenders',
        body: {
          query: {
            simple_query_string: {
              query: query,
              "default_operator": "and",
              "fields": ["after.tender_id", "after.title^3", "after.description^3", "after.organisation^2", "after.short_blog^2", "after.slug_uuid", "after.page_link", "after.state^2"]
            }
          },
          sort: [{
                   "after.submission_close_date": "desc"
                 }],
          size: items_per_page,
          from: offset
        }
      )
    rescue Elastic::Transport::Transport::Errors::BadRequest
      raise ActiveRecord::RecordNotFound
    end
    total = results['hits']['total']['value']

    pagy = Pagy.new(count: total, page: page_number, items: 5)
    db_records = results['hits']['hits'].map do |item|
      item['_source']['after']['id']
    end
    results = Tender.find(db_records)
    [pagy, results]
  end

  def self.similar_tenders(query, exclude_id)
    query = query.squish
    p "searching: #{query}"
    results = ElasticClient.search(
      index: 'cdc_pg_tenders.public.tenders',
      body: {
        "query": {
          "function_score": {
            "query": {
              "bool": {
                "must": {
                  "more_like_this": {
                    "fields": [
                      "after.title",
                      "after.description",
                      "after.short_blog"
                    ],
                    "like": query,
                    "min_term_freq": 1,
                    "max_query_terms": 25
                  }
                },
                "must_not": [
                  {
                    "term": {
                      "db_id": {
                        "value": exclude_id
                      }
                    }
                  }
                ]
              }
            },
            "min_score": 1
          }
        },
        "size": 10,
        "sort": [
          {
            "after.submission_close_date": {
              "order": "desc"
            }
          }
        ]
      })
    db_records = results['hits']['hits'].map do |item|
      item['_source']['after']['id']
    end
    results = Tender.find(db_records)
    results
  end

  private

  #
  # # Use callbacks to share common setup or constraints between actions.
  # def set_tender
  #   @tender = Tender.find(params[:id])
  # end
  #
  # # Only allow a list of trusted parameters through.
  # def tender_params
  #   params.require(:tender).permit(:tender_id, :title, :description, :organisation, :state, :tender_value, :submission_open_date, :submission_close_date, :attachments_id, :search_data)
  # end
end
