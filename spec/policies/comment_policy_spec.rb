require "rails_helper"

RSpec.describe CommentPolicy, type: :policy do
  subject(:comment_policy) { described_class.new(user, comment) }

  let(:article) { build_stubbed(:article) }
  let!(:comment) { create(:comment, commentable: create(:podcast_episode)) }

  let(:valid_attributes_for_create) do
    %i[body_markdown commentable_id commentable_type parent_id]
  end

  let(:valid_attributes_for_update) do
    %i[body_markdown receive_notifications]
  end

  let(:valid_attributes_for_subscribe) do
    %i[subscription_id comment_id article_id]
  end

  let(:valid_attributes_for_moderator_create) do
    %i[commentable_id commentable_type parent_id]
  end

  context "when user is not signed-in" do
    let(:user) { nil }

    it { within_block_is_expected.to raise_error(Pundit::NotAuthorizedError) }
  end

  context "when user wants to subscribe to a comment" do
    let(:user) { create(:user) }

    it { is_expected.to permit_actions(%i[subscribe]) }

    it { is_expected.to permit_mass_assignment_of(valid_attributes_for_subscribe).for_action(:subscribe) }
  end

  context "when user is not the author" do
    let!(:user) { create(:user) }

    it { is_expected.to permit_actions(%i[create]) }
    it { is_expected.to forbid_actions(%i[edit update destroy delete_confirm hide unhide moderator_create moderate]) }
    it { is_expected.to forbid_actions(%i[admin_delete]) }

    it { is_expected.to permit_mass_assignment_of(valid_attributes_for_create).for_action(:create) }

    context "with suspended status" do
      before { user.add_role(:suspended) }

      it { is_expected.to forbid_actions(%i[create edit update destroy delete_confirm hide unhide admin_delete]) }
      it { is_expected.to forbid_actions(%i[moderate]) }
    end

    context "with comment_suspended role" do
      before { user.add_role(:comment_suspended) }

      it { is_expected.to forbid_actions(%i[create edit update destroy delete_confirm hide unhide admin_delete]) }
      it { is_expected.to forbid_actions(%i[moderate]) }
    end

    context "when user is a tag moderator" do
      before do
        tag = create(:tag)
        user.add_role(:tag_moderator, tag)
      end

      it { is_expected.to permit_actions(%i[create moderator_create moderate]) }

      it do
        expect(comment_policy).to permit_mass_assignment_of(valid_attributes_for_moderator_create)
          .for_action(:moderator_create)
      end
    end

    context "when user is an admin or super_admin" do
      before { user.add_role(:admin) }

      it { is_expected.to permit_actions(%i[create moderator_create admin_delete moderate]) }

      it do
        expect(comment_policy).to permit_mass_assignment_of(valid_attributes_for_moderator_create)
          .for_action(:moderator_create)
      end
    end

    context "when user is trusted" do
      before { user.add_role(:trusted) }

      it { is_expected.to permit_actions(%i[moderator_create]) }
    end
  end

  context "when user is the author" do
    let(:user) { comment.user }

    it { is_expected.to permit_actions(%i[edit update new create delete_confirm destroy]) }
    it { is_expected.to forbid_actions(%i[moderator_create admin_delete moderate]) }

    it { is_expected.to permit_mass_assignment_of(valid_attributes_for_create).for_action(:create) }
    it { is_expected.to permit_mass_assignment_of(valid_attributes_for_update).for_action(:update) }

    context "with suspended status" do
      before { user.add_role(:suspended) }

      it { is_expected.to permit_actions(%i[preview destroy delete_confirm]) }
      it { is_expected.to forbid_actions(%i[edit update create hide unhide moderator_create admin_delete moderate]) }

      it do
        expect(comment_policy).to permit_mass_assignment_of(valid_attributes_for_update).for_action(:update)
      end
    end

    context "with comment_suspended role" do
      before { user.add_role(:comment_suspended) }

      it { is_expected.to permit_actions(%i[edit update destroy delete_confirm]) }
      it { is_expected.to forbid_actions(%i[create hide unhide moderator_create admin_delete moderate]) }

      it do
        expect(comment_policy).to permit_mass_assignment_of(valid_attributes_for_update).for_action(:update)
      end
    end

    context "when user is a tag moderator" do
      before do
        tag = create(:tag)
        user.add_role(:tag_moderator, tag)
      end

      it { is_expected.to permit_actions(%i[edit update destroy delete_confirm moderator_create create moderate]) }
      it { is_expected.to forbid_actions(%i[admin_delete]) }

      it do
        expect(comment_policy).to permit_mass_assignment_of(valid_attributes_for_update).for_action(:update)
        expect(comment_policy).to permit_mass_assignment_of(valid_attributes_for_moderator_create)
          .for_action(:moderator_create)
      end
    end
  end

  context "when user is commentable author" do
    subject(:comment_policy) { described_class.new(commentable_author, comment) }

    let(:commentable_author) { comment.commentable.user }
    let(:comment) { build_stubbed(:comment, commentable: article) }

    it { is_expected.to permit_actions(%i[hide unhide create]) }
    it { is_expected.to forbid_actions(%i[edit update destroy delete_confirm moderate]) }
    it { is_expected.to forbid_actions(%i[moderator_create admin_delete]) }

    context "when comment author is the staff account" do
      let(:staff_account) { create(:user) }
      let(:comment) { build_stubbed(:comment, commentable: article, user: staff_account) }

      before do
        allow(User).to receive(:staff_account).and_return(staff_account)
      end

      it { is_expected.to permit_actions([:create]) }
      it { is_expected.to forbid_actions(%i[hide unhide edit update destroy delete_confirm]) }
      it { is_expected.to forbid_actions(%i[moderate moderator_create admin_delete]) }
    end
  end
end
