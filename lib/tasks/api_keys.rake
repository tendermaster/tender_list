namespace :api_keys do
  desc 'Create an API key for /api/v1/search and print it: bin/rails "api_keys:create[Partner name]"'
  task :create, [:name] => :environment do |_, args|
    abort 'usage: bin/rails "api_keys:create[Partner name]"' if args[:name].blank?

    key = ApiKey.create!(name: args[:name])
    puts "API key for #{key.name} (also in /admin/api_keys, where it can be switched off):"
    puts key.token
  end
end
