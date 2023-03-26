class QueriesController < ApplicationController
  before_action :set_query, only: %i[ show edit update destroy ]
  before_action :authenticate_user!

  # GET /queries or /queries.json
  def index
    # @queries = Query.all
    @queries = current_user.query
  end

  def query_result
    @query_id = params['query_id'].to_i
    @query = current_user.query.find(@query_id)

    @query_string = "#{@query.include_keyword.split(',').map { |word| "\"#{word.strip}\"" }.join(' ')} #{@query.exclude_keyword&.split(',').map { |word| "-\"#{word.strip}\"" }.join(' ')}"

    @min_value = params['min_value'].to_i
    @max_value = params['max_value'].to_i

    if @max_value == 0 then
      @max_value = 10 ** 10
    end

    collection = TendersController.search_tender(@query_string, @min_value, @max_value)

    @pagy, @records = pagy(collection, items: 5)
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

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_query
    @query = current_user.query.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def query_params
    params.require(:query).permit(:name, :include_keyword, :exclude_keyword)
  end
end
