# frozen_string_literal: true

namespace :maps do
  namespace :screenshot do
    desc 'create screenshots for all maps missing thumbnails'
    task missing: :environment do
      NetworkMap.where(is_private: false).order(updated_at: :desc).find_each(batch_size: 100) do |map|
        map.take_screenshot unless map.screenshot_exists?
      end
    end

    task featured: :environment do
      NetworkMap.featured.each do |map|
        ColorPrinter.print_blue "Taking Screenshot for #{map.to_param}"
        map.take_screenshot # unless map.screenshot_exists?
      end
    end

    desc 'create screenshots for maps updated in the past X hours'
    task :recent, [:hours] => :environment do |_t, args|
      hours = args[:hours].nil? ? 25 : args[:hours].to_i

      NetworkMap.where('updated_at > ?', hours.hours.ago).each(&:take_screenshot)
    end
  end

  desc 'populate all entity map collections'
  task update_all_entity_map_collections: :environment do
    Rails.cache.delete_matched EntityNetworkMapCollection::MATCH_PATTERN

    NetworkMap.find_each(batch_size: 250) do |network_map|
      unless network_map.title == 'Untitled Map'
        network_map.entities.pluck(:id).each do |entity_id|
          EntityNetworkMapCollection
            .new(entity_id)
            .add(network_map.id)
            .save
        end
      end
    end
  end
end
