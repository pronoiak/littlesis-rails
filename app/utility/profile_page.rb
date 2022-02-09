# frozen_string_literal: true

module ProfilePage
  def self.subcategory_name(subcategory)
    case subcategory
    when :board_members
      "Board Members"
    when :board_memberships
      "Board Memberships"
    when :businesses
      "Business Positions"
    when :campaign_contributions
      "Federal Election Campaign Contributions"
    when :campaign_contributors
      "Campaign Donors"
    when :children
      "Child Organizations"
    when :donations
      "Donations"
    when :donors
      "Donors"
    when :family
      "Family"
    when :generic
      "Miscellaneous Relationships"
    when :governments
      "Government Positions"
    when :holdings
      "Holdings"
    when :lobbied_by
      "Lobbied By"
    when :lobbies
      "Lobbying"
    when :members
      "Members"
    when :memberships
      "Memberships"
    when :offices
      "In the office of"
    when :owners
      "Owners"
    when :parents
      "Parents"
    when :positions
      "Positions"
    when :schools
      "Schools"
    when :social
      "Social"
    when :staff
      "Leadership & Staff"
    when :students
      "Students"
    when :transactions
      "Services & Transactions"
    end
  end

  def self.relationship_category_icon(category_id)
    {
      Relationship::POSITION_CATEGORY => '🕴',
      Relationship::EDUCATION_CATEGORY => '🎓',
      Relationship::MEMBERSHIP_CATEGORY => '🤝',
      Relationship::FAMILY_CATEGORY => '👪',
      Relationship::DONATION_CATEGORY => '💸',
      Relationship::TRANSACTION_CATEGORY => '🧾',
      Relationship::LOBBYING_CATEGORY => '🏢',
      Relationship::SOCIAL_CATEGORY => '🍻',
      Relationship::PROFESSIONAL_CATEGORY => '💼',
      Relationship::OWNERSHIP_CATEGORY => '👑',
      Relationship::HIERARCHY_CATEGORY => '🛗',
      Relationship::GENERIC_CATEGORY => '🏷'
    }.fetch(category_id)
  end
end
