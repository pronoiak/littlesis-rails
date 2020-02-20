# frozen_string_literal: true

class EntityConnectionsQuery
  PER_PAGE = 10

  def initialize(entity)
    @entity = Entity.entity_for(entity)
    @category_id = nil
    @page = 1
    @per_page = PER_PAGE
  end

  def category(category_id)
    @category_id = category_id&.to_i

    unless @category_id.nil? || (1..12).cover?(category_id)
      raise Exceptions::InvalidRelationshipCategoryError
    end

    self
  end

  def page(page)
    @page = page.to_i
    self
  end

  def per(per_amount)
    @per_page = per_amount.to_i
    self
  end

  def run
    Entity
      .joins(:links)
      .where('link.entity2_id = ?', @entity.id)
      .where(@category_id ? "link.category_id = #{@category_id}" : nil)
      .order(link_count: :desc)
      .page(@page)
      .per(PER_PAGE)
  end
end
