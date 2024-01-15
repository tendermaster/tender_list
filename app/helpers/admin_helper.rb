module AdminHelper

  def user_list
    users = []
    User.where('sign_in_count > 0').each do |u|
      users.append([u.email.to_s, u.id])
    end

    users.sort_by { |u| u[0] }
  end

end
