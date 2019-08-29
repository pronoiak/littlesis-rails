# frozen_string_literal: true

module ExternalDatasetService
  class Iapd < Base
    def self.crd_number?(crd)
      return false if crd.blank? || crd.include?('-')

      /\A\d+\z/.match?(crd)
    end

    def validate_match!
      requies_entity!

      return if crd_number.blank?

      external_link = @entity.external_links.find_by(link_type: :crd)

      if external_link
        if external_link.link_id.to_i == crd_number.to_i
          # Entity already has an external link with the value.
          # The entity has likely already been matched.
          return
        else
          msg = "Entity #{@entity.id} already has a crd_number. Cannot match row #{@external_dataset.id}"
          raise InvalidMatchError, msg
        end
      end

      if ExternalLink.exists?(link_type: :crd, link_id: crd_number)
        msg = "Another entity has already claimed the crd number #{crd_number}. Cannot match row #{@external_dataset.id}"
        raise InvalidMatchError, msg
      end
    end

    def match
      return :already_matched if @external_dataset.matched?

      validate_match!

      # if @external_dataset.advisor?
      #   aum = @external_dataset.row_data['data'].first['assets_under_management']&.to_i
      #   extension_attrs[:aum] = aum unless aum.nil? || aum.zero?
      # end

      ApplicationRecord.transaction do
        @entity.add_tag(IapdDatum::IAPD_TAG_ID)

        crd_numbers_for_documentation.each do |crd_number|
          @entity.add_reference(IapdDatum.document_attributes_for_form_adv_pdf(crd_number))
        end

        if @entity.has_extension?(extension)
          @entity.merge_extension extension, extension_attrs
        else
          @entity.add_extension extension, extension_attrs
        end

        external_dataset.update! entity_id: @entity.id
        @entity.save!
      end

      if external_dataset.advisor?
        external_dataset.owners.map do |owner|
          IapdRelationshipService.new(advisor: external_dataset, owner: owner)
        end
      elsif external_dataset.owner?
        external_dataset.advisors.map do |advisor|
          IapdRelationshipService.new(advisor: advisor, owner: external_dataset)
        end
      end
    end

    def unmatch
      extension = external_dataset.org? ? 'business' : 'business_person'

      ApplicationRecord.transaction do
        @external_dataset.entity.public_send(extension).update! crd_number: nil
        @external_dataset.update! entity_id: nil
      end
    end

    private

    def crd_numbers_for_documentation
      if @external_dataset.advisor?
        Array.wrap(@external_dataset.row_data.fetch('crd_number'))
      elsif @external_dataset.owner?
        @external_dataset.row_data.fetch('associated_advisors')
      end
    end

    def crd_number
      if @external_dataset.row_data_class&.include? 'IapdAdvisor'
        @external_dataset.row_data.fetch('crd_number')
      elsif @external_dataset.row_data_class&.include? 'IapdOwner'
        owner_key = @external_dataset.row_data.fetch('owner_key')
        return owner_key if self.class.crd_number?(owner_key)
      end
    end
  end
end
