class Tag < ActiveRecord::Base
  TAGABLE_PAGINATION_LIMIT = 20

  has_many :taggings

  # create associations for all tagable classes
  # ie: tag#entities, tag#lists, tag#relationships, etc...
  Tagable.classes.each do |klass|
    has_many klass.category_sym, through: :taggings, source: :tagable, source_type: klass
  end

  validates :name, uniqueness: true, presence: true
  validates :description, presence: true

  # CLASS METHODS

  # (set, set) -> hash
  def self.parse_update_actions(client_ids, server_ids)
    {
      ignore: client_ids & server_ids,
      add: client_ids - server_ids,
      remove: server_ids - client_ids
    }
  end

  # String -> [Tag]
  def self.search_by_names(phrase)
    Tag.lookup.keys
      .select { |tag_name| phrase.downcase.include?(tag_name) }
      .map { |tag_name| lookup[tag_name] }
  end

  # String -> Tag | Nil
  # Search through tags find tag by name
  def self.search_by_name(query)
    lookup[query.downcase]
  end

  def self.lookup
    @lookup ||= Tag.all.reduce({}) do |acc, tag|
      acc.tap { |h| h.store(tag.name.downcase.tr('-', ' '), tag) }
    end
  end

  # INSTANCE METHODS

  def restricted?
    restricted
  end

  def tagables_for_homepage(tagable_category, page = 1)
    return entities_for_homepage(page) if tagable_category == Entity.category_str
    default_tagables_for_homepage(tagable_category, page)
  end

  def default_tagables_for_homepage(tagable_category, page = 1)
    public_send(tagable_category.to_sym)
      .order(updated_at: :desc)
      .page(page)
      .per(TAGABLE_PAGINATION_LIMIT)
  end

  def entities_for_homepage(page = 1)
    Kaminari
      .paginate_array(entities_with_tagged_relationship_counts, total_count: entities.count)
      .page(page)
      .per(TAGABLE_PAGINATION_LIMIT)
  end

  def entities_with_tagged_relationship_counts(page = 1)
    raise ArgumentError unless page.is_a? Integer
    # * first, we join on *both* entity1_id and entity2_id and filter out rows w/o both ids so that
    # our result set will only include taggings in which both elements in a relationship are tagged
    # * then we append entities with no relationships
    # * finally (outside sub-query) we sort and paginate
    sql = <<-SQL
      SELECT * FROM (
         SELECT entity1_id, count(*) as related_tagged_entities
         FROM link
         LEFT JOIN taggings as e1t on e1t.tagable_id = link.entity1_id AND e1t.tagable_class = 'Entity' AND e1t.tag_id = #{id}
         LEFT JOIN taggings as e2t on e2t.tagable_id = link.entity2_id AND e2t.tagable_class = 'Entity' AND e2t.tag_id = #{id}
         WHERE e1t.id is not null AND e2t.id is not null
         GROUP BY entity1_id

         UNION

         SELECT tagable_id as entity1_id, 0 as related_tagged_entities
         FROM taggings
         INNER JOIN entity ON taggings.tagable_id = entity.id 
         WHERE taggings.tagable_class = 'Entity' AND taggings.tag_id = #{id}
               AND entity.link_count = 0

     ) as entity_counts

     INNER JOIN entity on entity_counts.entity1_id = entity.id
     ORDER BY entity_counts.related_tagged_entities desc
     LIMIT #{TAGABLE_PAGINATION_LIMIT}
     OFFSET #{(page - 1) * TAGABLE_PAGINATION_LIMIT}
    SQL

    Entity.find_by_sql(sql)
  end
end
