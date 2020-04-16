# frozen_string_literal: true

# Oligrapher 3 API endpoints
#
# MapsController is used for Oligrapher 2 endpoints
# and the html pages for Oligrapher 2 and 3
class OligrapherController < ApplicationController
  include MapsHelper

  skip_before_action :verify_authenticity_token if Rails.env.development?

  before_action :authenticate_user!, except: %i[find_nodes find_connections get_edges]
  before_action :set_map, only: %i[update get_editors editors show lock]
  before_action :check_owner, only: %i[update get_editors editors]
  before_action :set_oligrapher_version

  before_action :admins_only if Rails.env.production?

  # Crud actions

  # POST /oligrapher
  #  { graph_data: {...}, attributes: { title, description, is_private, is_cloneable } }
  def create
    save_and_render NetworkMap.new(new_oligrapher_params)
  end

  def update
    @map.assign_attributes(oligrapher_params)
    save_and_render @map
  end

  def new
    @map = NetworkMap.new(version: 3, title: 'Untitled Map', user: current_user)
    @configuration = Oligrapher.configuration(map: @map, current_user: current_user)
    render 'oligrapher/new', layout: 'oligrapher3'
  end

  def get_editors
    render json: @map.usernames
  end

  # two actions { editor: { action: add | remove, username: <username> } }
  def editors
    action = params.require(:editor).require(:action).downcase
    username = params.require(:editor).require(:username)

    unless %w[add remove].include? action
      raise Exceptions::LittleSisError, "Invalid oligrapher editor action: #{action}"
    end

    unless (editor = User.find_by(username: username))
      raise Exceptions::LittleSisError, "No user found with username #{username}"
    end

    @map.public_send("#{action}_editor", editor).save
    render json: { editors: @map.usernames }
  end

  # a POST request is how a user can "takeover" a locked map
  # A GET request does lock polling
  def lock
    check_private_access
    raise Exceptions::PermissionError unless @map.editors.include?(current_user.id)

    lock_service = ::OligrapherLockService.new(map: @map, current_user: current_user)
    lock_service.lock! if request.post? || lock_service.user_can_lock?
    render json: lock_service.as_json
  end

  # Pages

  def show
    check_private_access
    @configuration = Oligrapher.configuration(map: @map, current_user: current_user)
    render 'oligrapher/oligrapher', layout: 'oligrapher3'
  end

  def example
    render 'oligrapher/example', layout: 'oligrapher3'
  end

  # Search Api
  # Oligrapher 3 also uses our regular api routes
  def find_nodes
    return head :bad_request if params[:q].blank?

    entities = EntitySearchService
                 .new(query: params[:q],
                      fields: %w[name aliases blurb],
                      per_page: params.fetch(:num, 10).to_i)
                 .search
                 .map(&Oligrapher::Node.method(:from_entity))

    render json: entities
  end

  def find_connections
    return head :bad_request if params[:entity_id].blank?

    entity = Entity.find(params[:entity_id])

    entities = EntityConnectionsQuery
      .new(entity)
      .category(params[:category_id])
      .page(1)
      .per(params.fetch(:num, 10))
      .run
      .map { |e|
        node = Oligrapher::Node.from_entity(e)
        node[:edge] = Oligrapher.rel_to_edge(Relationship.find(e.relationship_id))
        node
      }

    render json: entities
  end

  def get_edges
    return head :bad_request if params[:entity1_id].blank?
    return head :bad_request if params[:entity2_ids].blank?

    rel_ids = Link
      .where(entity1_id: params[:entity1_id].to_i)
      .where(entity2_id: params[:entity2_ids].split(','))
      .pluck(:relationship_id)
    
    edges = Relationship.find(rel_ids).map(&Oligrapher.method(:rel_to_edge))

    render json: edges
  end

  private

  def new_oligrapher_params
    oligrapher_params.merge!(oligrapher_version: 3, user_id: current_user.id)
  end

  def oligrapher_params
    params
      .require(:attributes)
      .permit(:title, :description, :is_private, :is_cloneable, :list_sources)
      .to_h
      .merge(graph_data: params[:graph_data]&.permit!&.to_h)
  end

  def set_oligrapher_version
    @oligrapher_version = Oligrapher::VERSION
  end
end

# Should we have some sort of GraphData validation?
#    OligrapherGraphData.new(params[:graph_data]).verify!
