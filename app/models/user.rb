class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :timeoutable, :trackable, :omniauthable

  devise :omniauthable, omniauth_providers: [:google_oauth2]

  has_many :query
  has_many :bookmarks
  has_many :subscriptions
  has_many :tenders, through: :bookmarks

  BUSINESS_TYPES = ['Manufacturer', 'Contractor', 'Trader / Supplier', 'Service provider'].freeze

  # How the team's call to a new user went (blank: not called yet)
  enum :call_status, { called: 'called', no_answer: 'no_answer', not_interested: 'not_interested' },
       validate: { allow_nil: true }

  # Indian mobiles only, stored as +919876543210
  validates :phone, phone: { possible: false, types: [:mobile], countries: :in }, allow_blank: true
  validates :business_type, inclusion: { in: BUSINESS_TYPES }, allow_blank: true
  before_validation :normalize_phone

  # Sent to /welcome after the first sign-in; afterwards the "Finish setup"
  # bar asks for the number until they give it.
  def needs_phone? = phone.blank?
  def new_to_onboarding? = needs_phone? && onboarded_at.nil? && sign_in_count <= 1

  # The user for a Google account, linking or creating one on first sign-in.
  # Returns nil if Google hasn't verified the email address.
  def self.from_google(uid:, email:, email_verified:, name: nil)
    user = find_by(google_uid: uid)
    return user if user
    return nil unless email_verified && email.present?

    user = find_by(email: email.strip.downcase) || new(email: email, name: name.to_s, password: Devise.friendly_token)
    user.google_uid = uid
    user.name = name if user.name.blank? && name.present?
    unless user.confirmed?
      # Nobody proved they own this address when the account was made, so its
      # password may have been set by someone else to take the account over
      # once the real owner arrives. Google just proved who owns it.
      user.password = Devise.friendly_token if user.persisted?
      user.skip_confirmation!
    end
    user.save!
    user
  end

  def self.active_subscription_end_date(user)
    return '-' unless user

    active_subscription = user.active_subscription
    if active_subscription.present?
      end_date = active_subscription.end_date
      time_left = (end_date - Time.zone.now) / 1.days
      "#{end_date.strftime('%d/%m/%Y')} (#{time_left.to_i} #{'day'.pluralize(time_left.to_i)} left)"
    else
      '-'
    end
  end

  def self.active_plan(user)
    return nil unless user

    user.active_plan
  end

  def self.can_fully_view_tender(user, submission_close_date = nil)
    is_tender_expired = if submission_close_date.respond_to?(:to_time)
                          (submission_close_date.to_time < Time.zone.now rescue false)
                        elsif submission_close_date.is_a?(String)
                          (Time.zone.parse(submission_close_date) < Time.zone.now rescue false)
                        else
                          false
                        end

    # has paid valid subscription
    if (!user.nil? && ['PAID', 'PREMIUM'].include?(User.active_plan(user))) || is_tender_expired
      true
    else
      false
    end
  end

  def active_subscription
    @active_subscription ||= subscriptions.where('end_date > now()').order(end_date: :desc).first
  end

  def active_plan
    active_subscription&.plan_name || 'DEMO'
  end

  def self.redeem_coupon(user, code)
    # one time use
    coupon = Coupon.find_by(coupon_code: code, is_valid: true)
    if coupon.present? && Time.now.between?(coupon.start_date, coupon.end_date) && coupon.is_valid
      #   coupon valid
      if coupon.one_time_use
        if Subscription.find_by(coupon_code: code).present?
          {
            ok: false,
            message: 'Coupon has already been used'
          }
        else
          Subscription.create!(
            plan_name: 'PAID',
            price: 0,
            start_date: Time.now,
            end_date: Time.now + coupon.validity_seconds,
            user_id: user.id,
            coupon_code: code
          )

          {
            ok: true,
            message: 'Coupon Redeemed Successfully'
          }
        end
      else
        if user.subscriptions.find_by(coupon_code: code).present?
          #   already in use
          {
            ok: false,
            message: 'Coupon has already been used in this account'
          }
        else
          Subscription.create!(
            plan_name: 'PAID',
            price: 0,
            start_date: Time.now,
            end_date: Time.now + coupon.validity_seconds,
            user_id: user.id,
            coupon_code: code
          )

          {
            ok: true,
            message: 'Coupon Redeemed Successfully'
          }
        end
      end
    else
      {
        ok: true,
        message: 'Invalid Coupon'
      }
    end
  end

  private

  def normalize_phone
    return if phone.blank?

    parsed = Phonelib.parse(phone, 'IN')
    self.phone = parsed.e164 if parsed.valid?
  end
end
