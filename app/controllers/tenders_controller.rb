class TendersController < ApplicationController
  before_action :set_tender, only: %i[ show edit update destroy ]
  before_action :authenticate_user!, only: [:bookmark_tender]

  def home
    #   root
  end

  def search

    # Tender.reindex
    @query = params['q'] || params['keyword'].gsub('-', ' ')
    @min_value = params['min_value'].to_i
    @max_value = params['max_value'].to_i

    if @max_value == 0 then
      @max_value = 10 ** 10
    end

    SearchQuery.create(query: @query)

    p "searching #{@query}"

    collection = TendersController.search_tender(@query, @min_value, @max_value)

    @pagy, @records = pagy(collection, items: 5)

  end

  # TODO: complete recommendation
  def recommend_tender(keywords)
    # fix space in query: cctv delhi recommend
    #     query = keywords.split(' ').join(' or ')
    #
    #     Tenders.select()
    #
    #     @recommended_tenders = ActiveRecord::Base.connection.execute(['select id, title, ts_rank_cd(tenders.tender_text_vector, query) as rank
    # from tenders,
    #      websearch_to_tsquery(?) query
    # where query @@ tender_text_vector
    # limit 100', query])
  end

  helper_method :recommend_tender

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

  def trending_tenders

  end

  def get_relevant_tenders
  end

  def get_relevant_tenders_success

  end

  def get_relevant_tenders_post
    pp params
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

  def tender_main_category

  end

  def tender_category_by_city

  end

  def tender_category_by_state

  end

  def tender_category_by_organization

  end

  def tender_category_by_sector
    @pagy, @items = pagy_array(helpers.get_sector_list, items: 15)
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
