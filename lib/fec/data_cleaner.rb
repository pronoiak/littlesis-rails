# frozen_string_literal: true

# rubocop:disable Rails/SkipsModelValidations

module FEC
  module DataCleaner
    def self.run
      Committee.where(:CAND_ID => '').update_all(:CAND_ID => nil)
      IndividualContribution.where(:CITY => '').update_all(:CITY => nil)
      IndividualContribution.where(:STATE => '').update_all(:STATE => nil)
      IndividualContribution.where(:ZIP_CODE => '').update_all(:ZIP_CODE => nil)
      IndividualContribution.where(:EMPLOYER => '').update_all(:EMPLOYER => nil)
      IndividualContribution.where(:OCCUPATION => '').update_all(:OCCUPATION => nil)
    end
  end
end


# rubocop:enable Rails/SkipsModelValidations
