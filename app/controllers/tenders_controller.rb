class TendersController < ApplicationController
  before_action :set_tender, only: %i[ show edit update destroy ]

  def home
    #   root
  end

  def search
    # Tender.reindex
    @query = params['q']
    @min_value = params['min_value'].to_i
    @max_value = params['max_value'].to_i

    if @max_value == 0 then
      @max_value = 10 ** 10
    end

    SearchQuery.create(query: @query)

    # if @query.nil? || (@query == '*') || @query == ""
    #   @query = ' '
    # end

    p "searching #{@query}"

    # @search_result = Tender.where("search_data like ?", "%#{@query}%").limit(10)

    # @pagy, @records = pagy(Tender.where('search_data ilike ? and is_visible = true', "%#{@query}%"), items: 5, request_path: search_path)
    # p params, @query

    collection = Tender.where([
                                "(tenders.tsvector_index @@ websearch_to_tsquery('english', ?)
    or tenders.id in (select tender_id
                      from attachments
                      where file_text @@ websearch_to_tsquery('english', ?)))
  and (emd between ? and ? or emd is null)
  and (tender_value between ? and ? or tender_value is null)
  and (submission_close_date > now() AT TIME ZONE 'Asia/Kolkata')
",
                                @query,
                                @query,
                                @min_value * 0.02,
                                @max_value * 0.02,
                                @min_value,
                                @max_value
                              ])

    @pagy, @records = pagy(collection, items: 5)

    # collection = Tender.pagy_search(
    #   @query,
    #   where: {
    #     submission_close_date: {gt: Time.now},
    #     _or: [
    #       { emd: { gte: @min_value * 0.02, lte: @max_value * 0.02 } },
    #       { tender_value: { gte: @min_value, lte: @max_value } }
    #     ]
    #   },
    #   boost_where: {
    #     tenderId: { factor: 5 },
    #     title: { factor: 5 },
    #     description: { factor: 5 },
    #     organisation: { factor: 5 },
    #     state: { factor: 5 }
    #   }
    # )
    #
    # @pagy, @records = pagy_searchkick(collection, items: 1)

  end

  def tender_show
    # p params
    # render locals: {
    #   params: params
    # }
    # @tender_data = Tender.first

    @tender_data = Tender.find_by({ slug_uuid: params['slug_uuid'] })
    # p @tender_data
    if @tender_data.nil?
      redirect_to(controller: :home, action: :not_found)
    else
      @tender_json = JSON.parse(@tender_data.full_data)
    end

    # render :html => params
  end

  def state_page
    @query = params['state']

    @query = ' ' if @query.nil? || (@query == '*')

    p "searching #{@query}"

    collection = Tender.pagy_search(@query, where: {
      submission_close_date: { gt: Time.now }
    })
    @pagy, @records = pagy_searchkick(collection, items: 5)

  end

  def sector_page

    @query = params['sector']

    @query = ' ' if @query.nil? || (@query == '*')

    p "searching #{@query}"

    collection = Tender.pagy_search(@query, where: {
      submission_close_date: { gt: Time.now }
    })
    @pagy, @records = pagy_searchkick(collection, items: 5)

  end

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

  # private
  #
  # # Use callbacks to share common setup or constraints between actions.
  # def set_tender
  #   @tender = Tender.find(params[:id])
  # end
  #
  # # Only allow a list of trusted parameters through.
  # def tender_params
  #   params.require(:tender).permit(:tenderId, :title, :description, :organisation, :state, :tender_value, :submission_open_date, :submission_close_date, :attachments_id, :search_data)
  # end

end
