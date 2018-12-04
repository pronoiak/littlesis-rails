# frozen_string_literal: true

class DashboardBulletin < ApplicationRecord
  DEFAULT_COLOR = 'rgba(0, 0, 0, 0.03)'.html_safe.freeze

  default_scope { order(created_at: :desc) }

  def self.last_bulletin_updated_at
    DashboardBulletin.reorder('updated_at desc').limit(1).pluck('updated_at').first
  end
end
