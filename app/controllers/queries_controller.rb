class QueriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_query, only: %i[ show edit update destroy ]

  # GET /queries or /queries.json
  def index
    # @queries = Query.all
    @queries = current_user.query
  end

  def query_result
    @query_id = params['query_id'].to_i
    @saved_query = current_user.query.find(@query_id)
    @query_string = QueriesController.get_query_string(@saved_query)
    pp @query_string

    @min_value = params['min_value'].to_i
    @max_value = params['max_value'].to_i

    @max_value = 10 ** 10 if @max_value == 0

    # collection = TendersController.search_tender(@query_string, @min_value, @max_value)
    @pagy, @records = TendersController.elastic_pagy(@query_string, params[:page])

    # @pagy, @records = pagy(collection, items: 5)
    @query = @query_string
    @query_label = @saved_query.name.presence || @query_string
    render 'tenders/search'
  end

  def self.get_query_string(saved_query)
    include_query = saved_query.include_keyword.split(',').map { |e| "(#{e.squish})" }.join(' | ')
    exclude_query = saved_query.exclude_keyword.split(',').map { |e| "-(#{e.squish.gsub(' ', '\\ ')})" }.join(' ')
    query_string = "#{include_query} #{exclude_query}"
    query_string
  end

  # GET /queries/1 or /queries/1.json
  def show
  end

  # GET /queries/new
  def new
    @query = Query.new
  end

  # GET /queries/1/edit
  def edit
  end

  # POST /queries or /queries.json
  def create
    @query = Query.new(query_params.merge(user_id: current_user.id))

    respond_to do |format|
      if @query.save
        format.html { redirect_to queries_url, notice: "Query was successfully created." }
        # format.json { render :show, status: :created, location: @query }
      else
        format.html { render :new, status: :unprocessable_entity }
        # format.json { render json: @query.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /queries/1 or /queries/1.json
  def update
    respond_to do |format|
      if @query.update(query_params.merge(user_id: current_user.id))
        format.html { redirect_to queries_url, notice: "Query was successfully updated." }
        # format.json { render :show, status: :ok, location: @query }
      else
        format.html { render :edit, status: :unprocessable_entity }
        # format.json { render json: @query.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /queries/1 or /queries/1.json
  def destroy
    @query.destroy

    respond_to do |format|
      format.html { redirect_to queries_url, notice: "Query was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def redeem

  end

  def redeem_coupon
    coupon_code = params['coupon_code']
    res = User.redeem_coupon(current_user, coupon_code)
    if res[:ok]
      flash[:success] = res[:message]
    else
      flash[:error] = res[:message]
    end
    redirect_to url_for(redeem)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_query
    @query = current_user.query.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def query_params
    params.require(:query).permit(:name, :include_keyword, :exclude_keyword, :updates)
  end
end
