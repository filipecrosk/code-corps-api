require 'rails_helper'

describe "Organizations API" do

  context 'GET /organizations/:id' do
    before do
      @organization = create(:organization, name: "Code Corps")
      get "#{host}/organizations/#{@organization.id}"
    end

    it "responds with a 200" do
      expect(last_response.status).to eq 200
    end

    it "retrieves the specified organization by id using OrganizationSerializer" do
      expect(json).to serialize_object(Organization.find(@organization.id)).with(OrganizationSerializer)
    end
  end

  context 'POST /organizations' do
    context "when unauthenticated" do
      it "responds with a 401 NOT_AUTHORIZED" do
        post "#{host}/organizations"

        expect(last_response.status).to eq 401
        expect(json).to be_a_valid_json_api_error.with_id "NOT_AUTHORIZED"
      end
    end

    context "when authenticated" do
      context "as a regular user" do
        before do
          @user = create(:user, password: "password")
          @token = authenticate(email: @user.email, password: "password")
        end

        it "responds with a 401 ACCESS_DENIED" do
          authenticated_post "/organizations", {}, @token

          expect(last_response.status).to eq 401
          expect(json).to be_a_valid_json_api_error.with_id "ACCESS_DENIED"
        end
      end

      context "as an admin user" do
        before do
          @admin = create(:user, admin: true, password: "password")
          @token = authenticate(email: @admin.email, password: "password")
        end

        context "with a user uploaded image" do
          it "creates an organization" do
            Sidekiq::Testing.inline! do
              file = File.open("#{Rails.root}/spec/sample_data/default-avatar.png", 'r')
              base64_image = Base64.encode64(open(file) { |io| io.read })

              authenticated_post "/organizations", {
                data: {
                  attributes: {
                    base64_icon_data: base64_image,
                    name: "Test",
                  }
                }
              }, @token

              expect(last_response.status).to eq 200

              organization = Organization.last

              expect(organization.base64_icon_data).to be_nil
              expect(organization.icon.path).to_not be_nil
              expect(organization.name).to eq "Test"
              # expect icon saved from create action to be identical to our test photor
              icon_file = File.open("#{Rails.root}/spec/sample_data/default-avatar.png", "r")
              base64_saved_image = Base64.encode64(open(icon_file, &:read))
              expect(base64_saved_image).to include base64_image
            end
          end
        end

        it "responds with a 422 VALIDATION_ERROR if name is not provided" do
          authenticated_post "/organizations", { data: { attributes: { } } }, @token
          expect(last_response.status).to eq 422
          expect(json).to be_a_valid_json_api_validation_error
        end

        it 'allows a slug to be set' do
          authenticated_post "/organizations", { data: { attributes: { name: "Test", slug: "Test_slug" } } }, @token

          expect(last_response.status).to eq 200

          expect(Organization.last.slug).to eq "Test_slug"
        end

        it 'fails on a slug with profane content' do
          authenticated_post "/organizations", { data: { attributes: { name: "Test", slug: "shit" } } }, @token
          expect(last_response.status).to eq 422
          expect(json).to be_a_valid_json_api_validation_error.with_message "may not be obscene"
        end

        context "when succesful" do
          def make_request
            authenticated_post "/organizations", { data: { attributes: { name: "Test" } } }, @token
          end

          it "responds with a 200" do
            make_request
            expect(last_response.status).to eq 200
          end

          it "creates an Organization" do
            expect{ make_request }.to change{ Organization.count }.by 1
            expect(Organization.last.name).to eq "Test"
          end

          it "returns the created Organization, serialized with OrganizationSerializer" do
            make_request
            expect(json).to serialize_object(Organization.last).with(OrganizationSerializer)
          end
        end
      end
    end
  end

  context "PATCH /organizations/:id" do

     let(:organization) { create(:organization) }

    context "when unauthenticated" do
      it "should return a 401 with a proper error" do
        patch "#{host}/organizations/#{organization.id}", { data: { type: "organization" } }
        expect(last_response.status).to eq 401
        expect(json).to be_a_valid_json_api_error.with_id "NOT_AUTHORIZED"
      end
    end

    context "when authenticated" do
      before do
        @user = create(:user, email: "test_user@mail.com", password: "password")
        @organization = create(:organization)
        create(:organization_membership, member: @user, organization: @organization, role: "admin")
        @token = authenticate(email: "test_user@mail.com", password: "password")
      end

      it "returns a 404 if the organization doesn't exist" do
        authenticated_patch "/organizations/22", {
          data: {
            attributes: { name: "Organization" },
          }
        }, @token

        expect(last_response.status).to eq 404
        expect(json).to be_a_valid_json_api_error.with_id "RECORD_NOT_FOUND"
      end

      context "when updating the name and description" do
        it "updates a organization name" do
          authenticated_patch "/organizations/#{@organization.id}", {
            data: {
              attributes: { 
                name: "New Name",
                description: "New Description"
                },
            }
          }, @token

          @organization.reload
          expect(@organization.name).to eq "New Name"
        end
      end

      it "returns an error when with a nil name" do
        authenticated_patch "/organizations/#{@organization.id}", {
          data: {
            attributes: {
              name: nil
            }
          }
        }, @token

        expect(last_response.status).to eq 422
        expect(json).to be_a_valid_json_api_validation_error.with_message "can't be blank"
      end

      context "when updating a organization icon when none exists" do
        context "when given a base64 string" do
          it "saves successfully" do
            Sidekiq::Testing.inline! do
              filename = "#{Rails.root}/spec/sample_data/base64_images/jpeg.txt"
              base64_saved_image = File.open(filename, &:read)

              authenticated_patch "/organizations/#{@organization.id}", {
                data: {
                  attributes: {
                    base64_icon_data: base64_saved_image
                  }
                }
              }, @token

              @organization.reload

              expect(@organization.base64_icon_data).to be_nil
              expect(@organization.icon.path).to_not be_nil
            end
          end
        end
      end
    end
  end
end
