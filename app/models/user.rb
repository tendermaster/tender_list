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

  def self.ransackable_associations(auth_object = nil)
    ['bookmarks', 'query', 'tenders']
  end

  def self.ransackable_attributes(auth_object = nil)
    ['confirmation_sent_at', 'confirmation_token', 'confirmed_at', 'created_at', 'current_plan', 'current_sign_in_at', 'current_sign_in_ip', 'email', 'encrypted_password', 'failed_attempts', 'id', 'last_sign_in_at', 'last_sign_in_ip', 'locked_at', 'name', 'remember_created_at', 'reset_password_sent_at', 'reset_password_token', 'role', 'sign_in_count', 'unconfirmed_email', 'unlock_token', 'updated_at']
  end

  def self.from_omniauth(access_token)
    data = access_token.info
    user = User.where(email: data['email']).first

    # Uncomment the section below if you want users to be created if they don't exist
    user ||= User.create(name: data['name'],
                         email: data['email'],
                         password: Devise.friendly_token[0, 20]
    )
    user
  end

  def self.active_subscription_end_date(user)
    user_subscription = user.subscriptions.where('end_date > now()').order(end_date: :desc).limit(1)
    if user_subscription.present?
      end_date = user_subscription[0].end_date
      time_left = (end_date - Time.zone.now) / 1.days
      "#{end_date.strftime('%d/%m/%Y')} (#{time_left.to_i} #{'day'.pluralize(time_left.to_i)} left)"
    else
      '-'
    end
  end

  def self.active_plan(user)
    user_subscription = user.subscriptions.where('end_date > now()').order(end_date: :desc).limit(1)
    if user_subscription.present?
      sub = user_subscription[0]
      sub.plan_name
    else
      'DEMO'
    end
  end

  def self.can_fully_view_tender(user)
    # has paid valid subscription
    if !user.nil? && ['PAID', 'PREMIUM'].include?(User.active_plan(user))
      true
    else
      false
    end
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

end
