class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :timeoutable, :trackable, :omniauthable

  devise :omniauthable, omniauth_providers: [:google_oauth2]

  has_many :query
  has_many :bookmarks
  has_many :tenders, through: :bookmarks

  def self.ransackable_associations(auth_object = nil)
    ["bookmarks", "query", "tenders"]
  end

  def self.ransackable_attributes(auth_object = nil)
    ["confirmation_sent_at", "confirmation_token", "confirmed_at", "created_at", "current_plan", "current_sign_in_at", "current_sign_in_ip", "email", "encrypted_password", "failed_attempts", "id", "last_sign_in_at", "last_sign_in_ip", "locked_at", "name", "remember_created_at", "reset_password_sent_at", "reset_password_token", "role", "sign_in_count", "unconfirmed_email", "unlock_token", "updated_at"]
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

  def self.can_fully_view_tender(user)
    if !user.nil? && user.current_plan == 'PAID'
      true
    else
      false
    end
  end

end
