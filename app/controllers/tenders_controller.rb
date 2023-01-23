class TendersController < ApplicationController
  before_action :set_tender, only: %i[ show edit update destroy ]

  # GET /tenders or /tenders.json
  def index
    @tenders = Tender.all
  end

  def home
  #   root
  end

  def search
    @query = params['q'] || ' '

    # @search_result = Tender.where("search_data like ?", "%#{@query}%").limit(10)

    @pagy, @records = pagy(Tender.where("search_data ilike ? and is_visible = true", "%#{@query}%"), items: 5, request_path: search_path)
    # p params, @query

  end

  def tender_show
    p params
    # render locals: {
    #   params: params
    # }
    # @tender_data = Tender.first

    @tender_data = Tender.find_by({ slug_uuid: params['slug_uuid'] })
    p @tender_data
    if @tender_data.nil?
      redirect_to(controller: :home, action: :not_found)
    else
      @tender_json = JSON.parse(@tender_data.full_data)
    end

    # render :html => params
  end

  def time_left(time)
    time.is_a?(ActiveSupport::TimeWithZone) ? "#{distance_of_time_in_words(Date.today, time, true, highest_measure_only: true)} left" : '-'
    #   result.submission_close_date.is_a?(ActiveSupport::TimeWithZone) ? "#{distance_of_time_in_words(Date.today,result.submission_close_date, true, highest_measure_only: true)} left" : '-'
  end
  helper_method :time_left

  # GET /tenders/1 or /tenders/1.json
  def show
  end

  # GET /tenders/new
  def new
    @tender = Tender.new
  end

  # GET /tenders/1/edit
  def edit
  end

  # POST /tenders or /tenders.json
  def create
    @tender = Tender.new(tender_params)

    respond_to do |format|
      if @tender.save
        format.html { redirect_to tender_url(@tender), notice: "Tender was successfully created." }
        format.json { render :show, status: :created, location: @tender }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @tender.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tenders/1 or /tenders/1.json
  def update
    respond_to do |format|
      if @tender.update(tender_params)
        format.html { redirect_to tender_url(@tender), notice: "Tender was successfully updated." }
        format.json { render :show, status: :ok, location: @tender }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @tender.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tenders/1 or /tenders/1.json
  def destroy
    @tender.destroy

    respond_to do |format|
      format.html { redirect_to tenders_url, notice: "Tender was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_tender
    @tender = Tender.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def tender_params
    params.require(:tender).permit(:tenderId, :title, :description, :organisation, :state, :tender_value, :submission_open_date, :submission_close_date, :attachments_id, :search_data)
  end


end
