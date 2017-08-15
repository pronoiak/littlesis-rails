require 'rails_helper'

describe 'User Permissions', type: :model do

  it 'user has permissions class' do
    user = create_basic_user
    expect(user.permissions).to be_a UserPermissions::Permissions
  end

  xdescribe 'user.permissions.edit_list?' do

    # TODO (ag|2017.08.`5): delete this block once #210 is complete
    # as all scenarios will be tested by describe "list permissions" block

    it 'users can edit entities from lists they\'ve created' do
      user = create_contributor
      list_created_by_user = create(:list, creator_user_id: user.id)
      list_created_by_somone_else = create(:list, creator_user_id: user.id + 1)
      expect(user.permissions.edit_list?(list_created_by_user)).to be true
      expect(user.permissions.edit_list?(list_created_by_somone_else)).to be false
    end

    it 'users with lister permissions can edit any list' do
      lister = create_list_user
      contributor = create_contributor
      list = create(:list)
      expect(lister.permissions.edit_list?(list)).to be true
      expect(contributor.permissions.edit_list?(list)).to be false
    end

    it 'private lists can only be edited by the list owner' do
      lister = create_list_user
      contributor = create_contributor
      list = create(:list, creator_user_id: contributor.id, is_private: true)
      expect(lister.permissions.edit_list?(list)).to be false
      expect(contributor.permissions.edit_list?(list)).to be true
    end

    it 'admin lists can only be edited by admins' do
      lister = create_list_user
      admin = create_admin_user
      list = build(:list, is_admin: true)
      expect(lister.permissions.edit_list?(list)).to be false
      expect(admin.permissions.edit_list?(list)).to be true
    end
  end
  
end

describe UserPermissions::Permissions do

  describe 'initalize' do

    context 'basic user with contributor, editor, and lister permissions' do
      before(:all) do
        @user = create_basic_user
        @permission = UserPermissions::Permissions.new(@user)
      end

      it 'initializes with user' do
        expect(@permission.instance_variable_get('@user')).to eq @user
      end

      it 'initializes with sf_permissions' do
        expect(@permission.instance_variable_get('@sf_permissions')).to eq ['contributor', 'editor','lister']
      end

      it 'contributor? returns true' do
        expect(@permission.contributor?).to be true
      end

      it 'editor? returns true' do
        expect(@permission.editor?).to be true
      end

      it 'lister? returns true' do
        expect(@permission.lister?).to be true
      end

      it 'admin? returns false' do
        expect(@permission.admin?).to be false
      end

      it 'deleter? returns false' do
        expect(@permission.deleter?).to be false
      end
    end
  end

  describe "list permisions" do

    before do
      @creator = create_basic_user
      @non_creator = create_really_basic_user
      @lister = create_basic_user # basic_user === lister (see spec/support/helpers.rb)
      @admin = create_admin_user
    end

    context "an open list" do

      before do
        @open_list = build(:list, access: List::ACCESS_OPEN, creator_user_id: @creator.id)
      end

      context "anon user" do

        it 'cannot view but not edit or configure the list' do
          expect(UserPermissions::Permissions.anon_list_permissions(@list))
            .to eq ({
                      viewable: true,
                      editable: false,
                      configurable: false
                    })
        end
      end

      context "logged-in creator" do

        it 'can view, edit, and configure the list' do

          expect(@creator.permissions.list_permissions(@open_list))
            .to eq ({
                      viewable: true,
                      editable: true,
                      configurable: true
                    })
        end
      end

      context "logged-in non-creator" do

        it 'can view, but no edit, or configure the list' do
          expect(@non_creator.permissions.list_permissions(@open_list))
            .to eq ({
                      viewable: true,
                      editable: false,
                      configurable: false
                    })
        end
      end

      context "lister" do

        it "can be viewed and edited, but not configured" do
          expect(@lister.permissions.list_permissions(@open_list))
            .to eq ({
                      viewable: true,
                      editable: true,
                      configurable: false
                    })
        end
      end

      context "admin" do

        it "can view, edit, and configure" do
          expect(@admin.permissions.list_permissions(@open_list))
            .to eq ({
                      viewable: true,
                      editable: true,
                      configurable: true
                    })
        end
      end #admin
    end # open list
  end
end
