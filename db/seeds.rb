# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

if Rails.env == 'development'
  Rake::Task['hyrax:default_admin_set:create'].invoke
  Rake::Task['hyrax:default_collection_types:create'].invoke
  Rake::Task['hyrax:workflow:load'].invoke

  seed_admin_email    = ENV.fetch('SEED_ADMIN_EMAIL',    'admin@example.com')
  seed_admin_password = ENV.fetch('SEED_ADMIN_PASSWORD') { raise 'Set SEED_ADMIN_PASSWORD before running db:seed' }
  user = User.first_or_create!(email: seed_admin_email, password: seed_admin_password)
  admin = Role.first_or_create!(name: 'admin')
  admin.users << user
  admin.save
end
