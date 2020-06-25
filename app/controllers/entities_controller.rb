# frozen_string_literal: true

class EntitiesController < ApplicationController
  include TagableController
  include ReferenceableController

  ERRORS = ActiveSupport::HashWithIndifferentAccess.new(
    create_bulk: {
      errors: [{ 'title' => 'Could not create new entities: request formatted improperly' }]
    }
  )

  TABS = %w[interlocks political giving datatable].freeze

  EDITABLE_ACTIONS = %i[create update destroy create_bulk match_donation add_to_list].freeze
  IMPORTER_ACTIONS = %i[match_donation match_donations review_donations match_ny_donations review_ny_donations].freeze

  before_action :authenticate_user!, except: [:show, :datatable, :political, :contributions, :references, :interlocks, :giving, :validate]
  before_action :block_restricted_user_access, only: [:new, :create, :update, :create_bulk]
  before_action -> { current_user.raise_unless_can_edit! }, only: EDITABLE_ACTIONS
  before_action :importers_only, only: IMPORTER_ACTIONS
  before_action :set_entity, except: [:new, :create, :show, :create_bulk, :validate]
  before_action :set_entity_for_profile_page, only: [:show]
  before_action :check_delete_permission, only: [:destroy]

  ## Profile Page Tabs:
  # (consider moving these all to #show route)
  def show
    @active_tab = :relationships
  end

  def interlocks
    @active_tab = :interlocks
    render 'show'
  end

  def giving
    @active_tab = :giving
    render 'show'
  end

  def political
  end

  # THE DATA 'tab'
  def datatable
  end

  def create_bulk
    # only responds to JSON, not possible to create extensions in POSTS to this endpoint
    entity_attrs = create_bulk_payload.map { |x| merge_last_user(x) }
    block_unless_bulker(entity_attrs, Entity::BULK_LIMIT) # see application_controller
    entities = Entity.create!(entity_attrs)
    render json: Api.as_api_json(entities), status: :created
  rescue ActionController::ParameterMissing, NoMethodError, ActiveRecord::RecordInvalid
    render json: ERRORS[:create_bulk], status: 400
  end

  def new
    @entity = Entity.new(name: params[:name]) if params[:name].present?
  end

  def create
    @entity = Entity.new(new_entity_params)

    if @entity.save # successfully created entity
      params[:types].each { |type| @entity.add_extension(type) } if params[:types].present?

      if wants_json_response?
        render json: {
                 status: 'OK',
                 entity: {
                   id: @entity.id,
                   name: @entity.name,
                   description: @entity.blurb,
                   url: @entity.url,
                   primary_ext: @entity.primary_ext
                 }
               }
      else
        redirect_to edit_entity_path(@entity)
      end

    else # encounted error

      if wants_json_response?
        render json: { status: 'ERROR', errors: @entity.errors.messages }
      else
        render action: 'new'
      end

    end
  end

  def edit
    set_entity_references
  end

  def update
    # assign new attributes to the entity
    @entity.assign_attributes(prepare_params(update_entity_params))
    # if those attributes are valid
    # update the entity extension records  and save the reference
    if @entity.valid?
      @entity.update_extension_records(extension_def_ids)
      @entity.add_reference(reference_params) if need_to_create_new_reference
      # Add_reference will make the entity invalid if the reference is invalid
      if @entity.valid?
        @entity.save!
        return render json: { status: 'OK' } if api_request?
        return redirect_to entity_path(@entity)
      end
    end
    set_entity_references
    render :edit
  end

  def destroy
    @entity.soft_delete
    redirect_to home_dashboard_path, notice: "#{@entity.name} has been successfully deleted"
  end

  def add_relationship
    @relationship = Relationship.new
    @reference = Reference.new
  end

  def add_to_list
    list = List.find(params[:list_id])
    raise Exceptions::PermissionError unless list.user_can_edit?(current_user)

    ListEntity.add_to_list!(list_id: list.id,
                            entity_id: @entity.id,
                            current_user: current_user)

    flash[:notice] = "Added to list '#{list.name}'"
    redirect_to entity_path(@entity)
  end

  def references
    @page = params[:page].present? ? params[:page] : 1
  end

  # ------------------------------ #
  # Open Secrets Donation Matching #
  # ------------------------------ #

  def match_donations
  end

  def review_donations
  end

  def match_donation
    params[:payload].each do |donation_id|
      match = OsMatch.find_or_create_by(os_donation_id: donation_id, donor_id: params[:id])
      match.update(matched_by: current_user.id)
    end
    @entity.update(last_user_id: current_user.id)
    render json: { status: 'ok' }
  end

  def unmatch_donation
    check_permission 'importer'
    params[:payload].each do |os_match_id|
      OsMatch.find(os_match_id).destroy
    end
    @entity.update(last_user_id: current_user.id)
    render json: { status: 'ok' }
  end

  # ------------------------------ #
  # Open Secrets Contributions     #
  # ------------------------------ #

  def contributions
    expires_in(5.minutes, public: true)
    render json: @entity.contribution_info
  end

  def potential_contributions
    render json: @entity.potential_contributions
  end

  # ------------------------------ #
  # NYS Donation Matching          #
  # ------------------------------ #

  def match_ny_donations
  end

  def review_ny_donations
  end

  def fields
    @fields = JSON.dump(Field.all.map { |f| { value: f.name, tokens: f.display_name.split(/\s+/) } });
  end

  def update_fields
    if params[:names].nil? and params[:values].nil?
      fields = {}
    else
      fields = Hash[params[:names].zip(params[:values])]
    end
    @entity.update_fields(fields)
    Field.delete_unused
    redirect_to fields_entity_path(@entity)
  end

  ##
  # images
  #

  def images
    check_permission 'contributor'
  end

  def feature_image
    image = Image.find(params[:image_id])
    image.feature
    redirect_to images_entity_path(@entity)
  end

  def remove_image
    image = Image.find(params[:image_id])
    image.destroy
    redirect_to images_entity_path(@entity)
  end

  def new_image
    @image = Image.new
    @image.entity = @entity
  end

  def upload_image
    if image_params[:file]
      @image = Image.new_from_upload(image_params[:file])
    elsif image_params[:url]
      @image = Image.new_from_url(image_params[:url])
    else
      return head :bad_request
    end

    # TODO: handle error if @image doesn't exist?

    @image.assign_attributes(entity: @entity,
                             is_free: cast_to_boolean(image_params[:is_free]),
                             caption: image_params[:caption])
    if @image.save
      @image.feature if cast_to_boolean(image_params[:is_featured])
      redirect_to images_entity_path(@entity), notice: 'Image was successfully created.'
    else
      render action: 'new_image', notice: 'Failed to add the image :('
    end
  end

  def validate
    entity = Entity.new(validate_entity_params)
    entity.valid?
    render json: entity.errors.to_json
  end

  private

  def set_entity_for_profile_page
    set_entity(:profile_scope)
  end

  def set_entity_references
    @references = @entity.references.order('updated_at desc').limit(10)
  end

  def image_params
    params.require(:image).permit(:file, :caption, :url, :is_free, :is_featured)
  end

  def update_entity_params
    params.require(:entity).permit(
      :name, :blurb, :summary, :website, :start_date, :end_date, :is_current,
      person_attributes: [:name_first, :name_middle, :name_last, :name_prefix, :name_suffix, :name_nick, :birthplace, :gender_id, :id ],
      public_company_attributes: [:ticker, :id],
      school_attributes: [:is_private, :id],
      business_attributes: [:id, :annual_profit, :assets, :marketcap, :net_income]
    )
  end

  # output: [Int] or nil
  def extension_def_ids
    if params.require(:entity).key?(:extension_def_ids)
      return params.require(:entity).fetch(:extension_def_ids).split(',').map(&:to_i)
    end
  end

  def new_entity_params
    LsHash.new(params.require(:entity).permit(:name, :blurb, :primary_ext).to_h)
      .with_last_user(current_user)
      .nilify_blank_vals
  end

  def validate_entity_params
    params.require(:entity)
      .permit(:name, :blurb, :primary_ext)
  end

  def create_bulk_payload
    params.require('data')
      .map { |r| r.permit('attributes' => %w[name blurb primary_ext])['attributes'] }
  end

  def wants_json_response?
    params[:add_relationship_page].present? || params[:external_entity_page].present?
  end

  def importers_only
    check_permission 'importer'
  end

  def check_delete_permission
    unless current_user.permissions.entity_permissions(@entity).fetch(:deleteable)
      raise Exceptions::PermissionError
    end
  end
end
