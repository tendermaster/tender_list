module AdminHelper

  def user_list
    users = []
    User.where('sign_in_count > 0').each do |u|
      users.append(["#{u.email}", u.id])
    end

    users
  end

end
