class NoteEntity < ActiveRecord::Base
  belongs_to :note, inverse_of: :note_entities
  belongs_to :entity
end
