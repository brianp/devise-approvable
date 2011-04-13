module Devise
  module Models
    module Approvable
      # extend ActiveSupport::Concern #RAILS 3
      include Devise::Models::Activatable

      def self.included(base)
        base.class_eval do
          extend ClassMethods

          before_create :generate_approval_token, :if => :approval_required?
          # after_create  :send_approval_instructions unless approved?
        end
      end

      # Confirm a user by setting it's confirmed_at to actual time. If the user
      # is already confirmed, add en error to email field
      def confirm!
        unless_confirmed do
          self.confirmation_token = nil
          self.confirmed_at = Time.now
          save(false)
        end
      end

      # Verifies whether a user is confirmed or not
      def confirmed?
        !new_record? && !confirmed_at.nil?
      end

      # Send confirmation instructions by email
      def send_confirmation_instructions
        generate_confirmation_token if self.confirmation_token.nil?
        ::DeviseMailer.deliver_confirmation_instructions(self)
      end

      # Resend confirmation token. This method does not need to generate a new token.
      def resend_confirmation_token
        unless_confirmed { send_confirmation_instructions }
      end

      # Overwrites active? from Devise::Models::Activatable for confirmation
      # by verifying whether an user is active to sign in or not. If the user
      # is already confirmed, it should never be blocked. Otherwise we need to
      # calculate if the confirm time has not expired for this user.
      def active?
        super && (!confirmation_required? || confirmed? || confirmation_period_valid?)
      end

      # The message to be shown if the account is inactive.
      def inactive_message
        !confirmed? ? :unconfirmed : super
      end

      # If you don't want confirmation to be sent on create, neither a code
      # to be generated, call skip_confirmation!
      def skip_confirmation!
        self.confirmed_at  = Time.now
        @skip_confirmation = true
      end

      def skip_confirm_and_approve!
        skip_confirmation!
        skip_approval!
      end

      def approve!
        self.is_approved = true
        self.approval_token = nil
        send_confirmation_instructions
        save(:validate => false)
      end

      # Verifies whether a user is confirmed or not
      def approved?
        self.is_approved
      end

      def skip_approval!
        self.is_approved = true
        @skip_approval = true
      end
      
      # Send confirmation instructions by email
      def send_approval_instructions
        generate_approval_token if self.approval_token.nil?
        ::DeviseMailer.deliver_approval_instructions(self)
      end

      protected

        # Callback to overwrite if confirmation is required or not.
        def confirmation_required?
          !@skip_confirmation
        end
        
        def approval_required?
          !@skip_approval
        end

        # Checks if the confirmation for the user is within the limit time.
        # We do this by calculating if the difference between today and the
        # confirmation sent date does not exceed the confirm in time configured.
        # Confirm_in is a model configuration, must always be an integer value.
        #
        # Example:
        #
        #   # confirm_within = 1.day and confirmation_sent_at = today
        #   confirmation_period_valid?   # returns true
        #
        #   # confirm_within = 5.days and confirmation_sent_at = 4.days.ago
        #   confirmation_period_valid?   # returns true
        #
        #   # confirm_within = 5.days and confirmation_sent_at = 5.days.ago
        #   confirmation_period_valid?   # returns false
        #
        #   # confirm_within = 0.days
        #   confirmation_period_valid?   # will always return false
        #
        def confirmation_period_valid?
          confirmation_sent_at && confirmation_sent_at.utc >= self.class.confirm_within.ago
        end

        # Checks whether the record is confirmed or not, yielding to the block
        # if it's already confirmed, otherwise adds an error to email.
        def unless_confirmed
          unless confirmed?
            yield
          else
            self.class.add_error_on(self, :email, :already_confirmed)
            false
          end
        end

        # Generates a new random token for confirmation, and stores the time
        # this token is being generated
        def generate_confirmation_token
          self.confirmed_at = nil
          self.confirmation_token = Devise.friendly_token
          self.confirmation_sent_at = Time.now.utc
        end

        def generate_approval_token
          self.is_approved = false
          self.approval_token = Devise.friendly_token
          self.approval_sent_at = Time.now.utc
        end

      module ClassMethods
        # Attempt to find a user by it's email. If a record is found, send new
        # confirmation instructions to it. If not user is found, returns a new user
        # with an email not found error.
        # Options must contain the user email
        def send_confirmation_instructions(attributes={})
          confirmable = find_or_initialize_with_error_by(:email, attributes[:email], :not_found)
          confirmable.resend_confirmation_token unless confirmable.new_record?
          confirmable
        end

        # Find a user by it's confirmation token and try to confirm it.
        # If no user is found, returns a new user with an error.
        # If the user is already confirmed, create an error for the user
        # Options must have the confirmation_token
        def confirm_by_token(confirmation_token)
          confirmable = find_or_initialize_with_error_by(:confirmation_token, confirmation_token)
          confirmable.confirm! unless confirmable.new_record?
          confirmable
        end

        Devise::Models.config(self, :confirm_within)
      end
    end
  end
end